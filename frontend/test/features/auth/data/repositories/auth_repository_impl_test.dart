import 'dart:convert';

import 'package:esouq/core/constants/storage_keys.dart';
import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/core/storage/in_memory_secure_storage.dart';
import 'package:esouq/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

class MockHttpTransport implements HttpTransport {
  int statusCode = 200;
  String responseBody = '{}';
  Map<String, String> responseHeaders = {};
  Map<String, String>? lastHeaders;
  Uri? lastUri;
  String? lastBody;
  HttpMethod? lastMethod;

  @override
  Future<HttpResponseData> send({
    required Uri uri,
    required HttpMethod method,
    required Map<String, String> headers,
    String? body,
    Duration? timeout,
  }) async {
    lastUri = uri;
    lastMethod = method;
    lastHeaders = headers;
    lastBody = body;

    return HttpResponseData(
      statusCode: statusCode,
      body: responseBody,
      headers: responseHeaders,
    );
  }
}

void main() {
  group('AuthRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late InMemorySecureStorage mockStorage;
    late DefaultApiClient apiClient;
    late AuthRepositoryImpl authRepository;

    setUp(() {
      mockTransport = MockHttpTransport();
      mockStorage = InMemorySecureStorage();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com/api',
        transport: mockTransport,
        tokenProvider: () => mockStorage.read(key: StorageKeys.authToken),
      );
      authRepository = AuthRepositoryImpl(
        apiClient: apiClient,
        secureStorage: mockStorage,
      );
    });

    final sampleUserJson = {
      'id': 'user-123',
      'phone_number': '+966512345678',
      'email': 'ahmed@esouq.com',
      'full_name': 'Ahmed Al-Salem',
      'role': 'customer',
      'address': 'Riyadh',
      'is_active': true,
    };

    test('signupCustomer calls /auth/signup, persists token, and returns AuthResponse', () async {
      mockTransport.statusCode = 201;
      mockTransport.responseBody = jsonEncode({
        'user': sampleUserJson,
        'token': 'jwt_signup_token_123',
      });

      final result = await authRepository.signupCustomer(
        phoneNumber: '+966512345678',
        fullName: 'Ahmed Al-Salem',
        password: 'password123',
        address: 'Riyadh',
      );

      expect(result.isSuccess, isTrue);
      final authResponse = result.dataOrNull!;
      expect(authResponse.token, equals('jwt_signup_token_123'));
      expect(authResponse.user.fullName, equals('Ahmed Al-Salem'));

      expect(mockTransport.lastUri?.path, equals('/api/auth/signup'));
      expect(mockTransport.lastMethod, equals(HttpMethod.post));

      final storedToken = await mockStorage.read(key: StorageKeys.authToken);
      expect(storedToken, equals('jwt_signup_token_123'));
    });

    test('login calls /auth/login, persists token, and sets currentUser', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'user': {
          ...sampleUserJson,
          'role': 'store_staff',
          'store_id': 'store-999',
        },
        'token': 'jwt_login_token_456',
      });

      final result = await authRepository.login(
        phoneNumber: '+966512345678',
        password: 'password123',
      );

      expect(result.isSuccess, isTrue);
      final authResponse = result.dataOrNull!;
      expect(authResponse.token, equals('jwt_login_token_456'));
      expect(authResponse.user.role, equals(UserRole.storeStaff));
      expect(authRepository.currentUser?.role, equals(UserRole.storeStaff));

      expect(mockTransport.lastUri?.path, equals('/api/auth/login'));
      final storedToken = await mockStorage.read(key: StorageKeys.authToken);
      expect(storedToken, equals('jwt_login_token_456'));
    });

    test('requestAdminMagicLink calls /auth/admin/request-magic-link', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'message': 'If that email is registered as an admin, a login link has been sent.',
      });

      final result = await authRepository.requestAdminMagicLink(email: 'admin@esook.sa');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, contains('login link has been sent'));
      expect(mockTransport.lastUri?.path, equals('/api/auth/admin/request-magic-link'));
    });

    test('verifyAdminMagicLink calls /auth/admin/verify-magic-link and persists token', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'user': {
          ...sampleUserJson,
          'role': 'super_admin',
        },
        'token': 'jwt_admin_token_789',
      });

      final result = await authRepository.verifyAdminMagicLink(token: 'token_hex_123');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.user.role, equals(UserRole.superAdmin));
      expect(mockTransport.lastUri?.path, equals('/api/auth/admin/verify-magic-link'));

      final storedToken = await mockStorage.read(key: StorageKeys.authToken);
      expect(storedToken, equals('jwt_admin_token_789'));
    });

    test('getCurrentUser calls /auth/me with Authorization Bearer header', () async {
      await mockStorage.write(key: StorageKeys.authToken, value: 'active_token_555');

      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({'user': sampleUserJson});

      final result = await authRepository.getCurrentUser();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.fullName, equals('Ahmed Al-Salem'));
      expect(mockTransport.lastUri?.path, equals('/api/auth/me'));
      expect(mockTransport.lastHeaders?['Authorization'], equals('Bearer active_token_555'));
    });

    test('logout deletes token from secure storage and clears currentUser', () async {
      await mockStorage.write(key: StorageKeys.authToken, value: 'active_token_555');

      await authRepository.logout();

      final storedToken = await mockStorage.read(key: StorageKeys.authToken);
      expect(storedToken, isNull);
      expect(authRepository.currentUser, isNull);
    });

    test('checkSession returns null when no token in secure storage', () async {
      final result = await authRepository.checkSession();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
    });

    test('checkSession returns user when valid token exists', () async {
      await mockStorage.write(key: StorageKeys.authToken, value: 'valid_token');

      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({'user': sampleUserJson});

      final result = await authRepository.checkSession();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.id, equals('user-123'));
    });

    test('checkSession deletes token and returns null on 401 Unauthorized', () async {
      await mockStorage.write(key: StorageKeys.authToken, value: 'expired_token');

      mockTransport.statusCode = 401;
      mockTransport.responseBody = jsonEncode({'error': 'Unauthorized: Invalid or expired token'});

      final result = await authRepository.checkSession();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);

      final storedToken = await mockStorage.read(key: StorageKeys.authToken);
      expect(storedToken, isNull);
    });

    test('maps 400 validation error correctly', () async {
      mockTransport.statusCode = 400;
      mockTransport.responseBody = jsonEncode({
        'errors': ['phone_number is required', 'password must be at least 8 characters'],
      });

      final result = await authRepository.signupCustomer(
        phoneNumber: '',
        fullName: 'Test',
        password: '123',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('maps 409 conflict error correctly', () async {
      mockTransport.statusCode = 409;
      mockTransport.responseBody = jsonEncode({
        'error': 'An account with this phone number already exists',
      });

      final result = await authRepository.signupCustomer(
        phoneNumber: '+966512345678',
        fullName: 'Test',
        password: 'password123',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ConflictFailure>());
      expect(result.failureOrNull?.message, contains('already exists'));
    });

    test('maps 429 rate limit error correctly', () async {
      mockTransport.statusCode = 429;
      mockTransport.responseBody = jsonEncode({
        'error': 'Too many authentication attempts. Please try again later.',
      });

      final result = await authRepository.login(
        phoneNumber: '+966512345678',
        password: 'password123',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<RateLimitFailure>());
      expect(result.failureOrNull?.message, contains('Too many authentication attempts'));
    });
  });
}
