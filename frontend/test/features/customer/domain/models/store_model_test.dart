import 'package:esouq/features/customer/domain/models/store_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoreModel', () {
    test('parses full JSON response correctly', () {
      final json = {
        'id': 's-123',
        'name': 'eSOuQ Olaya',
        'area': 'Riyadh - Olaya',
        'address': 'King Fahd Road',
        'phone_number': '+966112345678',
        'is_active': true,
        'created_at': '2026-09-10T12:00:00.000Z',
        'updated_at': '2026-09-10T13:00:00.000Z',
      };

      final store = StoreModel.fromJson(json);

      expect(store.id, equals('s-123'));
      expect(store.name, equals('eSOuQ Olaya'));
      expect(store.area, equals('Riyadh - Olaya'));
      expect(store.address, equals('King Fahd Road'));
      expect(store.phoneNumber, equals('+966112345678'));
      expect(store.isActive, isTrue);
      expect(store.createdAt, isNotNull);
      expect(store.updatedAt, isNotNull);
    });

    test('handles nullable fields gracefully', () {
      final json = {
        'id': 's-456',
        'name': 'eSOuQ Minimal',
        'area': 'Muscat - Bowsher',
        'address': null,
        'phone_number': null,
        'is_active': false,
        'created_at': null,
        'updated_at': null,
      };

      final store = StoreModel.fromJson(json);

      expect(store.id, equals('s-456'));
      expect(store.name, equals('eSOuQ Minimal'));
      expect(store.area, equals('Muscat - Bowsher'));
      expect(store.address, isNull);
      expect(store.phoneNumber, isNull);
      expect(store.isActive, isFalse);
      expect(store.createdAt, isNull);
    });

    test('serializes to JSON correctly', () {
      const store = StoreModel(
        id: 's-789',
        name: 'eSOuQ Express',
        area: 'Seeb',
        address: 'Main St',
        phoneNumber: '+96891234567',
        isActive: true,
      );

      final json = store.toJson();

      expect(json['id'], equals('s-789'));
      expect(json['name'], equals('eSOuQ Express'));
      expect(json['area'], equals('Seeb'));
      expect(json['address'], equals('Main St'));
      expect(json['phone_number'], equals('+96891234567'));
      expect(json['is_active'], isTrue);
    });
  });
}
