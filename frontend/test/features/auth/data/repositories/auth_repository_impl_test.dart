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

    test('sendOtp calls POST /auth/otp/send and returns response message', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'channel': 'whatsapp',
        'message': 'Verification code sent via whatsapp',
      });

      final result = await authRepository.sendOtp(
        phone: '+966501234567',
        email: 'user@example.com',
        name: 'Ahmed',
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, equals('Verification code sent via whatsapp'));
      expect(mockTransport.lastUri?.path, equals('/api/auth/otp/send'));
      expect(mockTransport.lastMethod, equals(HttpMethod.post));
      expect(mockTransport.lastBody, contains('+966501234567'));
      expect(mockTransport.lastBody, contains('user@example.com'));
      expect(mockTransport.lastBody, contains('Ahmed'));
    });

    test('sendOtp maps 429 rate limit error to RateLimitFailure', () async {
      mockTransport.statusCode = 429;
      mockTransport.responseBody = jsonEncode({
        'code': 'OTP_RATE_LIMIT',
        'message': 'Too many OTP requests. Please wait before requesting another code.',
      });

      final result = await authRepository.sendOtp(phone: '+966501234567');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<RateLimitFailure>());
      expect(result.failureOrNull?.message, contains('Too many OTP requests'));
    });

    test('verifyOtp calls POST /auth/otp/verify, persists tokens, and sets currentUser', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'accessToken': 'jwt_access_token_123',
        'refreshToken': 'uuid_refresh_token_456',
        'user': {
          'id': 'user-customer-99',
          'phone': '+966501234567',
          'name': 'Customer Ali',
          'role': 'CUSTOMER',
          'isPhoneVerified': true,
          'isActive': true,
        },
        'isNew': false,
      });

      final result = await authRepository.verifyOtp(
        phone: '+966501234567',
        code: '123456',
      );

      expect(result.isSuccess, isTrue);
      final authResponse = result.dataOrNull!;
      expect(authResponse.token, equals('jwt_access_token_123'));
      expect(authResponse.refreshToken, equals('uuid_refresh_token_456'));
      expect(authResponse.user.id, equals('user-customer-99'));
      expect(authResponse.user.role, equals(UserRole.customer));
      expect(authRepository.currentUser?.id, equals('user-customer-99'));

      expect(mockTransport.lastUri?.path, equals('/api/auth/otp/verify'));
      expect(mockTransport.lastMethod, equals(HttpMethod.post));
      expect(mockTransport.lastBody, contains('+966501234567'));
      expect(mockTransport.lastBody, contains('123456'));

      // Check persistent secure storage
      final storedAuthToken = await mockStorage.read(key: StorageKeys.authToken);
      final storedRefreshToken = await mockStorage.read(key: StorageKeys.refreshToken);
      final storedUserId = await mockStorage.read(key: StorageKeys.userId);
      final storedUserRole = await mockStorage.read(key: StorageKeys.userRole);

      expect(storedAuthToken, equals('jwt_access_token_123'));
      expect(storedRefreshToken, equals('uuid_refresh_token_456'));
      expect(storedUserId, equals('user-customer-99'));
      expect(storedUserRole, equals('customer'));
    });

    test('verifyOtp maps 422 invalid OTP to ValidationFailure', () async {
      mockTransport.statusCode = 422;
      mockTransport.responseBody = jsonEncode({
        'code': 'OTP_INVALID',
        'message': 'Invalid code. 4 attempts remaining.',
      });

      final result = await authRepository.verifyOtp(
        phone: '+966501234567',
        code: '000000',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(result.failureOrNull?.message, contains('Invalid code. 4 attempts remaining.'));
    });

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

    test('login calls /auth/login, persists tokens, and sets currentUser', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'user': {
          ...sampleUserJson,
          'role': 'store_staff',
          'store_id': 'store-999',
        },
        'accessToken': 'jwt_login_token_456',
        'refreshToken': 'uuid_login_refresh_token',
      });

      final result = await authRepository.login(
        phoneNumber: '+966512345678',
        password: 'password123',
      );

      expect(result.isSuccess, isTrue);
      final authResponse = result.dataOrNull!;
      expect(authResponse.token, equals('jwt_login_token_456'));
      expect(authResponse.refreshToken, equals('uuid_login_refresh_token'));
      expect(authResponse.user.role, equals(UserRole.storeStaff));
      expect(authRepository.currentUser?.role, equals(UserRole.storeStaff));

      expect(mockTransport.lastUri?.path, equals('/api/auth/login'));
      expect(mockTransport.lastBody, contains('phone_number'));
      expect(mockTransport.lastBody, contains('password'));
      final storedToken = await mockStorage.read(key: StorageKeys.authToken);
      final storedRefreshToken = await mockStorage.read(key: StorageKeys.refreshToken);
      expect(storedToken, equals('jwt_login_token_456'));
      expect(storedRefreshToken, equals('uuid_login_refresh_token'));
    });

    test('refreshToken calls /auth/refresh and updates stored tokens', () async {
      await mockStorage.write(key: StorageKeys.refreshToken, value: 'old_refresh_token');

      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'accessToken': 'new_access_token_888',
        'refreshToken': 'new_refresh_token_999',
      });

      final result = await authRepository.refreshToken();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.token, equals('new_access_token_888'));
      expect(result.dataOrNull?.refreshToken, equals('new_refresh_token_999'));

      expect(mockTransport.lastUri?.path, equals('/api/auth/refresh'));
      expect(await mockStorage.read(key: StorageKeys.authToken), equals('new_access_token_888'));
      expect(await mockStorage.read(key: StorageKeys.refreshToken), equals('new_refresh_token_999'));
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

    test('logout notifies /auth/logout, deletes tokens and user keys from secure storage, and clears currentUser', () async {
      await mockStorage.write(key: StorageKeys.authToken, value: 'active_token_555');
      await mockStorage.write(key: StorageKeys.refreshToken, value: 'refresh_token_555');
      await mockStorage.write(key: StorageKeys.userId, value: 'user_555');
      await mockStorage.write(key: StorageKeys.userRole, value: 'customer');

      mockTransport.statusCode = 204;
      mockTransport.responseBody = '';

      await authRepository.logout();

      expect(mockTransport.lastUri?.path, equals('/api/auth/logout'));
      expect(mockTransport.lastBody, contains('refresh_token_555'));

      expect(await mockStorage.read(key: StorageKeys.authToken), isNull);
      expect(await mockStorage.read(key: StorageKeys.refreshToken), isNull);
      expect(await mockStorage.read(key: StorageKeys.userId), isNull);
      expect(await mockStorage.read(key: StorageKeys.userRole), isNull);
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

    group('updateProfile', () {
      test('calls PATCH /users/me with only supplied name and email', () async {
        await mockStorage.write(key: StorageKeys.authToken, value: 'test_token');
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'id': 'usr_123',
          'name': 'Updated Ahmed',
          'email': 'ahmed@example.com',
          'phone': '+966501234567',
          'role': 'CUSTOMER',
          'is_active': true,
        });

        final result = await authRepository.updateProfile(
          name: 'Updated Ahmed',
          email: 'ahmed@example.com',
        );

        expect(result.isSuccess, isTrue);
        expect(mockTransport.lastMethod, equals(HttpMethod.patch));
        expect(mockTransport.lastUri?.path, equals('/api/users/me'));

        final sentBody = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(sentBody['name'], equals('Updated Ahmed'));
        expect(sentBody['email'], equals('ahmed@example.com'));
        expect(sentBody.containsKey('phone'), isFalse);
        expect(sentBody.containsKey('phone_number'), isFalse);
        expect(sentBody.containsKey('role'), isFalse);
        expect(sentBody.containsKey('id'), isFalse);
        expect(sentBody.containsKey('isActive'), isFalse);
        expect(sentBody.containsKey('is_active'), isFalse);

        final user = result.dataOrNull!;
        expect(user.fullName, equals('Updated Ahmed'));
        expect(user.email, equals('ahmed@example.com'));
        expect(user.phoneNumber, equals('+966501234567'));
        expect(user.role, equals(UserRole.customer));
        expect(authRepository.currentUser, equals(user));
      });

      test('calls PATCH /users/me with only name when email is omitted', () async {
        await mockStorage.write(key: StorageKeys.authToken, value: 'test_token');
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'id': 'usr_123',
          'name': 'Only Name Update',
          'phone': '+966501234567',
          'role': 'CUSTOMER',
        });

        final result = await authRepository.updateProfile(name: 'Only Name Update');

        expect(result.isSuccess, isTrue);
        final sentBody = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(sentBody['name'], equals('Only Name Update'));
        expect(sentBody.containsKey('email'), isFalse);
        expect(sentBody.containsKey('phone'), isFalse);
      });

      test('returns ValidationFailure on 400 validation error', () async {
        await mockStorage.write(key: StorageKeys.authToken, value: 'test_token');
        mockTransport.statusCode = 400;
        mockTransport.responseBody = jsonEncode({
          'message': 'Name must be at least 2 characters',
        });

        final result = await authRepository.updateProfile(name: 'A');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<ValidationFailure>());
        expect(result.failureOrNull?.message, contains('Name must be at least 2 characters'));
      });

      test('returns UnauthorizedFailure on 401 unauthorized', () async {
        mockTransport.statusCode = 401;
        mockTransport.responseBody = jsonEncode({'message': 'Unauthorized'});

        final result = await authRepository.updateProfile(name: 'New Name');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<UnauthorizedFailure>());
      });

      test('returns ServerFailure on 500 server error', () async {
        mockTransport.statusCode = 500;
        mockTransport.responseBody = jsonEncode({'message': 'Internal server error'});

        final result = await authRepository.updateProfile(name: 'New Name');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<ServerFailure>());
      });
    });
  });
}
