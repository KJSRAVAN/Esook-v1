import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRole', () {
    test('parses all valid backend roles', () {
      expect(UserRole.fromString('customer'), equals(UserRole.customer));
      expect(UserRole.fromString('store_staff'), equals(UserRole.storeStaff));
      expect(
        UserRole.fromString('store_manager'),
        equals(UserRole.storeManager),
      );
      expect(
        UserRole.fromString('delivery_rider'),
        equals(UserRole.deliveryRider),
      );
      expect(UserRole.fromString('driver'), equals(UserRole.deliveryRider));
      expect(UserRole.fromString('DRIVER'), equals(UserRole.deliveryRider));
      expect(UserRole.fromString('super_admin'), equals(UserRole.superAdmin));
      expect(UserRole.fromString('CUSTOMER'), equals(UserRole.customer));
    });

    test('handles unknown and null role gracefully without throwing', () {
      expect(UserRole.fromString('unknown_role'), equals(UserRole.unknown));
      expect(UserRole.fromString(null), equals(UserRole.unknown));
      expect(UserRole.fromString(''), equals(UserRole.unknown));
    });

    test('role helper getters return correct flags', () {
      expect(UserRole.customer.isCustomer, isTrue);
      expect(UserRole.storeStaff.isStoreStaff, isTrue);
      expect(UserRole.storeManager.isStoreStaff, isTrue);
      expect(UserRole.storeManager.isStoreManager, isTrue);
      expect(UserRole.deliveryRider.isDeliveryRider, isTrue);
      expect(UserRole.superAdmin.isSuperAdmin, isTrue);
    });
  });

  group('UserModel', () {
    test('parses complete backend user JSON correctly', () {
      final json = {
        'id': 'user-123',
        'phone_number': '+966512345678',
        'email': 'user@example.com',
        'full_name': 'Ahmed Al-Salem',
        'role': 'customer',
        'store_id': 'store-456',
        'address': 'Riyadh, Olaya',
        'is_active': true,
        'created_at': '2026-09-10T00:00:00.000Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, equals('user-123'));
      expect(user.phoneNumber, equals('+966512345678'));
      expect(user.email, equals('user@example.com'));
      expect(user.fullName, equals('Ahmed Al-Salem'));
      expect(user.role, equals(UserRole.customer));
      expect(user.storeId, equals('store-456'));
      expect(user.address, equals('Riyadh, Olaya'));
      expect(user.isActive, isTrue);
      expect(user.createdAt, isNotNull);
    });

    test('parses origin/Prod_Backend camelCase user JSON correctly', () {
      final json = {
        'id': 'user-789',
        'phone': '+966501234567',
        'email': null,
        'name': 'Customer Ali',
        'role': 'CUSTOMER',
        'storeId': 'store-101',
        'isPhoneVerified': true,
        'isActive': true,
        'createdAt': '2026-09-15T12:00:00.000Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, equals('user-789'));
      expect(user.phoneNumber, equals('+966501234567'));
      expect(user.email, isNull);
      expect(user.fullName, equals('Customer Ali'));
      expect(user.role, equals(UserRole.customer));
      expect(user.storeId, equals('store-101'));
      expect(user.isActive, isTrue);
      expect(user.createdAt, isNotNull);
    });

    test('handles nullable fields gracefully', () {
      final json = {
        'id': 'user-123',
        'phone_number': '+966512345678',
        'full_name': 'Ahmed Al-Salem',
        'role': 'store_staff',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, equals('user-123'));
      expect(user.phoneNumber, equals('+966512345678'));
      expect(user.email, isNull);
      expect(user.storeId, isNull);
      expect(user.address, isNull);
      expect(user.createdAt, isNull);
      expect(user.isActive, isTrue);
    });

    test('serializes to JSON correctly', () {
      const user = UserModel(
        id: 'user-123',
        phoneNumber: '+966512345678',
        fullName: 'Ahmed Al-Salem',
        role: UserRole.deliveryRider,
        isActive: true,
      );

      final json = user.toJson();

      expect(json['id'], equals('user-123'));
      expect(json['phone_number'], equals('+966512345678'));
      expect(json['full_name'], equals('Ahmed Al-Salem'));
      expect(json['role'], equals('delivery_rider'));
      expect(json['is_active'], isTrue);
    });
  });
}
