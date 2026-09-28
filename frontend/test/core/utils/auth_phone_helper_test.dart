import 'package:esouq/core/utils/auth_phone_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthPhoneHelper', () {
    group('normalizeAuthPhone - International Numbers', () {
      test('accepts valid Indian phone number (+919876543210)', () {
        expect(
          AuthPhoneHelper.normalizeAuthPhone('+919876543210'),
          equals('+919876543210'),
        );
      });

      test('accepts valid Saudi phone number (+966501234567)', () {
        expect(
          AuthPhoneHelper.normalizeAuthPhone('+966501234567'),
          equals('+966501234567'),
        );
      });

      test('accepts valid Omani phone number (+96891234567)', () {
        expect(
          AuthPhoneHelper.normalizeAuthPhone('+96891234567'),
          equals('+96891234567'),
        );
      });

      test('accepts other valid international E.164 numbers (+1, +44, etc.)', () {
        expect(
          AuthPhoneHelper.normalizeAuthPhone('+14155552671'),
          equals('+14155552671'),
        );
        expect(
          AuthPhoneHelper.normalizeAuthPhone('+447911123456'),
          equals('+447911123456'),
        );
      });
    });

    group('normalizeAuthPhone - User Formatting Normalization', () {
      test('normalizes spaces and hyphens in international numbers', () {
        expect(
          AuthPhoneHelper.normalizeAuthPhone('+966 50 123 4567'),
          equals('+966501234567'),
        );
        expect(
          AuthPhoneHelper.normalizeAuthPhone('+91 98765-43210'),
          equals('+919876543210'),
        );
        expect(
          AuthPhoneHelper.normalizeAuthPhone('+91 (987) 654-3210'),
          equals('+919876543210'),
        );
      });

      test('converts standard international prefix "00" to "+"', () {
        expect(
          AuthPhoneHelper.normalizeAuthPhone('00966501234567'),
          equals('+966501234567'),
        );
        expect(
          AuthPhoneHelper.normalizeAuthPhone('00919876543210'),
          equals('+919876543210'),
        );
        expect(
          AuthPhoneHelper.normalizeAuthPhone('00968 9123 4567'),
          equals('+96891234567'),
        );
      });

      test('normalizes E.164 digits entered without leading "+"', () {
        expect(
          AuthPhoneHelper.normalizeAuthPhone('966501234567'),
          equals('+966501234567'),
        );
        expect(
          AuthPhoneHelper.normalizeAuthPhone('919876543210'),
          equals('+919876543210'),
        );
      });
    });

    group('normalizeAuthPhone - Rejections & Safety', () {
      test('local number without country context is not silently assigned to any country', () {
        expect(AuthPhoneHelper.normalizeAuthPhone('0501234567'), isNull);
        expect(AuthPhoneHelper.normalizeAuthPhone('050 123 4567'), isNull);
        expect(AuthPhoneHelper.normalizeAuthPhone('0112345678'), isNull);
        expect(AuthPhoneHelper.normalizeAuthPhone('0222345678'), isNull);
      });

      test('rejects malformed numbers with letters or punctuation', () {
        expect(AuthPhoneHelper.normalizeAuthPhone('+96650abc123'), isNull);
        expect(AuthPhoneHelper.normalizeAuthPhone('not-a-phone'), isNull);
        expect(AuthPhoneHelper.normalizeAuthPhone('+91@9876543210'), isNull);
      });

      test('rejects country codes starting with 0', () {
        expect(AuthPhoneHelper.normalizeAuthPhone('+0123456789'), isNull);
        expect(AuthPhoneHelper.normalizeAuthPhone('000123456789'), isNull);
      });

      test('rejects underlength (< 8 digits) and overlength (> 15 digits) numbers', () {
        expect(AuthPhoneHelper.normalizeAuthPhone('+9665'), isNull);
        expect(AuthPhoneHelper.normalizeAuthPhone('12345'), isNull);
        expect(AuthPhoneHelper.normalizeAuthPhone('+9665012345678901234'), isNull);
      });

      test('rejects empty, whitespace, and null inputs', () {
        expect(AuthPhoneHelper.normalizeAuthPhone(''), isNull);
        expect(AuthPhoneHelper.normalizeAuthPhone('   '), isNull);
        expect(AuthPhoneHelper.normalizeAuthPhone(null), isNull);
      });
    });

    group('isValidAuthPhone', () {
      test('returns true for valid E.164 and false for invalid', () {
        expect(AuthPhoneHelper.isValidAuthPhone('+919876543210'), isTrue);
        expect(AuthPhoneHelper.isValidAuthPhone('+966501234567'), isTrue);
        expect(AuthPhoneHelper.isValidAuthPhone('0501234567'), isFalse);
        expect(AuthPhoneHelper.isValidAuthPhone('invalid'), isFalse);
      });
    });

    group('validateAuthPhone', () {
      test('returns custom or default required message on empty input', () {
        expect(
          AuthPhoneHelper.validateAuthPhone(null),
          equals('Please enter your phone number'),
        );
        expect(
          AuthPhoneHelper.validateAuthPhone(''),
          equals('Please enter your phone number'),
        );
        expect(
          AuthPhoneHelper.validateAuthPhone(
            '',
            requiredMessage: 'Please enter your registered staff phone number',
          ),
          equals('Please enter your registered staff phone number'),
        );
        expect(
          AuthPhoneHelper.validateAuthPhone(
            null,
            requiredMessage: 'Please enter your registered rider phone number',
          ),
          equals('Please enter your registered rider phone number'),
        );
      });

      test('returns error on invalid phone format', () {
        expect(
          AuthPhoneHelper.validateAuthPhone('0501234567'),
          equals('Please enter a valid phone number'),
        );
        expect(
          AuthPhoneHelper.validateAuthPhone('12345'),
          equals('Please enter a valid phone number'),
        );
        expect(
          AuthPhoneHelper.validateAuthPhone('invalid-phone'),
          equals('Please enter a valid phone number'),
        );
      });

      test('returns null on valid international phone number', () {
        expect(AuthPhoneHelper.validateAuthPhone('+919876543210'), isNull);
        expect(AuthPhoneHelper.validateAuthPhone('+966501234567'), isNull);
        expect(AuthPhoneHelper.validateAuthPhone('+968 9123 4567'), isNull);
      });
    });

    group('normalizeWithCountryContext', () {
      test('normalizes standard E.164 even without context', () {
        expect(
          AuthPhoneHelper.normalizeWithCountryContext('+919876543210'),
          equals('+919876543210'),
        );
      });

      test('applies Saudi conversion only when explicit Saudi context is provided', () {
        expect(
          AuthPhoneHelper.normalizeWithCountryContext(
            '0501234567',
            defaultCountryCode: '+966',
          ),
          equals('+966501234567'),
        );
        expect(
          AuthPhoneHelper.normalizeWithCountryContext(
            '0501234567',
            defaultCountryCode: null,
          ),
          isNull,
        );
      });
    });
  });
}
