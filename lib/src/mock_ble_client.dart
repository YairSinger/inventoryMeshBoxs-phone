import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../protocol.dart';
import 'ble_client.dart';

class MockBleClient implements IBleClient {
  final _eventStreamController = StreamController<List<int>>.broadcast();
  @override
  Stream<List<int>> get eventStream => _eventStreamController.stream;

  bool _isAuthenticated = false;
  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Future<void> connect(BluetoothDevice device) async {
    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 500));
    _isAuthenticated = true;
  }

  @override
  Future<void> sendCommand(Uint8List data) async {
    final msgType = data[0];
    final msgId = data[1];

    // Simulate box logic for various commands
    if (msgType == imb_msg_typeValues[imb_msg_type.msg_cmd_mode]) {
      final cmd = CmdMode.fromBytes(data);
      // Respond with ACK OK
      final ack = EventAck(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_ack]!,
        acked_msg_id: msgId,
        acked_msg_type: msgType,
        status: imb_ack_statusValues[imb_ack_status.ack_ok]!,
      );
      _eventStreamController.add(ack.toBytes());

      // Then fire EVENT_MODE
      final modeEvent = EventMode(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_mode]!,
        mode: cmd.mode,
      );
      _eventStreamController.add(modeEvent.toBytes());
    } 
    else if (msgType == imb_msg_typeValues[imb_msg_type.msg_cmd_name]) {
      final cmd = CmdName.fromBytes(data);
      
      // Simulate slow NDEF write (1s)
      await Future.delayed(const Duration(seconds: 1));

      // Respond with ACK OK
      final ack = EventAck(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_ack]!,
        acked_msg_id: msgId,
        acked_msg_type: msgType,
        status: imb_ack_statusValues[imb_ack_status.ack_ok]!,
      );
      _eventStreamController.add(ack.toBytes());

      // Also fire an INSERT EVENT_TAG with the new name to update inventory
      final tagEvent = Eventag(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_tag]!,
        direction: 0, // INSERT
        uid: cmd.uid,
        name: cmd.name,
      );
      _eventStreamController.add(tagEvent.toBytes());
    }
  }

  @override
  Future<void> disconnect() async {
    _isAuthenticated = false;
  }

  // Debug helper: Simulate a tag drop from the UI
  void simulateTagDrop(String uid) {
    final tagEvent = Eventag(
      msg_type: imb_msg_typeValues[imb_msg_type.msg_event_tag]!,
      direction: 0, // INSERT
      uid: uid,
      name: "", // Unnamed
    );
    _eventStreamController.add(tagEvent.toBytes());
  }
}
