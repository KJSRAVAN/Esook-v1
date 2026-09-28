/// Helper utility for international authentication phone number validation and normalization.
///
/// Complies with ITU E.164 international standards and backend auth schemas:
/// - Canonical format: `+[1-9]\d{7,14}` (8 to 15 digits total, country code never starts with 0).
/// - Accepts international numbers globally (e.g. India +91, Saudi Arabia +966, Oman +968, etc.).
/// - Does NOT silently guess or assign local numbers without explicit country context.
abstract final class AuthPhoneHelper {
  /// Regular expression for canonical E.164 international phone numbers:
  /// Starts with '+', first digit [1-9] (country code cannot start with 0),
  /// followed by 7 to 14 digits (8 to 15 total digits).
  static final RegExp e164Regex = RegExp(r'^\+[1-9]\d{7,14}$');

  /// Normalizes an international authentication phone number into canonical E.164 format.
  ///
  /// - Strips common user formatting: spaces, hyphens, parentheses, brackets, and periods.
  /// - Converts standard international dialing prefix `00` to `+`.
  /// - Accepts valid E.164 numbers with or without a leading `+`.
  /// - Rejects malformed numbers, non-digits, country codes starting with 0, and under/overlength inputs.
  /// - Rejects local numbers starting with 0 (e.g. `05XXXXXXXX`) to prevent silently assuming an incorrect country.
  ///
  /// Returns the canonical E.164 string (`+...`) or `null` if invalid.
  static String? normalizeAuthPhone(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // 1. Strip common formatting characters
    String cleaned = trimmed.replaceAll(RegExp(r'[\s\-\(\)\[\]\.]'), '');
    if (cleaned.isEmpty) return null;

    // 2. Reject inputs with illegal characters (letters, symbols other than optional leading '+')
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(cleaned)) {
      return null;
    }

    // 3. Convert standard international prefix '00' to '+'
    if (cleaned.startsWith('00')) {
      cleaned = '+${cleaned.substring(2)}';
    }

    // 4. Validate numbers with explicit '+'
    if (cleaned.startsWith('+')) {
      if (e164Regex.hasMatch(cleaned)) {
        return cleaned;
      }
      return null;
    }

    // 5. If no leading '+', local numbers starting with '0' cannot be safely inferred
    if (cleaned.startsWith('0')) {
      return null;
    }

    // 6. If digits start with [1-9] and fall within 8 to 15 total digits, prepend canonical '+'
    if (RegExp(r'^[1-9]\d{7,14}$').hasMatch(cleaned)) {
      return '+$cleaned';
    }

    return null;
  }

  /// Returns `true` if [input] can be normalized to a valid international E.164 phone number.
  static bool isValidAuthPhone(String? input) {
    return normalizeAuthPhone(input) != null;
  }

  /// Form field validator for authentication phone inputs.
  ///
  /// Returns [requiredMessage] when empty, an invalid format message if normalization fails,
  /// or `null` if valid.
  static String? validateAuthPhone(
    String? value, {
    String requiredMessage = 'Please enter your phone number',
  }) {
    if (value == null || value.trim().isEmpty) {
      return requiredMessage;
    }
    if (normalizeAuthPhone(value) == null) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  /// Normalizes a phone number with an explicit country context.
  ///
  /// Only applies country-specific local conversions if [defaultCountryCode] is explicitly provided.
  /// Generic authentication calls should use [normalizeAuthPhone].
  static String? normalizeWithCountryContext(
    String? input, {
    String? defaultCountryCode,
  }) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final standard = normalizeAuthPhone(trimmed);
    if (standard != null) return standard;

    if (defaultCountryCode != null && defaultCountryCode.isNotEmpty) {
      final cleaned = trimmed.replaceAll(RegExp(r'[\s\-\(\)\[\]\.]'), '');
      if (defaultCountryCode == '+966' || defaultCountryCode == '966') {
        if (cleaned.startsWith('05') &&
            cleaned.length == 10 &&
            RegExp(r'^05\d{8}$').hasMatch(cleaned)) {
          return '+966${cleaned.substring(1)}';
        }
      }
    }

    return null;
  }
}
