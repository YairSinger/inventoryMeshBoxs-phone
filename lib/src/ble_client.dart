import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../protocol.dart';

abstract class IBleClient {
  Stream<List<int>> get eventStream;
  Stream<List<ScanResult>> get scanResults;
  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connect(BluetoothDevice device, int meshPinHash);
  Future<void> sendCommand(Uint8List data);
  bool get isAuthenticated;
  Future<void> disconnect();
  Future<void> requestPriority(ConnectionPriority priority);
}

class BleClient implements IBleClient {
  BluetoothDevice? _device;
  bool _isAuthenticated = false;
  
  final List<StreamSubscription> _subs = [];
  Completer<imb_ack_status>? _authCompleter;
  
  final _eventStreamController = StreamController<List<int>>.broadcast();
  @override
  Stream<List<int>> get eventStream => _eventStreamController.stream;

  @override
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  BluetoothCharacteristic? _commandChar;

  BleClient();

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Future<void> startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  @override
  Future<void> connect(BluetoothDevice device, int meshPinHash) async {
    _device = device;
    _isAuthenticated = false;

    await device.connect();

    List<BluetoothService> services = await device.discoverServices();
    BluetoothService imbService = services.firstWhere(
      (service) => service.uuid.toString() == IMB_SERVICE_UUID,
      orElse: () => throw Exception('IMB Service not found'),
    );

    BluetoothCharacteristic eventChar = imbService.characteristics.firstWhere(
      (char) => char.uuid.toString() == IMB_CHAR_EVENT_NOTIFY
    );
    BluetoothCharacteristic reportChar = imbService.characteristics.firstWhere(
      (char) => char.uuid.toString() == IMB_CHAR_REPORT_NOTIFY
    );
    BluetoothCharacteristic commandChar = imbService.characteristics.firstWhere(
      (char) => char.uuid.toString() == IMB_CHAR_COMMAND_WRITE
    );
    _commandChar = commandChar;

    // Both characteristics MUST be subscribed before CMD_HELLO to enable queue flush
    await eventChar.setNotifyValue(true);
    await reportChar.setNotifyValue(true);

    _subs.add(eventChar.onValueReceived.listen(_onDataReceived));
    _subs.add(reportChar.onValueReceived.listen(_onDataReceived));

    _authCompleter = Completer<imb_ack_status>();
    
    // Set high priority for handshake
    await requestPriority(ConnectionPriority.high);

    final hello = CmdHello(
      msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_hello]!,
      msg_id: 1, 
      pin_hash: meshPinHash,
    );

    await commandChar.write(hello.toBytes());

    try {
      final statusResult = await _authCompleter!.future.timeout(const Duration(seconds: 5));
      if (statusResult == imb_ack_status.ack_ok) {
        _isAuthenticated = true;
      } else {
        throw Exception('Authentication failed: $statusResult');
      }
    } on TimeoutException {
      throw Exception('Handshake timeout');
    }
  }

  @override
  Future<void> requestPriority(ConnectionPriority priority) async {
    if (_device != null) {
      await _device!.requestConnectionPriority(connectionPriorityRequest: priority);
    }
  }

  void _onDataReceived(List<int> data) {
    if (data.isEmpty) return;
    
    _eventStreamController.add(data);

    final msgType = data[0];
    if (msgType == imb_msg_typeValues[imb_msg_type.msg_event_ack]) {
      final ack = EventAck.fromBytes(Uint8List.fromList(data));
      
      if (ack.acked_msg_id == 1 && 
          ack.acked_msg_type == imb_msg_typeValues[imb_msg_type.msg_cmd_hello]) {
        
        final status = imb_ack_status.values.firstWhere(
          (st) => imb_ack_statusValues[st] == ack.status,
          orElse: () => imb_ack_status.ack_not_authed,
        );
        
        _authCompleter?.complete(status);
      }
    }
  }

  @override
  Future<void> sendCommand(Uint8List data) async {
    if (_commandChar == null) throw Exception('Not connected');
    await _commandChar!.write(data);
  }

  @override
  Future<void> disconnect() async {
    for (var sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _device?.disconnect();
    _isAuthenticated = false;
  }
}
