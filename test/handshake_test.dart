import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_mesh_box_phone/protocol.dart';

void main() {
  group('Tracer Bullet: CMD_HELLO Handshake', () {
    test('GREEN: CmdHello should round-trip correctly', () {
      final hello = CmdHello(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_hello]!,
        msg_id: 1,
        pin_hash: 0x12345678,
      );
      
      final bytes = hello.toBytes();
      expect(bytes.length, 6); // 1 + 1 + 4
      
      final unpacked = CmdHello.fromBytes(bytes);
      expect(unpacked.msg_type, hello.msg_type);
      expect(unpacked.msg_id, hello.msg_id);
      expect(unpacked.pin_hash, hello.pin_hash);
    });

    test('GREEN: EventAck should round-trip correctly', () {
      final ack = EventAck(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_ack]!,
        acked_msg_id: 1,
        acked_msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_hello]!,
        status: imb_ack_statusValues[imb_ack_status.ack_ok]!,
      );
      
      final bytes = ack.toBytes();
      expect(bytes.length, 4);
      
      final unpacked = EventAck.fromBytes(bytes);
      expect(unpacked.status, imb_ack_statusValues[imb_ack_status.ack_ok]);
    });
  });
}
