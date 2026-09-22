/// Helper utility for Saudi Arabia phone number normalization and validation.
///
/// Production backend contract requires Saudi mobile numbers in exact E.164 format:
/// `+9665XXXXXXXX` (13 characters total, country code `+966`, mobile digit `5`, and 8 subscriber digits).
abstract final class SaudiPhoneHelper {
  /// Regular expression strictly matching Saudi mobile E.164 numbers (+9665XXXXXXXX).
  static final RegExp saudiMobileRegex = RegExp(r'^\+9665\d{8}$');

  /// Normalizes user-inputted phone numbers to the canonical Saudi E.164 format (`+9665XXXXXXXX`).
  ///
  /// Strips formatting whitespace, hyphens, brackets, and periods.
  /// Converts:
  /// - `05XXXXXXXX` (10 digits) -> `+9665XXXXXXXX`
  /// - `5XXXXXXXX` (9 digits) -> `+9665XXXXXXXX`
  /// - `9665XXXXXXXX` (12 digits) -> `+9665XXXXXXXX`
  /// - `009665XXXXXXXX` (14 digits) -> `+9665XXXXXXXX`
  /// - `+966 5X XXX XXXX` (with spaces) -> `+9665XXXXXXXX`
  ///
  /// Returns `null` if the input cannot be normalized into a valid Saudi mobile number.
  static String? normalizeSaudiPhone(String? input) {
    if (input == null) return null;

    // 1. Remove all spaces, dashes, brackets, and periods
    String cleaned = input.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (cleaned.isEmpty) return null;

    // 2. Replace international dialing prefix '00966'
    if (cleaned.startsWith('00966')) {
      cleaned = '+966${cleaned.substring(5)}';
    } else if (cleaned.startsWith('00')) {
      // Non-Saudi international dialing prefix
      return null;
    }

    // 3. Handle '966' without '+'
    if (cleaned.startsWith('966')) {
      cleaned = '+$cleaned';
    }

    // 4. Handle local Saudi format '05XXXXXXXX' (10 digits)
    if (cleaned.startsWith('05') &&
        cleaned.length == 10 &&
        RegExp(r'^05\d{8}$').hasMatch(cleaned)) {
      cleaned = '+966${cleaned.substring(1)}';
    }

    // 5. Handle local 9-digit mobile number starting with '5'
    if (cleaned.startsWith('5') &&
        cleaned.length == 9 &&
        RegExp(r'^5\d{8}$').hasMatch(cleaned)) {
      cleaned = '+966$cleaned';
    }

    // 6. Validate against exact Saudi E.164 mobile pattern
    if (saudiMobileRegex.hasMatch(cleaned)) {
      return cleaned;
    }

    return null;
  }

  /// Returns `true` if [input] can be normalized to a valid Saudi mobile number.
  static bool isValidSaudiPhone(String? input) {
    return normalizeSaudiPhone(input) != null;
  }

  /// Form validation function for Saudi mobile phone fields.
  static String? validateSaudiPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your registered staff phone number';
    }
    if (normalizeSaudiPhone(value) == null) {
      return 'Please enter a valid Saudi mobile number (+966 5X XXX XXXX)';
    }
    return null;
  }

  /// Normalizes store contact phone numbers.
  ///
  /// Supports both Saudi mobile (+9665XXXXXXXX) and landlines (+96611XXXXXXX, +96612XXXXXXX, etc.).
  /// Removes formatting spaces, dashes, parentheses, and dots.
  /// Converts local formats (011..., 012..., 05...) to +966 international format.
  /// Does NOT silently truncate strings exceeding 20 characters.
  static String? normalizeStorePhone(String? input) {
    if (input == null) return null;
    final cleaned = input.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (cleaned.isEmpty) return null;

    String formatted = cleaned;
    if (formatted.startsWith('00966')) {
      formatted = '+966${formatted.substring(5)}';
    } else if (formatted.startsWith('00')) {
      formatted = '+${formatted.substring(2)}';
    }

    if (formatted.startsWith('966')) {
      formatted = '+$formatted';
    }

    // Local Saudi number starting with 0 (011... Riyadh landline, 012... Jeddah landline, 05... mobile)
    if (formatted.startsWith('0') &&
        formatted.length >= 9 &&
        RegExp(r'^0\d+$').hasMatch(formatted)) {
      formatted = '+966${formatted.substring(1)}';
    }

    return formatted;
  }

  /// Form validation for store contact phone.
  ///
  /// - Returns `null` if empty (store phone is optional).
  /// - Rejects strings containing letters or invalid punctuation.
  /// - Enforces the 20-character maximum database limit without silent truncation.
  /// - Rejects underlength numbers.
  static String? validateStorePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final trimmed = value.trim();
    final rawCleaned = trimmed.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // Disallow alphabetic / invalid characters
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(rawCleaned)) {
      return 'Please enter a valid contact phone number';
    }

    final normalized = normalizeStorePhone(trimmed);
    if (normalized == null) {
      return 'Please enter a valid contact phone number';
    }

    // Backend database column constraint is VARCHAR(20)
    if (normalized.length > 20) {
      return 'Phone number cannot exceed 20 characters';
    }

    if (normalized.length < 8) {
      return 'Please enter a valid phone number';
    }

    return null;
  }
}
