import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../protocol.dart';
import 'ble_client.dart';

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
  final int boxCount;
  final int itemCount;
  final List<ReportEntry> missingItems;
  final List<LogEntryData> recentEvents;
  final List<BoxData> boxes;

  MeshData({
    required this.pinHash,
    required this.name,
    this.boxCount = 0,
    this.itemCount = 0,
    this.missingItems = const [],
    this.recentEvents = const [],
    this.boxes = const [],
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
  Completer<imb_ack_status>? _nameCompleter;

  BoxSessionProvider({required this.bleClient}) {
    _eventSub = bleClient.eventStream.listen(_handleBleEvent);
    _loadCachedMeshes();
    startScan();
  }

  void _loadCachedMeshes() {
    // Mocking cached data for now
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

  void startScan() {
    // In a real app, this would trigger BLE scanning
    notifyListeners();
  }

  void selectMesh(MeshData mesh) async {
    _selectedMesh = mesh;
    _connectionStatus = ConnectionStatus.connecting;
    notifyListeners();

    // Simulate connection
    await Future.delayed(const Duration(seconds: 1));
    _connectionStatus = ConnectionStatus.connected;
    
    // In real app: bleClient.connect(mesh.address)
    // Then send CMD_HELLO and CMD_GET_LOG
    notifyListeners();
  }

  void _handleBleEvent(List<int> data) {
    if (data.isEmpty) return;
    final msgType = data[0];

    if (msgType == imb_msg_typeValues[imb_msg_type.msg_event_mode]) {
      final modeEvent = EventMode.fromBytes(Uint8List.fromList(data));
      _currentMode = imb_op_mode.values.firstWhere(
        (m) => imb_op_modeValues[m] == modeEvent.mode,
        orElse: () => imb_op_mode.mode_field_check,
      );
      notifyListeners();
    } else if (msgType == imb_msg_typeValues[imb_msg_type.msg_event_tag]) {
      final tagEvent = Eventag.fromBytes(Uint8List.fromList(data));
      if (tagEvent.name.isEmpty) {
        if (!_pendingTags.any((t) => t.uid == tagEvent.uid)) {
          _pendingTags.add(PendingTag(uid: tagEvent.uid));
          notifyListeners();
        }
      }
      // Real-time updates to _selectedMesh would go here
    } else if (msgType == imb_msg_typeValues[imb_msg_type.msg_event_ack]) {
      final ack = EventAck.fromBytes(Uint8List.fromList(data));
      if (ack.acked_msg_type == imb_msg_typeValues[imb_msg_type.msg_cmd_name]) {
        final status = imb_ack_status.values.firstWhere(
          (st) => imb_ack_statusValues[st] == ack.status,
          orElse: () => imb_ack_status.ack_not_authed,
        );
        _nameCompleter?.complete(status);
      }
    }
  }

  Future<bool> startRegistration() async {
    final cmd = CmdMode(
      msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_mode]!,
      msg_id: 10,
      mode: imb_op_modeValues[imb_op_mode.mode_registration]!,
    );
    await bleClient.sendCommand(cmd.toBytes());
    return true;
  }

  Future<bool> endRegistration() async {
    if (_pendingTags.isNotEmpty) {
      return false;
    }
    final cmd = CmdMode(
      msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_mode]!,
      msg_id: 11,
      mode: imb_op_modeValues[imb_op_mode.mode_field_check]!,
    );
    await bleClient.sendCommand(cmd.toBytes());
    return true;
  }

  Future<imb_ack_status> namePendingTag(String name) async {
    if (_pendingTags.isEmpty) return imb_ack_status.ack_unknown_uid;
    final currentTag = _pendingTags.first;
    _nameCompleter = Completer<imb_ack_status>();

    final cmd = CmdName(
      msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_name]!,
      msg_id: 20,
      uid: currentTag.uid,
      name: name,
    );

    await bleClient.sendCommand(cmd.toBytes());
    final status = await _nameCompleter!.future.timeout(const Duration(seconds: 3));
    if (status == imb_ack_status.ack_ok) {
      _pendingTags.removeFirst();
      notifyListeners();
    }
    return status;
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}
