import '../protocol.dart';

class BoxManager {
  /// Returns true if the advertisement manufacturer data matches the expected PIN hash.
  static bool isMyBox(Adv adv, int expectedPinHash) {
    return adv.pin_hash == expectedPinHash;
  }

  /// Extracts the box name from the full advertisement name (e.g., "IMB-kitchen-A3F1" -> "kitchen")
  static String? parseBoxName(String advName) {
    final parts = advName.split('-');
    if (parts.length >= 3 && parts[0] == 'IMB') {
      return parts[1];
    }
    return null;
  }
}
