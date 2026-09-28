import 'dart:convert';

import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/admin/data/repositories/admin_drivers_repository_impl.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

class MockHttpTransport implements HttpTransport {
  int statusCode = 200;
  String responseBody = '{}';
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
      headers: {},
    );
  }
}

void main() {
  group('AdminDriversRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late AdminDriversRepositoryImpl driversRepository;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: mockTransport,
      );
      driversRepository = AdminDriversRepositoryImpl(apiClient: apiClient);
    });

    test(
      'registerDriver sends POST /auth/register/driver and returns created driver',
      () async {
        mockTransport.statusCode = 201;
        mockTransport.responseBody = jsonEncode({
          'id': 'd-101',
          'name': 'Mohammed Al-Rashid',
          'phone': '+966501234567',
          'role': 'DRIVER',
          'isActive': true,
        });

        final result = await driversRepository.registerDriver(
          name: 'Mohammed Al-Rashid',
          phone: '+966501234567',
          password: 'Password@123',
        );

        expect(result.isSuccess, isTrue);
        final driver = result.dataOrNull!;
        expect(driver.id, 'd-101');
        expect(driver.name, 'Mohammed Al-Rashid');
        expect(driver.role, UserRole.deliveryRider);
        expect(mockTransport.lastUri?.path, '/auth/register/driver');
        expect(mockTransport.lastMethod, HttpMethod.post);

        final sentBody = jsonDecode(mockTransport.lastBody!);
        expect(sentBody['name'], 'Mohammed Al-Rashid');
        expect(sentBody['phone'], '+966501234567');
        expect(sentBody['password'], 'Password@123');
        expect(sentBody.containsKey('role'), isFalse);
      },
    );

    test(
      'getDrivers queries /users without role filter and returns filtered driver list',
      () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'data': [
            {
              'id': 'd-1',
              'name': 'Driver One',
              'phone': '+966501111111',
              'role': 'DRIVER',
              'isActive': true,
            },
            {
              'id': 'c-1',
              'name': 'Customer One',
              'phone': '+966502222222',
              'role': 'CUSTOMER',
              'isActive': true,
            },
          ],
          'total': 2,
        });

        final result = await driversRepository.getDrivers();

        expect(result.isSuccess, isTrue);
        final drivers = result.dataOrNull!;
        expect(drivers.length, 1);
        expect(drivers.first.name, 'Driver One');
        expect(drivers.first.role, UserRole.deliveryRider);
        expect(mockTransport.lastUri?.path, '/users');
        expect(
          mockTransport.lastUri?.queryParameters.containsKey('role'),
          isFalse,
        );
      },
    );

    test(
      'updateDriverStatus sends PATCH /users/:id and returns updated driver',
      () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'id': 'd-1',
          'name': 'Driver One',
          'phone': '+966501111111',
          'role': 'DRIVER',
          'isActive': false,
        });

        final result = await driversRepository.updateDriverStatus(
          driverId: 'd-1',
          isActive: false,
        );

        expect(result.isSuccess, isTrue);
        final driver = result.dataOrNull!;
        expect(driver.id, 'd-1');
        expect(driver.isActive, isFalse);
        expect(mockTransport.lastUri?.path, '/users/d-1');
        expect(mockTransport.lastMethod, HttpMethod.patch);

        final sentBody = jsonDecode(mockTransport.lastBody!);
        expect(sentBody['isActive'], isFalse);
        expect(sentBody['is_active'], isFalse);
      },
    );

    test(
      'deleteDriver sends DELETE /users/drivers/:id and returns success',
      () async {
        mockTransport.statusCode = 204;
        mockTransport.responseBody = '';

        final result = await driversRepository.deleteDriver('d-1');

        expect(result.isSuccess, isTrue);
        expect(mockTransport.lastUri?.path, '/users/drivers/d-1');
        expect(mockTransport.lastMethod, HttpMethod.delete);
      },
    );

    test(
      'deleteDriver returns failure on server error',
      () async {
        mockTransport.statusCode = 404;
        mockTransport.responseBody = jsonEncode({
          'error': 'Driver not found',
        });

        final result = await driversRepository.deleteDriver('d-unknown');

        expect(result.isFailure, isTrue);
      },
    );
  });
}
