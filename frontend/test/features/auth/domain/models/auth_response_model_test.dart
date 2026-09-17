import 'package:esouq/features/auth/domain/models/auth_response_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthResponseModel', () {
    test('parses backend auth response payload correctly', () {
      final json = {
        'user': {
          'id': 'user-123',
          'phone_number': '+966512345678',
          'full_name': 'Ahmed Al-Salem',
          'role': 'customer',
          'is_active': true,
        },
        'token': 'jwt_token_sample_abc',
      };

      final authResponse = AuthResponseModel.fromJson(json);

      expect(authResponse.token, equals('jwt_token_sample_abc'));
      expect(authResponse.user.id, equals('user-123'));
      expect(authResponse.user.role, equals(UserRole.customer));
    });

    test('parses NestJS origin/Prod_Backend auth response payload with accessToken and refreshToken', () {
      final json = {
        'user': {
          'id': 'user-456',
          'phone': '+966501234567',
          'name': 'Customer',
          'role': 'CUSTOMER',
          'isPhoneVerified': true,
          'isActive': true,
        },
        'accessToken': 'jwt_access_token_xyz',
        'refreshToken': 'uuid_refresh_token_xyz',
        'isNew': true,
      };

      final authResponse = AuthResponseModel.fromJson(json);

      expect(authResponse.token, equals('jwt_access_token_xyz'));
      expect(authResponse.refreshToken, equals('uuid_refresh_token_xyz'));
      expect(authResponse.isNew, isTrue);
      expect(authResponse.user.id, equals('user-456'));
      expect(authResponse.user.phoneNumber, equals('+966501234567'));
      expect(authResponse.user.role, equals(UserRole.customer));
    });

    test('serializes to JSON correctly', () {
      final json = {
        'user': {
          'id': 'user-123',
          'phone_number': '+966512345678',
          'full_name': 'Ahmed Al-Salem',
          'role': 'customer',
          'is_active': true,
        },
        'token': 'jwt_token_sample_abc',
      };

      final authResponse = AuthResponseModel.fromJson(json);
      final serialized = authResponse.toJson();

      expect(serialized['token'], equals('jwt_token_sample_abc'));
      expect((serialized['user'] as Map<String, dynamic>)['id'], equals('user-123'));
    });
  });
}
