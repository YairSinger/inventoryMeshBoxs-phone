import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../protocol.dart';

class BleClient {
  final int pinHash;
  BluetoothDevice? _device;
  bool _isAuthenticated = false;
  
  StreamSubscription<List<int>>? _eventSub;
  Completer<imb_ack_status>? _authCompleter;
  
  final _eventStreamController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get eventStream => _eventStreamController.stream;

  BluetoothCharacteristic? _commandChar;

  BleClient({required this.pinHash});

  bool get isAuthenticated => _isAuthenticated;

  Future<void> connect(BluetoothDevice device) async {
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
    BluetoothCharacteristic commandChar = imbService.characteristics.firstWhere(
      (char) => char.uuid.toString() == IMB_CHAR_COMMAND_WRITE
    );
    _commandChar = commandChar;

    await eventChar.setNotifyValue(true);
    _eventSub = eventChar.lastValueStream.listen(_onEventReceived);

    _authCompleter = Completer<imb_ack_status>();
    
    final hello = CmdHello(
      msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_hello]!,
      msg_id: 1, 
      pin_hash: pinHash,
    );

    await commandChar.write(hello.toBytes());

    try {
      final statusResult = await _authCompleter!.future.timeout(const Duration(seconds: 5));
      if (statusResult == imb_ack_status.ack_ok) {
        _isAuthenticated = true;
      } else {
        throw Exception('Authentication failed');
      }
    } on TimeoutException {
      throw Exception('Handshake timeout');
    }
  }

  void _onEventReceived(List<int> data) {
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

  Future<void> sendCommand(Uint8List data) async {
    if (_commandChar == null) throw Exception('Not connected');
    await _commandChar!.write(data);
  }

  Future<void> disconnect() async {
    await _eventSub?.cancel();
    await _device?.disconnect();
    _isAuthenticated = false;
  }
}
