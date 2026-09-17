import 'dart:math';

/// Utility to generate RFC 4122 compliant UUID v4 strings without external packages.
class UuidHelper {
  static final Random _random = Random.secure();

  /// Generates a random UUID v4 string (e.g. `e3b0c442-98fc-4c14-9afe-36a536f96614`).
  static String generateV4() {
    final values = List<int>.generate(16, (i) => _random.nextInt(256));
    // Set version 4 (bits 12-15 of time_hi_and_version to 0100)
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant (bits 6-7 of clock_seq_hi_and_reserved to 10)
    values[8] = (values[8] & 0x3f) | 0x80;

    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex[0]}${hex[1]}${hex[2]}${hex[3]}-'
        '${hex[4]}${hex[5]}-'
        '${hex[6]}${hex[7]}-'
        '${hex[8]}${hex[9]}-'
        '${hex[10]}${hex[11]}${hex[12]}${hex[13]}${hex[14]}${hex[15]}';
  }
}
