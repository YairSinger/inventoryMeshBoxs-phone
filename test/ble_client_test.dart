import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:inventory_mesh_box_phone/protocol.dart';
import 'package:inventory_mesh_box_phone/src/ble_client.dart';
import 'ble_client_test.mocks.dart';

@GenerateMocks([BluetoothDevice, BluetoothService, BluetoothCharacteristic])
void main() {
  late BleClient client;
  late MockBluetoothDevice mockDevice;
  late MockBluetoothService mockService;
  late MockBluetoothCharacteristic mockEventChar;
  late MockBluetoothCharacteristic mockCommandChar;

  setUp(() {
    client = BleClient(pinHash: 0x12345678);
    mockDevice = MockBluetoothDevice();
    mockService = MockBluetoothService();
    mockEventChar = MockBluetoothCharacteristic();
    mockCommandChar = MockBluetoothCharacteristic();

    when(mockDevice.connect()).thenAnswer((_) async => {});
    when(mockDevice.discoverServices()).thenAnswer((_) async => [mockService]);
    when(mockService.uuid).thenReturn(Guid(IMB_SERVICE_UUID));
    when(mockService.characteristics).thenReturn([mockEventChar, mockCommandChar]);
    
    when(mockEventChar.uuid).thenReturn(Guid(IMB_CHAR_EVENT_NOTIFY));
    when(mockEventChar.setNotifyValue(true)).thenAnswer((_) async => true);
    
    when(mockCommandChar.uuid).thenReturn(Guid(IMB_CHAR_COMMAND_WRITE));
  });

  group('BleClient Handshake', () {
    test('GREEN: Should execute HELLO handshake on connect', () async {
      final eventController = StreamController<List<int>>();
      when(mockEventChar.lastValueStream).thenAnswer((_) => eventController.stream);

      when(mockCommandChar.write(any)).thenAnswer((_) async {
        final ack = EventAck(
          msg_type: imb_msg_typeValues[imb_msg_type.msg_event_ack]!,
          acked_msg_id: 1,
          acked_msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_hello]!,
          status: imb_ack_statusValues[imb_ack_status.ack_ok]!,
        );
        eventController.add(ack.toBytes());
        return null;
      });

      await client.connect(mockDevice);
      
      expect(client.isAuthenticated, true);
      verify(mockCommandChar.write(any)).called(1);
      
      await eventController.close();
    });

    test('GREEN: Should fail if PIN mismatch', () async {
      final eventController = StreamController<List<int>>();
      when(mockEventChar.lastValueStream).thenAnswer((_) => eventController.stream);

      when(mockCommandChar.write(any)).thenAnswer((_) async {
        final ack = EventAck(
          msg_type: imb_msg_typeValues[imb_msg_type.msg_event_ack]!,
          acked_msg_id: 1,
          acked_msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_hello]!,
          status: imb_ack_statusValues[imb_ack_status.ack_pin_mismatch]!,
        );
        eventController.add(ack.toBytes());
        return null;
      });

      await expectLater(client.connect(mockDevice, 0), throwsException);
      
      await eventController.close();
    });
  });
}
