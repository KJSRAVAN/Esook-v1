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
