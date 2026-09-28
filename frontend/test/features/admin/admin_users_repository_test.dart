import 'dart:convert';

import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/admin/data/repositories/admin_users_repository_impl.dart';
import 'package:esouq/features/admin/domain/models/admin_user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

class MockHttpTransport implements HttpTransport {
  int statusCode = 200;
  String responseBody = '{"data": [], "total": 0, "page": 1, "limit": 50}';
  Map<String, String> responseHeaders = {};
  Uri? lastUri;
  HttpMethod? lastMethod;
  String? lastBody;

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
    lastBody = body;

    return HttpResponseData(
      statusCode: statusCode,
      body: responseBody,
      headers: responseHeaders,
    );
  }
}

void main() {
  group('AdminUsersRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late AdminUsersRepositoryImpl usersRepository;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: mockTransport,
      );
      usersRepository = AdminUsersRepositoryImpl(apiClient: apiClient);
    });

    test(
      'getUsers parses user list from GET /users with uppercase role mapping',
      () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'data': [
            {
              'id': 'u-1',
              'name': 'Ahmed Ali',
              'email': 'ahmed@example.com',
              'phone': '+966501234567',
              'role': 'CUSTOMER',
              'storeId': null,
              'isActive': true,
              'createdAt': '2026-09-01T10:00:00.000Z',
            },
            {
              'id': 'u-2',
              'name': 'Staff Riyadh',
              'email': 'staff@esook.store',
              'phone': '+966509876543',
              'role': 'STAFF',
              'storeId': 'store-1',
              'isActive': false,
            },
          ],
          'total': 2,
          'page': 1,
          'limit': 50,
        });

        final result = await usersRepository.getUsers(
          page: 1,
          limit: 50,
          role: 'STAFF',
        );

        expect(result.isSuccess, isTrue);
        final page = result.dataOrNull!;
        expect(page.total, 2);
        expect(page.users.length, 2);
        expect(page.users[0].name, 'Ahmed Ali');
        expect(page.users[0].role, UserRole.customer);
        expect(page.users[0].isActive, isTrue);
        expect(page.users[1].name, 'Staff Riyadh');
        expect(page.users[1].role, UserRole.storeStaff);
        expect(page.users[1].storeId, 'store-1');
        expect(page.users[1].isActive, isFalse);

        expect(mockTransport.lastUri?.path, '/users');
        expect(mockTransport.lastUri?.queryParameters['role'], 'STAFF');
        expect(mockTransport.lastUri?.queryParameters['page'], '1');
        expect(mockTransport.lastUri?.queryParameters['limit'], '50');
      },
    );

    test(
      'getUsers does not send role filter for DRIVER as /users role enum is constrained',
      () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({'data': [], 'total': 0});

        await usersRepository.getUsers(role: 'DRIVER');

        expect(mockTransport.lastUri?.path, '/users');
        expect(
          mockTransport.lastUri?.queryParameters.containsKey('role'),
          isFalse,
        );
      },
    );

    test('AdminUserModel.fromJson maps is_active false correctly', () {
      final user = AdminUserModel.fromJson({
        'id': 'u-99',
        'full_name': 'Inactive User',
        'phone_number': '+966509999999',
        'role': 'customer',
        'is_active': false,
      });

      expect(user.isActive, isFalse);
      expect(user.name, 'Inactive User');
      expect(user.phone, '+966509999999');
    });

    test('getUsers handles network/API error gracefully', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({
        'error': 'Internal server error',
      });

      final result = await usersRepository.getUsers();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('Internal server error'));
    });

    test('createStaffAccount sends POST /users/staff with verified storeId payload', () async {
      mockTransport.statusCode = 201;
      mockTransport.responseBody = jsonEncode({
        'id': 'u-new',
        'name': 'New Staff',
        'email': 'staff@esook.store',
        'phone': '+966501234567',
        'role': 'STAFF',
        'storeId': 'store-1',
        'isActive': true,
      });

      final result = await usersRepository.createStaffAccount(
        storeId: 'store-1',
        name: 'New Staff',
        email: 'staff@esook.store',
        phone: '+966501234567',
        role: 'STAFF',
        password: 'Password@123',
      );

      expect(result.isSuccess, isTrue);
      expect(mockTransport.lastMethod, HttpMethod.post);
      expect(mockTransport.lastUri?.path, '/users/staff');

      final sentBody = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
      expect(sentBody['storeId'], 'store-1');
      expect(sentBody['name'], 'New Staff');
      expect(sentBody['email'], 'staff@esook.store');
      expect(sentBody['phone'], '+966501234567');
      expect(sentBody['role'], 'STAFF');
      expect(sentBody['password'], 'Password@123');

      final staff = result.dataOrNull!;
      expect(staff.id, 'u-new');
      expect(staff.name, 'New Staff');
      expect(staff.storeId, 'store-1');
      expect(staff.role, UserRole.storeStaff);
    });

    test('createStaffAccount handles 409 duplicate account gracefully', () async {
      mockTransport.statusCode = 409;
      mockTransport.responseBody = jsonEncode({
        'message': 'A user with this email or phone already exists',
        'statusCode': 409,
      });

      final result = await usersRepository.createStaffAccount(
        storeId: 'store-1',
        name: 'Duplicate Staff',
        email: 'existing@esook.store',
        role: 'STAFF',
        password: 'Password@123',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ConflictFailure>());
      expect(
        result.failureOrNull?.message,
        contains('already exists'),
      );
    });

    test('updateStaffAccount sends PATCH /users/staff/:userId with only changed fields', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'id': 'u-edit-1',
        'name': 'Updated Staff Name',
        'email': 'staff@esook.store',
        'role': 'MANAGER',
        'storeId': 'store-1',
        'isActive': false,
      });

      final result = await usersRepository.updateStaffAccount(
        userId: 'u-edit-1',
        name: 'Updated Staff Name',
        role: 'MANAGER',
        isActive: false,
      );

      expect(result.isSuccess, isTrue);
      expect(mockTransport.lastMethod, HttpMethod.patch);
      expect(mockTransport.lastUri?.path, '/users/staff/u-edit-1');

      final sentBody = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
      expect(sentBody['name'], 'Updated Staff Name');
      expect(sentBody['role'], 'MANAGER');
      expect(sentBody['isActive'], isFalse);
      expect(sentBody.containsKey('email'), isFalse);
      expect(sentBody.containsKey('password'), isFalse);
      expect(sentBody.containsKey('phone'), isFalse);

      final updated = result.dataOrNull!;
      expect(updated.name, 'Updated Staff Name');
      expect(updated.role, UserRole.storeManager);
      expect(updated.isActive, isFalse);
    });

    test('deleteStaffAccount sends DELETE /users/staff/:userId', () async {
      mockTransport.statusCode = 204;
      mockTransport.responseBody = '';

      final result = await usersRepository.deleteStaffAccount('u-delete-1');

      expect(result.isSuccess, isTrue);
      expect(mockTransport.lastMethod, HttpMethod.delete);
      expect(mockTransport.lastUri?.path, '/users/staff/u-delete-1');
    });

    test('deleteStaffAccount returns failure on server error', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({
        'message': 'Failed to delete user account',
      });

      final result = await usersRepository.deleteStaffAccount('u-delete-1');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('Failed to delete user account'));
    });
  });
}
