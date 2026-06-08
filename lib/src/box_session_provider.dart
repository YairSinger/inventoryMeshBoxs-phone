import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../protocol.dart';
import 'ble_client.dart';
import 'box_manager.dart';
import 'mock_ble_client.dart';
import 'utils/crc32.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class PendingTag {
  final String uid;
  int retryCount;
  PendingTag({required this.uid, this.retryCount = 0});
}

class LogEntryData {
  final int seqId;
  final int boxId;
  final int type;
  final String itemName;
  LogEntryData({required this.seqId, required this.boxId, required this.type, required this.itemName});
}

class BoxData {
  final int id;
  final String name;
  final bool isOnline;
  final String lastSeen;
  final int itemCount;
  final List<ReportEntry> items;

  BoxData({
    required this.id,
    required this.name,
    this.isOnline = false,
    this.lastSeen = 'Unknown',
    this.itemCount = 0,
    this.items = const [],
  });
}

class MeshData {
  final int pinHash;
  final String name;
  int boxCount;
  int itemCount;
  final List<ReportEntry> missingItems;
  final List<LogEntryData> recentEvents;
  final List<BoxData> boxes;
  BluetoothDevice? device;

  MeshData({
    required this.pinHash,
    required this.name,
    this.boxCount = 0,
    this.itemCount = 0,
    this.missingItems = const [],
    this.recentEvents = const [],
    this.boxes = const [],
    this.device,
  });
}

class BoxSessionProvider extends ChangeNotifier {
  final IBleClient bleClient;

  List<MeshData> _discoveredMeshes = [];
  MeshData? _selectedMesh;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  imb_op_mode _currentMode = imb_op_mode.mode_field_check;
  bool _isRegistrationIncomplete = false;
  final Queue<PendingTag> _pendingTags = Queue<PendingTag>();

  // Getters
  List<MeshData> get discoveredMeshes => _discoveredMeshes;
  MeshData? get selectedMesh => _selectedMesh;
  ConnectionStatus get connectionStatus => _connectionStatus;
  imb_op_mode get currentMode => _currentMode;
  bool get isRegistrationIncomplete => _isRegistrationIncomplete;
  bool get hasPendingTags => _pendingTags.isNotEmpty;
  Queue<PendingTag> get pendingTags => _pendingTags;

  StreamSubscription<List<int>>? _eventSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  Completer<imb_ack_status>? _nameCompleter;

  BoxSessionProvider({required this.bleClient}) {
    _eventSub = bleClient.eventStream.listen(_handleBleEvent);
    _scanSub = bleClient.scanResults.listen(_handleScanResults);
    
    if (bleClient is MockBleClient) {
      _loadCachedMeshes();
    }
  }

  void _loadCachedMeshes() {
    _discoveredMeshes = [
      MeshData(
        name: 'Camping Trip',
        pinHash: 0x12345678,
        boxCount: 2,
        itemCount: 15,
        missingItems: [
          ReportEntry(box_id: 0xA3F1, status: 1, uid: 'TAG-1', name: 'Flashlight'),
        ],
        recentEvents: [
          LogEntryData(seqId: 102, boxId: 0xA3F1, type: 0, itemName: 'Flashlight'),
          LogEntryData(seqId: 101, boxId: 0xB2C2, type: 1, itemName: 'Sleeping Bag'),
        ],
        boxes: [
          BoxData(id: 0xA3F1, name: 'Kitchen Box', isOnline: true, itemCount: 8, items: [
            ReportEntry(box_id: 0xA3F1, status: 0, uid: 'TAG-2', name: 'Stove'),
          ]),
          BoxData(id: 0xB2C2, name: 'Gear Box', isOnline: false, lastSeen: '2 hours ago', itemCount: 7),
        ],
      ),
    ];
  }

  void startScan() async {
    if (bleClient is! MockBleClient) {
      if (await Permission.bluetoothScan.request().isGranted &&
          await Permission.bluetoothConnect.request().isGranted &&
          await Permission.location.request().isGranted) {
        bleClient.startScan();
      }
    } else {
      bleClient.startScan();
    }
    notifyListeners();
  }

  void _handleScanResults(List<ScanResult> results) {
    bool updated = false;
    for (var r in results) {
      int? companyId;
      Uint8List? payload;
      
      r.advertisementData.manufacturerData.forEach((id, bytes) {
         companyId = id;
         payload = Uint8List.fromList(bytes);
      });

      if (payload == null || payload!.length < 6) continue;

      try {
        final fullData = Uint8List(8);
        final view = ByteData.view(fullData.buffer);
        view.setUint16(0, companyId ?? 0xFFFF, Endian.little);
        fullData.setRange(2, 8, payload!);
        final adv = Adv.fromBytes(fullData);

        // FILTER: For testing, show ALL IMB meshes and Setup boxes
        // In a real app, this would filter by saved user meshes
        if (true) {
          final deviceId = r.device.remoteId.str;
          
          // Clear this device from any other mesh it might have belonged to
          for (var m in _discoveredMeshes) {
            if (m.pinHash != adv.pin_hash && m.device?.remoteId.str == deviceId) {
              m.device = null;
            }
          }
          
          // Clean up dead SETUP meshes
          _discoveredMeshes.removeWhere((m) => m.pinHash == 0 && m.device == null);

          int index = _discoveredMeshes.indexWhere((m) => m.pinHash == adv.pin_hash);

          if (index == -1) {
            String meshName = adv.op_mode == imb_op_modeValues[imb_op_mode.mode_setup] 
              ? "New Box (Setup)" 
              : BoxManager.parseBoxName(r.device.platformName) ?? "Mesh 0x${adv.pin_hash.toRadixString(16).toUpperCase()}";

            _discoveredMeshes.add(MeshData(
              name: meshName,
              pinHash: adv.pin_hash,
              boxCount: 1,
              device: r.device,
            ));
            updated = true;
          } else {
            _discoveredMeshes[index].device = r.device;
          }
        }

      } catch (e) {
        debugPrint("Discovery error: $e");
      }
    }
    if (updated) notifyListeners();
  }

  Future<void> selectMesh(MeshData mesh) async {
    _selectedMesh = mesh;
    _connectionStatus = ConnectionStatus.connecting;
    notifyListeners();

    if (mesh.device != null) {
      try {
        await bleClient.connect(mesh.device!, mesh.pinHash);
        _connectionStatus = ConnectionStatus.connected;
      } catch (e) {
        _connectionStatus = ConnectionStatus.disconnected;
      }
    } else if (bleClient is MockBleClient) {
       await Future.delayed(const Duration(seconds: 1));
       _connectionStatus = ConnectionStatus.connected;
    }
    
    notifyListeners();
  }

  Future<imb_ack_status> provisionBox(MeshData mesh, String boxName, String pin) async {
    _selectedMesh = mesh;
    _connectionStatus = ConnectionStatus.connecting;
    notifyListeners();

    try {
      // 1. Ensure we are connected and authenticated with PIN 0 (Setup mode)
      if (mesh.device != null) {
        await bleClient.connect(mesh.device!, 0);
      } else if (bleClient is! MockBleClient) {
        return imb_ack_status.ack_not_authed;
      }

      final pinHash = Crc32.compute(pin);
      _nameCompleter = Completer<imb_ack_status>();

      final cmd = CmdSetPin(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_set_pin]!,
        msg_id: 30,
        pin_hash: pinHash,
        box_name: boxName,
      );

      await bleClient.sendCommand(cmd.toBytes());
      
      // 2. Wait for EVENT_ACK[CMD_SET_PIN]
      final ackStatus = await _nameCompleter!.future.timeout(const Duration(seconds: 5));
      if (ackStatus != imb_ack_status.ack_ok) return ackStatus;

      // 3. Wait for EVENT_MODE[FIELD_CHECK]
      int waitCount = 0;
      while (_currentMode != imb_op_mode.mode_field_check && waitCount < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }

      // 4. Disconnect so we can see the new advertising name/PIN
      await bleClient.disconnect();
      _connectionStatus = ConnectionStatus.disconnected;
      
      return imb_ack_status.ack_ok;
    } on TimeoutException {
      return imb_ack_status.ack_not_authed;
    } catch (e) {
      debugPrint("Provisioning error: $e");
      return imb_ack_status.ack_not_authed;
    } finally {
      notifyListeners();
    }
  }

  Future<imb_ack_status> unbond() async {
    _nameCompleter = Completer<imb_ack_status>();
    final cmd = CmdUnbond(
      msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_unbond]!,
      msg_id: 50,
    );
    await bleClient.sendCommand(cmd.toBytes());
    
    try {
      final status = await _nameCompleter!.future.timeout(const Duration(seconds: 3));
      await bleClient.disconnect();
      _connectionStatus = ConnectionStatus.disconnected;
      return status;
    } on TimeoutException {
      await bleClient.disconnect();
      return imb_ack_status.ack_not_authed;
    } finally {
      notifyListeners();
    }
  }

  Future<imb_ack_status> renameBox(String newName) async {
    _nameCompleter = Completer<imb_ack_status>();

    final cmd = CmdBoxName(
      msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_box_name]!,
      msg_id: 40,
      name: newName,
    );

    await bleClient.sendCommand(cmd.toBytes());
    final status = await _nameCompleter!.future.timeout(const Duration(seconds: 3));
    return status;
  }

  void _handleBleEvent(List<int> data) {
    if (data.isEmpty) return;
    final msgType = data[0];
    
    debugPrint("BLE Event Received: type=0x${msgType.toRadixString(16)} data=$data");

    if (msgType == imb_msg_typeValues[imb_msg_type.msg_event_mode]) {
      final modeEvent = EventMode.fromBytes(Uint8List.fromList(data));
      final newMode = imb_op_mode.values.firstWhere(
        (m) => imb_op_modeValues[m] == modeEvent.mode,
        orElse: () => imb_op_mode.mode_field_check,
      );
      
      _isRegistrationIncomplete = (newMode == imb_op_mode.mode_registration_incomplete);

      if (_currentMode != newMode) {
        _currentMode = newMode;
        if (newMode == imb_op_mode.mode_registration) {
          bleClient.requestPriority(ConnectionPriority.balanced);
        } else if (newMode == imb_op_mode.mode_field_check) {
          bleClient.requestPriority(ConnectionPriority.high);
        }
        notifyListeners();
      }
    } else if (msgType == imb_msg_typeValues[imb_msg_type.msg_event_tag]) {
      final tagEvent = Eventag.fromBytes(Uint8List.fromList(data));
      if (tagEvent.name.isEmpty) {
        if (!_pendingTags.any((t) => t.uid == tagEvent.uid)) {
          _pendingTags.add(PendingTag(uid: tagEvent.uid));
          notifyListeners();
        }
      }
    } else if (msgType == imb_msg_typeValues[imb_msg_type.msg_event_ack]) {
      final ack = EventAck.fromBytes(Uint8List.fromList(data));
      final status = imb_ack_status.values.firstWhere(
        (st) => imb_ack_statusValues[st] == ack.status,
        orElse: () => imb_ack_status.ack_not_authed,
      );
      
      if (ack.acked_msg_type == imb_msg_typeValues[imb_msg_type.msg_cmd_name] ||
          ack.acked_msg_type == imb_msg_typeValues[imb_msg_type.msg_cmd_set_pin] ||
          ack.acked_msg_type == imb_msg_typeValues[imb_msg_type.msg_cmd_unbond] ||
          ack.acked_msg_type == imb_msg_typeValues[imb_msg_type.msg_cmd_box_name] ||
          ack.acked_msg_type == imb_msg_typeValues[imb_msg_type.msg_cmd_mode]) {
        _nameCompleter?.complete(status);
      }
    }
  }

  Future<bool> startRegistration() async {
    _nameCompleter = Completer<imb_ack_status>();
    final cmd = CmdMode(
      msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_mode]!,
      msg_id: 10,
      mode: imb_op_modeValues[imb_op_mode.mode_registration]!,
    );
    
    try {
      await bleClient.sendCommand(cmd.toBytes());
      final status = await _nameCompleter!.future.timeout(const Duration(seconds: 3));
      
      if (status == imb_ack_status.ack_ok) {
         // Wait briefly for the EVENT_MODE to arrive and update local state
         int waitCount = 0;
         while (_currentMode != imb_op_mode.mode_registration && waitCount < 10) {
           await Future.delayed(const Duration(milliseconds: 100));
           waitCount++;
         }
         return true;
      }
      return false;
    } catch (e) {
      debugPrint("startRegistration error: $e");
      return false;
    }
  }

  Future<bool> endRegistration() async {
    if (_pendingTags.isNotEmpty) {
      return false;
    }
    _nameCompleter = Completer<imb_ack_status>();
    final cmd = CmdMode(
      msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_mode]!,
      msg_id: 11,
      mode: imb_op_modeValues[imb_op_mode.mode_field_check]!,
    );
    
    try {
      await bleClient.sendCommand(cmd.toBytes());
      final status = await _nameCompleter!.future.timeout(const Duration(seconds: 3));
      
      if (status == imb_ack_status.ack_ok || status == imb_ack_status.ack_registration_incomplete) {
         // Wait briefly for EVENT_MODE
         int waitCount = 0;
         while (_currentMode == imb_op_mode.mode_registration && waitCount < 10) {
           await Future.delayed(const Duration(milliseconds: 100));
           waitCount++;
         }
         return status == imb_ack_status.ack_ok;
      }
      return false;
    } catch (e) {
      debugPrint("endRegistration error: $e");
      return false;
    }
  }

  Future<imb_ack_status> namePendingTag(String name) async {
    if (_pendingTags.isEmpty) return imb_ack_status.ack_unknown_uid;
    
    final currentTag = _pendingTags.first;
    imb_ack_status status = imb_ack_status.ack_not_authed;

    _nameCompleter = Completer<imb_ack_status>();
    
    final cmd = CmdName(
      msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_name]!,
      msg_id: 20, // Static ID for now, could be dynamic
      uid: currentTag.uid,
      name: name,
    );

    await bleClient.sendCommand(cmd.toBytes());
    
    try {
      // The firmware now manages the retry loop for up to 60 seconds (The "Long ACK")
      status = await _nameCompleter!.future.timeout(const Duration(seconds: 60));
      if (status == imb_ack_status.ack_ok) {
        _pendingTags.removeFirst();
        notifyListeners();
      }
    } on TimeoutException {
      status = imb_ack_status.ack_ndef_write_failed; 
    } catch (e) {
      status = imb_ack_status.ack_not_authed;
    }
    
    return status;
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _scanSub?.cancel();
    super.dispose();
  }
}
