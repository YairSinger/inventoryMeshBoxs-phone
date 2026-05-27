import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_mesh_box_phone/protocol.dart';
import 'package:inventory_mesh_box_phone/src/box_manager.dart';

void main() {
  group('BLE Discovery', () {
    test('GREEN: Should parse advertisement manufacturer data correctly', () {
      final rawData = Uint8List.fromList([
        0xFF, 0xFF,
        0x78, 0x56, 0x34, 0x12,
        0x01,
        0x01,
      ]);

      final adv = Adv.fromBytes(rawData);

      expect(adv.company_id, 0xFFFF);
      expect(adv.pin_hash, 0x12345678);
      expect(adv.op_mode, imb_op_modeValues[imb_op_mode.mode_field_check]);
      expect(adv.flags, 0x01);
    });

    test('GREEN: Should identify if a box belongs to our mesh', () {
      final myPinHash = 0x12345678;
      final adv = Adv(
        company_id: 0xFFFF,
        pin_hash: 0x12345678,
        op_mode: 1,
        flags: 0,
      );

      final isMyBox = BoxManager.isMyBox(adv, myPinHash);
      expect(isMyBox, true);
    });

    test('GREEN: Should reject a box from a different mesh', () {
      final myPinHash = 0x12345678;
      final adv = Adv(
        company_id: 0xFFFF,
        pin_hash: 0xAAAAAAAA,
        op_mode: 1,
        flags: 0,
      );

      final isMyBox = BoxManager.isMyBox(adv, myPinHash);
      expect(isMyBox, false);
    });

    test('GREEN: Should parse box name correctly', () {
      expect(BoxManager.parseBoxName("IMB-kitchen-A3F1"), "kitchen");
      expect(BoxManager.parseBoxName("IMB-livingroom-B2C4"), "livingroom");
      expect(BoxManager.parseBoxName("OTHER-DEVICE"), null);
    });
  });
}
