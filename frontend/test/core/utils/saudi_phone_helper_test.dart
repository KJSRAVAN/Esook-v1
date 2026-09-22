import 'package:esouq/core/utils/saudi_phone_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaudiPhoneHelper', () {
    group('normalizeSaudiPhone', () {
      test('normalizes canonical Saudi E.164 phone (+9665XXXXXXXX)', () {
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('+966501234567'),
          equals('+966501234567'),
        );
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('+966512345678'),
          equals('+966512345678'),
        );
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('+966598765432'),
          equals('+966598765432'),
        );
      });

      test('normalizes Saudi phone with spaces and punctuation', () {
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('+966 50 123 4567'),
          equals('+966501234567'),
        );
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('+966-50-123-4567'),
          equals('+966501234567'),
        );
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('(+966) 50 123 4567'),
          equals('+966501234567'),
        );
      });

      test('normalizes local 05XXXXXXXX format to +9665XXXXXXXX', () {
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('0501234567'),
          equals('+966501234567'),
        );
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('050 123 4567'),
          equals('+966501234567'),
        );
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('055-987-6543'),
          equals('+966559876543'),
        );
      });

      test('normalizes 9-digit 5XXXXXXXX format to +9665XXXXXXXX', () {
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('501234567'),
          equals('+966501234567'),
        );
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('59 123 4567'),
          equals('+966591234567'),
        );
      });

      test('normalizes 9665XXXXXXXX (without +) to +9665XXXXXXXX', () {
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('966501234567'),
          equals('+966501234567'),
        );
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('966 50 123 4567'),
          equals('+966501234567'),
        );
      });

      test('normalizes 009665XXXXXXXX international prefix to +9665XXXXXXXX', () {
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('00966501234567'),
          equals('+966501234567'),
        );
        expect(
          SaudiPhoneHelper.normalizeSaudiPhone('00966 50 123 4567'),
          equals('+966501234567'),
        );
      });

      test('rejects overlength phone numbers', () {
        expect(SaudiPhoneHelper.normalizeSaudiPhone('05012345678'), isNull);
        expect(SaudiPhoneHelper.normalizeSaudiPhone('+9665012345678'), isNull);
        expect(SaudiPhoneHelper.normalizeSaudiPhone('9665012345678'), isNull);
      });

      test('rejects underlength phone numbers', () {
        expect(SaudiPhoneHelper.normalizeSaudiPhone('0501234'), isNull);
        expect(SaudiPhoneHelper.normalizeSaudiPhone('+96650123'), isNull);
        expect(SaudiPhoneHelper.normalizeSaudiPhone('12345'), isNull);
      });

      test('rejects non-Saudi phone numbers (India, Oman, etc.)', () {
        expect(SaudiPhoneHelper.normalizeSaudiPhone('+919876543210'), isNull);
        expect(SaudiPhoneHelper.normalizeSaudiPhone('+96891234567'), isNull);
        expect(SaudiPhoneHelper.normalizeSaudiPhone('00919876543210'), isNull);
      });

      test('rejects invalid non-mobile numbers or non-numeric strings', () {
        expect(SaudiPhoneHelper.normalizeSaudiPhone('+966112345678'), isNull); // Landline
        expect(SaudiPhoneHelper.normalizeSaudiPhone('+96650abc123'), isNull);
        expect(SaudiPhoneHelper.normalizeSaudiPhone(''), isNull);
        expect(SaudiPhoneHelper.normalizeSaudiPhone('    '), isNull);
        expect(SaudiPhoneHelper.normalizeSaudiPhone(null), isNull);
      });
    });

    group('validateSaudiPhone', () {
      test('returns required message for empty/null', () {
        expect(
          SaudiPhoneHelper.validateSaudiPhone(null),
          equals('Please enter your registered staff phone number'),
        );
        expect(
          SaudiPhoneHelper.validateSaudiPhone(''),
          equals('Please enter your registered staff phone number'),
        );
        expect(
          SaudiPhoneHelper.validateSaudiPhone('   '),
          equals('Please enter your registered staff phone number'),
        );
      });

      test('returns null (valid) for valid formats', () {
        expect(SaudiPhoneHelper.validateSaudiPhone('+966501234567'), isNull);
        expect(SaudiPhoneHelper.validateSaudiPhone('050 123 4567'), isNull);
        expect(SaudiPhoneHelper.validateSaudiPhone('501234567'), isNull);
      });

      test('returns invalid format message for invalid input', () {
        expect(
          SaudiPhoneHelper.validateSaudiPhone('05012345678'),
          equals('Please enter a valid Saudi mobile number (+966 5X XXX XXXX)'),
        );
        expect(
          SaudiPhoneHelper.validateSaudiPhone('+96891234567'),
          equals('Please enter a valid Saudi mobile number (+966 5X XXX XXXX)'),
        );
      });
    });

    group('normalizeStorePhone', () {
      test('accepts and normalizes valid Saudi mobile', () {
        expect(
          SaudiPhoneHelper.normalizeStorePhone('+966512345678'),
          equals('+966512345678'),
        );
        expect(
          SaudiPhoneHelper.normalizeStorePhone('0512345678'),
          equals('+966512345678'),
        );
        expect(
          SaudiPhoneHelper.normalizeStorePhone('05 1234 5678'),
          equals('+966512345678'),
        );
      });

      test('accepts and normalizes valid Saudi landlines (Riyadh 011, Jeddah 012)', () {
        expect(
          SaudiPhoneHelper.normalizeStorePhone('+966112345678'),
          equals('+966112345678'),
        );
        expect(
          SaudiPhoneHelper.normalizeStorePhone('0112345678'),
          equals('+966112345678'),
        );
        expect(
          SaudiPhoneHelper.normalizeStorePhone('0126543210'),
          equals('+966126543210'),
        );
        expect(
          SaudiPhoneHelper.normalizeStorePhone('+966 12 654 3210'),
          equals('+966126543210'),
        );
      });

      test('removes formatting characters (spaces, dashes, parentheses, dots)', () {
        expect(
          SaudiPhoneHelper.normalizeStorePhone('+966 (11) 234-5678'),
          equals('+966112345678'),
        );
        expect(
          SaudiPhoneHelper.normalizeStorePhone('011.234.5678'),
          equals('+966112345678'),
        );
        expect(
          SaudiPhoneHelper.normalizeStorePhone(' 00966 11 234 5678 '),
          equals('+966112345678'),
        );
      });

      test('does not silently truncate values exceeding 20 characters', () {
        const longInput = '+966112345678901234567890';
        final normalized = SaudiPhoneHelper.normalizeStorePhone(longInput);
        // It should preserve the string length so validation can explicitly reject it
        expect(normalized, equals(longInput));
        expect(normalized!.length, greaterThan(20));
      });
    });

    group('validateStorePhone', () {
      test('returns null (valid) for empty or null since store phone is optional', () {
        expect(SaudiPhoneHelper.validateStorePhone(null), isNull);
        expect(SaudiPhoneHelper.validateStorePhone(''), isNull);
        expect(SaudiPhoneHelper.validateStorePhone('   '), isNull);
      });

      test('accepts valid Saudi mobile and landline numbers', () {
        expect(SaudiPhoneHelper.validateStorePhone('+966512345678'), isNull);
        expect(SaudiPhoneHelper.validateStorePhone('0512345678'), isNull);
        expect(SaudiPhoneHelper.validateStorePhone('+966112345678'), isNull);
        expect(SaudiPhoneHelper.validateStorePhone('011 234 5678'), isNull);
        expect(SaudiPhoneHelper.validateStorePhone('012 654 3210'), isNull);
      });

      test('rejects values that exceed 20 transmitted characters without silent truncation', () {
        // 21-character normalized string
        const over20 = '+96611234567890123456';
        expect(
          SaudiPhoneHelper.validateStorePhone(over20),
          equals('Phone number cannot exceed 20 characters'),
        );

        // Input with formatting that normalizes to >20 chars
        const over20Formatted = '+966 (11) 234-5678-901-234-56';
        expect(
          SaudiPhoneHelper.validateStorePhone(over20Formatted),
          equals('Phone number cannot exceed 20 characters'),
        );
      });

      test('rejects non-numeric characters and invalid strings', () {
        expect(
          SaudiPhoneHelper.validateStorePhone('011234abcd'),
          equals('Please enter a valid contact phone number'),
        );
        expect(
          SaudiPhoneHelper.validateStorePhone('phone#123'),
          equals('Please enter a valid contact phone number'),
        );
      });

      test('rejects underlength phone numbers (< 8 characters)', () {
        expect(
          SaudiPhoneHelper.validateStorePhone('12345'),
          equals('Please enter a valid phone number'),
        );
      });
    });
  });
}
