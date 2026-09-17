import 'dart:convert';

import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/admin/data/repositories/admin_users_repository_impl.dart';
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

    test('getUsers parses paginated user list from GET /users', () async {
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
            'isPhoneVerified': true,
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
            'isPhoneVerified': true,
            'isActive': true,
          }
        ],
        'total': 2,
        'page': 1,
        'limit': 50,
      });

      final result = await usersRepository.getUsers(page: 1, limit: 50, role: 'STAFF');

      expect(result.isSuccess, isTrue);
      final page = result.dataOrNull!;
      expect(page.total, 2);
      expect(page.users.length, 2);
      expect(page.users[0].name, 'Ahmed Ali');
      expect(page.users[0].role, UserRole.customer);
      expect(page.users[1].name, 'Staff Riyadh');
      expect(page.users[1].role, UserRole.storeStaff);
      expect(page.users[1].storeId, 'store-1');

      expect(mockTransport.lastUri?.path, '/users');
      expect(mockTransport.lastUri?.queryParameters['role'], 'STAFF');
      expect(mockTransport.lastUri?.queryParameters['page'], '1');
    });

    test('getUsers handles network/API error gracefully', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({'error': 'Internal server error'});

      final result = await usersRepository.getUsers();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('Internal server error'));
    });
  });
}
