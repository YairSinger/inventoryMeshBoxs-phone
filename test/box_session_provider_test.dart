import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:inventory_mesh_box_phone/protocol.dart';
import 'package:inventory_mesh_box_phone/src/ble_client.dart';
import 'package:inventory_mesh_box_phone/src/box_session_provider.dart';

@GenerateMocks([IBleClient])
import 'box_session_provider_test.mocks.dart';

void main() {
  late MockIBleClient mockBleClient;
  late BoxSessionProvider provider;
  late StreamController<List<int>> eventController;

  setUp(() {
    mockBleClient = MockIBleClient();
    eventController = StreamController<List<int>>.broadcast();
    when(mockBleClient.eventStream).thenAnswer((_) => eventController.stream);
    
    provider = BoxSessionProvider(bleClient: mockBleClient);
  });

  tearDown(() {
    eventController.close();
  });

  group('Slice 1: Mode Synchronization', () {
    test('RED: Should update currentMode when EVENT_MODE is received', () async {
      final modeEvent = EventMode(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_mode]!,
        mode: imb_op_modeValues[imb_op_mode.mode_registration]!,
      );

      eventController.add(modeEvent.toBytes());

      // Give it a microtask to process
      await Future.microtask(() {});

      expect(provider.currentMode, imb_op_mode.mode_registration);
    });
  });

  group('Slice 2: The Naming Queue', () {
    test('RED: Should add tag to pending queue when EVENT_TAG with empty name is received', () async {
      final tagEvent = Eventag(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_tag]!,
        direction: 0, // INSERT
        uid: "ABC123DEF45678",
        name: "", // Unnamed
      );

      eventController.add(tagEvent.toBytes());
      await Future.microtask(() {});

      expect(provider.hasPendingTags, true);
      expect(provider.pendingTags.first.uid, "ABC123DEF45678");
    });
  });

  group('Slice 3: Successful Naming', () {
    test('RED: Should remove tag from queue after successful CMD_NAME', () async {
      // 1. Add a pending tag
      final tagEvent = Eventag(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_tag]!,
        direction: 0,
        uid: "TAG123",
        name: "",
      );
      eventController.add(tagEvent.toBytes());
      await Future.microtask(() {});
      expect(provider.hasPendingTags, true);

      // 2. Mock successful ACK
      when(mockBleClient.sendCommand(any)).thenAnswer((_) async {
        final ack = EventAck(
          msg_type: imb_msg_typeValues[imb_msg_type.msg_event_ack]!,
          acked_msg_id: 20, // Our implementation uses 20 for first name attempt
          acked_msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_name]!,
          status: imb_ack_statusValues[imb_ack_status.ack_ok]!,
        );
        eventController.add(ack.toBytes());
      });

      // 3. Name the tag
      final status = await provider.namePendingTag("flashlight");

      expect(status, imb_ack_status.ack_ok);
      expect(provider.hasPendingTags, false);
      
      // Verify command sent
      verify(mockBleClient.sendCommand(any)).called(1);
    });
  });

  group('Slice 4: Automatic Retry', () {
    test('RED: Should retry 3 times on NDEF_WRITE_FAILED', () async {
      // 1. Add a pending tag
      final tagEvent = Eventag(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_tag]!,
        direction: 0,
        uid: "TAG_RETRY",
        name: "",
      );
      eventController.add(tagEvent.toBytes());
      await Future.microtask(() {});

      int callCount = 0;
      when(mockBleClient.sendCommand(any)).thenAnswer((_) async {
        callCount++;
        // Always fail with NDEF_WRITE_FAILED
        final ack = EventAck(
          msg_type: imb_msg_typeValues[imb_msg_type.msg_event_ack]!,
          acked_msg_id: 20 + (callCount - 1),
          acked_msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_name]!,
          status: imb_ack_statusValues[imb_ack_status.ack_ndef_write_failed]!,
        );
        eventController.add(ack.toBytes());
      });

      // 2. Attempt naming (should retry and fail after 3)
      final status = await provider.namePendingTag("broken-tag");

      expect(status, imb_ack_status.ack_ndef_write_failed);
      expect(callCount, 3);
      expect(provider.hasPendingTags, true); // Still in queue
    });
  });

  group('Slice 5: Registration Incomplete Gate', () {
    test('RED: Should block endRegistration if pending tags exist', () async {
      // 1. Add a pending tag
      final tagEvent = Eventag(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_tag]!,
        direction: 0,
        uid: "TAG_GATE",
        name: "",
      );
      eventController.add(tagEvent.toBytes());
      await Future.microtask(() {});

      // 2. Try to end registration
      final success = await provider.endRegistration();

      expect(success, false);
      verifyNever(mockBleClient.sendCommand(any));
    });

    test('GREEN: Should allow endRegistration if queue is empty', () async {
      when(mockBleClient.sendCommand(any)).thenAnswer((_) async => {});

      final success = await provider.endRegistration();

      expect(success, true);
      verify(mockBleClient.sendCommand(any)).called(1);
    });
  });
}
