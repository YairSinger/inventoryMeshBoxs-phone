import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:inventory_mesh_box_phone/protocol.dart';
import 'package:inventory_mesh_box_phone/src/ble_client.dart';
import 'package:inventory_mesh_box_phone/src/box_session_provider.dart';

@GenerateMocks([IBleClient, BluetoothDevice])
import 'box_session_provider_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockIBleClient mockBleClient;
  late BoxSessionProvider provider;
  late StreamController<List<int>> eventController;
  late StreamController<List<ScanResult>> scanController;

  setUp(() {
    mockBleClient = MockIBleClient();
    eventController = StreamController<List<int>>();
    scanController = StreamController<List<ScanResult>>();
    
    when(mockBleClient.eventStream).thenAnswer((_) => eventController.stream);
    when(mockBleClient.scanResults).thenAnswer((_) => scanController.stream);
    when(mockBleClient.startScan()).thenAnswer((_) async => {});
    when(mockBleClient.stopScan()).thenAnswer((_) async => {});
    
    provider = BoxSessionProvider(bleClient: mockBleClient);
  });

  tearDown(() {
    eventController.close();
    scanController.close();
  });

  group('Slice 1: Mode Synchronization', () {
    test('Should update currentMode when EVENT_MODE is received', () async {
      final modeEvent = EventMode(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_mode]!,
        mode: imb_op_modeValues[imb_op_mode.mode_registration]!,
      );

      eventController.add(modeEvent.toBytes());
      await Future.microtask(() {});

      expect(provider.currentMode, imb_op_mode.mode_registration);
    });
  });

  group('Slice 2: The Naming Queue', () {
    test('Should add tag to pending queue when EVENT_TAG with empty name is received', () async {
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
    test('Should remove tag from queue after successful CMD_NAME', () async {
      final tagEvent = Eventag(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_tag]!,
        direction: 0,
        uid: "TAG123",
        name: "",
      );
      eventController.add(tagEvent.toBytes());
      await Future.microtask(() {});
      expect(provider.hasPendingTags, true);

      when(mockBleClient.sendCommand(any)).thenAnswer((_) async {
        final ack = EventAck(
          msg_type: imb_msg_typeValues[imb_msg_type.msg_event_ack]!,
          acked_msg_id: 20, 
          acked_msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_name]!,
          status: imb_ack_statusValues[imb_ack_status.ack_ok]!,
        );
        eventController.add(ack.toBytes());
      });

      final status = await provider.namePendingTag("flashlight");

      expect(status, imb_ack_status.ack_ok);
      expect(provider.hasPendingTags, false);
      verify(mockBleClient.sendCommand(any)).called(1);
    });
  });

  group('Slice 4: Async Naming Failure', () {
    test('Should return failure status after single long ACK response', () async {
      final tagEvent = Eventag(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_tag]!,
        direction: 0,
        uid: "TAG_FAIL",
        name: "",
      );
      eventController.add(tagEvent.toBytes());
      await Future.microtask(() {});

      when(mockBleClient.sendCommand(any)).thenAnswer((_) async {
        final ack = EventAck(
          msg_type: imb_msg_typeValues[imb_msg_type.msg_event_ack]!,
          acked_msg_id: 20,
          acked_msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_name]!,
          status: imb_ack_statusValues[imb_ack_status.ack_ndef_write_failed]!,
        );
        eventController.add(ack.toBytes());
      });

      final status = await provider.namePendingTag("broken-tag");

      expect(status, imb_ack_status.ack_ndef_write_failed);
      expect(provider.hasPendingTags, true); // Still in queue
      verify(mockBleClient.sendCommand(any)).called(1); // No retries anymore
    });
  });

  group('Slice 5: Registration Incomplete Gate', () {
    test('Should block endRegistration if pending tags exist', () async {
      final tagEvent = Eventag(
        msg_type: imb_msg_typeValues[imb_msg_type.msg_event_tag]!,
        direction: 0,
        uid: "TAG_GATE",
        name: "",
      );
      eventController.add(tagEvent.toBytes());
      await Future.microtask(() {});

      final success = await provider.endRegistration();

      expect(success, false);
      verifyNever(mockBleClient.sendCommand(any));
    });

    test('Should allow endRegistration if queue is empty', () async {
      when(mockBleClient.sendCommand(any)).thenAnswer((invocation) async {
        final Uint8List data = invocation.positionalArguments[0];
        if (data[0] == imb_msg_typeValues[imb_msg_type.msg_cmd_mode]!) {
          final ack = EventAck(
            msg_type: imb_msg_typeValues[imb_msg_type.msg_event_ack]!,
            acked_msg_id: data[1],
            acked_msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_mode]!,
            status: imb_ack_statusValues[imb_ack_status.ack_ok]!,
          );
          eventController.add(ack.toBytes());
          
          final modeEvent = EventMode(
            msg_type: imb_msg_typeValues[imb_msg_type.msg_event_mode]!,
            mode: imb_op_modeValues[imb_op_mode.mode_field_check]!,
          );
          eventController.add(modeEvent.toBytes());
        }
      });

      // Clear pending tags
      while(provider.pendingTags.isNotEmpty) {
         provider.pendingTags.removeFirst();
      }

      final success = await provider.endRegistration();

      expect(success, true);
      verify(mockBleClient.sendCommand(any)).called(1);
    });
  });

  group('Slice 6: Mesh Management', () {
    setUp(() {
       provider.discoveredMeshes.add(
         MeshData(
            name: 'Camping Trip',
            pinHash: 0x12345678,
            boxCount: 2,
            itemCount: 15,
         )
       );
    });

    test('Should populate discovered meshes from cache', () {
      expect(provider.discoveredMeshes.isNotEmpty, true);
      expect(provider.discoveredMeshes.first.name, 'Camping Trip');
    });

    test('Should transition connection status when mesh is selected', () async {
      final mesh = provider.discoveredMeshes.first;
      mesh.device = MockBluetoothDevice();
      
      when(mockBleClient.connect(any, any)).thenAnswer((_) async => {});
      
      final future = provider.selectMesh(mesh);
      
      expect(provider.connectionStatus, ConnectionStatus.connecting);
      expect(provider.selectedMesh, mesh);
      
      await future;
      expect(provider.connectionStatus, ConnectionStatus.connected);
    });

    test('Should send CMD_SET_PIN when provisionBox is called', () async {
      final mesh = MeshData(pinHash: 0, name: 'New Box (Setup)');
      mesh.device = MockBluetoothDevice();
      
      await provider.selectMesh(mesh);
      
      when(mockBleClient.connect(any, any)).thenAnswer((_) async => {});
      when(mockBleClient.disconnect()).thenAnswer((_) async => {});
      
      when(mockBleClient.sendCommand(any)).thenAnswer((invocation) async {
          final Uint8List data = invocation.positionalArguments[0];
          if (data[0] == imb_msg_typeValues[imb_msg_type.msg_cmd_set_pin]!) {
            final ack = EventAck(
              msg_type: imb_msg_typeValues[imb_msg_type.msg_event_ack]!,
              acked_msg_id: data[1],
              acked_msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_set_pin]!,
              status: imb_ack_statusValues[imb_ack_status.ack_ok]!,
            );
            eventController.add(ack.toBytes());
            
            final modeEvent = EventMode(
              msg_type: imb_msg_typeValues[imb_msg_type.msg_event_mode]!,
              mode: imb_op_modeValues[imb_op_mode.mode_field_check]!,
            );
            eventController.add(modeEvent.toBytes());
          }
      });

      final status = await provider.provisionBox(mesh, 'Kitchen Box', '1234');
      
      expect(status, imb_ack_status.ack_ok);

      verify(mockBleClient.sendCommand(argThat(
        predicate((Uint8List bytes) => bytes[0] == imb_msg_typeValues[imb_msg_type.msg_cmd_set_pin])
      ))).called(1);
    });
  });
}
