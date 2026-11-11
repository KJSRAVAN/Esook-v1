import 'dart:convert';

import 'package:esouq/core/constants/storage_keys.dart';
import 'package:esouq/core/error/exceptions.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/core/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class MockSecureStorage implements SecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({required String key}) async => data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    data.clear();
  }

  @override
  Future<bool> containsKey({required String key}) async => data.containsKey(key);
}

class MockHttpTransport implements HttpTransport {
  int statusCode = 200;
  String responseBody = '{}';
  Map<String, String> responseHeaders = {};
  Map<String, String>? lastHeaders;
  Uri? lastUri;
  String? lastBody;
  HttpMethod? lastMethod;
  Future<HttpResponseData> Function(
    Uri uri,
    HttpMethod method,
    Map<String, String> headers,
    String? body,
  )? customHandler;

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

    if (customHandler != null) {
      return customHandler!(uri, method, headers, body);
    }

    return HttpResponseData(
      statusCode: statusCode,
      body: responseBody,
      headers: responseHeaders,
    );
  }
}

void main() {
  group('DefaultApiClient', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com/api/v1',
        transport: mockTransport,
        tokenProvider: () async => 'test_token_123',
      );
    });

    test(
      'injects Authorization Bearer token and JSON headers automatically',
      () async {
        mockTransport.responseBody = jsonEncode({'success': true});

        final response = await apiClient.get<Map<String, dynamic>>('/test');

        expect(response.statusCode, equals(200));
        expect(
          mockTransport.lastHeaders?['Authorization'],
          equals('Bearer test_token_123'),
        );
        expect(
          mockTransport.lastHeaders?['Content-Type'],
          equals('application/json'),
        );
        expect(
          mockTransport.lastHeaders?['Accept'],
          equals('application/json'),
        );
      },
    );

    test('handles query parameters properly', () async {
      mockTransport.responseBody = jsonEncode({'items': []});

      await apiClient.get<Map<String, dynamic>>(
        '/products',
        queryParameters: {'category': 'tech', 'limit': 10},
      );

      expect(
        mockTransport.lastUri?.queryParameters['category'],
        equals('tech'),
      );
      expect(mockTransport.lastUri?.queryParameters['limit'], equals('10'));
    });

    test('serializes POST body to JSON', () async {
      mockTransport.statusCode = 201;
      mockTransport.responseBody = jsonEncode({'id': 'item_1'});

      final response = await apiClient.post<Map<String, dynamic>>(
        '/orders',
        body: {'amount': 150},
      );

      expect(response.statusCode, equals(201));
      expect(mockTransport.lastMethod, equals(HttpMethod.post));
      expect(mockTransport.lastBody, equals(jsonEncode({'amount': 150})));
    });

    test('serializes PATCH body to JSON and handles request', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'id': 'item_1',
        'status': 'updated',
      });

      final response = await apiClient.patch<Map<String, dynamic>>(
        '/orders/item_1',
        body: {'status': 'updated'},
      );

      expect(response.statusCode, equals(200));
      expect(mockTransport.lastMethod, equals(HttpMethod.patch));
      expect(mockTransport.lastBody, equals(jsonEncode({'status': 'updated'})));
    });

    test('dispatches DELETE request properly', () async {
      mockTransport.statusCode = 204;
      mockTransport.responseBody = '';

      final response = await apiClient.delete<dynamic>('/orders/item_1');

      expect(response.statusCode, equals(204));
      expect(mockTransport.lastMethod, equals(HttpMethod.delete));
    });

    test('parses response using custom fromJson transformer', () async {
      mockTransport.responseBody = jsonEncode({'name': 'eSOuQ Store'});

      final response = await apiClient.get<String>(
        '/store/profile',
        fromJson: (json) => (json as Map<String, dynamic>)['name'] as String,
      );

      expect(response.data, equals('eSOuQ Store'));
    });

    test('throws UnauthorizedException on 401 response', () async {
      mockTransport.statusCode = 401;
      mockTransport.responseBody = jsonEncode({
        'message': 'Invalid credentials',
      });

      expect(
        () => apiClient.get<dynamic>('/protected'),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            contains('Invalid credentials'),
          ),
        ),
      );
    });

    test(
      'throws ValidationException on 400 response with error details',
      () async {
        mockTransport.statusCode = 400;
        mockTransport.responseBody = jsonEncode({
          'message': 'Validation failed',
          'errors': {'email': 'Invalid email format'},
        });

        expect(
          () => apiClient.post<dynamic>('/register', body: {}),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.validationErrors?['email'],
              'email error',
              equals('Invalid email format'),
            ),
          ),
        );
      },
    );

    test('throws NotFoundException on 404 response', () async {
      mockTransport.statusCode = 404;
      mockTransport.responseBody = jsonEncode({
        'message': 'Resource not found',
      });

      expect(
        () => apiClient.get<dynamic>('/not-found'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('throws ServerException on 500 response', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({
        'message': 'Internal database error',
      });

      expect(
        () => apiClient.get<dynamic>('/error'),
        throwsA(isA<ServerException>()),
      );
    });

    test(
      '401 response triggers refresh and original request is retried once with new token',
      () async {
        final mockStorage = MockSecureStorage();
        mockStorage.data[StorageKeys.authToken] = 'old_access_token';
        mockStorage.data[StorageKeys.refreshToken] = 'valid_refresh_token';

        var ordersCallCount = 0;
        var refreshCallCount = 0;

        mockTransport.customHandler = (uri, method, headers, body) async {
          if (uri.path.endsWith('/auth/refresh')) {
            refreshCallCount++;
            return HttpResponseData(
              statusCode: 200,
              body: jsonEncode({
                'accessToken': 'new_refreshed_access_token',
                'refreshToken': 'new_rotated_refresh_token',
              }),
              headers: {'content-type': 'application/json'},
            );
          }

          if (uri.path.endsWith('/orders')) {
            ordersCallCount++;
            if (headers['Authorization'] == 'Bearer old_access_token') {
              return HttpResponseData(
                statusCode: 401,
                body: jsonEncode({'message': 'Access token expired'}),
                headers: {'content-type': 'application/json'},
              );
            }
            if (headers['Authorization'] ==
                'Bearer new_refreshed_access_token') {
              return HttpResponseData(
                statusCode: 200,
                body: jsonEncode({'success': true, 'orders': []}),
                headers: {'content-type': 'application/json'},
              );
            }
          }

          return HttpResponseData(statusCode: 404, body: '{}', headers: {});
        };

        final refreshingClient = DefaultApiClient(
          baseUrl: 'https://api.esouq.com',
          transport: mockTransport,
          secureStorage: mockStorage,
        );

        final response =
            await refreshingClient.get<Map<String, dynamic>>('/orders');

        expect(response.statusCode, equals(200));
        expect(response.data['success'], isTrue);
        expect(refreshCallCount, equals(1));
        expect(ordersCallCount, equals(2));
        expect(
          mockStorage.data[StorageKeys.authToken],
          equals('new_refreshed_access_token'),
        );
        expect(
          mockStorage.data[StorageKeys.refreshToken],
          equals('new_rotated_refresh_token'),
        );
      },
    );

    test('concurrent 401 requests share a single in-flight refresh call',
        () async {
      final mockStorage = MockSecureStorage();
      mockStorage.data[StorageKeys.authToken] = 'expired_token';
      mockStorage.data[StorageKeys.refreshToken] = 'valid_refresh';

      var refreshCallCount = 0;

      mockTransport.customHandler = (uri, method, headers, body) async {
        if (uri.path.endsWith('/auth/refresh')) {
          refreshCallCount++;
          // Simulate slight network latency
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return HttpResponseData(
            statusCode: 200,
            body: jsonEncode({
              'accessToken': 'concurrent_refreshed_token',
              'refreshToken': 'concurrent_rotated_refresh',
            }),
            headers: {'content-type': 'application/json'},
          );
        }

        if (uri.path.contains('/data/')) {
          if (headers['Authorization'] == 'Bearer expired_token') {
            return HttpResponseData(
              statusCode: 401,
              body: jsonEncode({'message': 'Expired'}),
              headers: {'content-type': 'application/json'},
            );
          }
          if (headers['Authorization'] ==
              'Bearer concurrent_refreshed_token') {
            return HttpResponseData(
              statusCode: 200,
              body: jsonEncode({'path': uri.path}),
              headers: {'content-type': 'application/json'},
            );
          }
        }

        return HttpResponseData(statusCode: 404, body: '{}', headers: {});
      };

      final refreshingClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: mockTransport,
        secureStorage: mockStorage,
      );

      // Launch 3 requests simultaneously
      final results = await Future.wait([
        refreshingClient.get<Map<String, dynamic>>('/data/1'),
        refreshingClient.get<Map<String, dynamic>>('/data/2'),
        refreshingClient.get<Map<String, dynamic>>('/data/3'),
      ]);

      expect(results.length, equals(3));
      for (final res in results) {
        expect(res.statusCode, equals(200));
      }
      // Exactly 1 refresh call was made for all 3 concurrent requests
      expect(refreshCallCount, equals(1));
    });

    test(
      'refresh failure does not loop, clears session, and throws UnauthorizedException',
      () async {
        final mockStorage = MockSecureStorage();
        mockStorage.data[StorageKeys.authToken] = 'bad_token';
        mockStorage.data[StorageKeys.refreshToken] = 'expired_refresh_token';

        var refreshCallCount = 0;
        var ordersCallCount = 0;
        var sessionExpiredCalled = false;

        mockTransport.customHandler = (uri, method, headers, body) async {
          if (uri.path.endsWith('/auth/refresh')) {
            refreshCallCount++;
            return HttpResponseData(
              statusCode: 401,
              body: jsonEncode({'message': 'Refresh token expired'}),
              headers: {'content-type': 'application/json'},
            );
          }

          if (uri.path.endsWith('/profile')) {
            ordersCallCount++;
            return HttpResponseData(
              statusCode: 401,
              body: jsonEncode({'message': 'Unauthorized'}),
              headers: {'content-type': 'application/json'},
            );
          }

          return HttpResponseData(statusCode: 404, body: '{}', headers: {});
        };

        final refreshingClient = DefaultApiClient(
          baseUrl: 'https://api.esouq.com',
          transport: mockTransport,
          secureStorage: mockStorage,
          onSessionExpired: () async {
            sessionExpiredCalled = true;
          },
        );

        expect(
          () => refreshingClient.get<dynamic>('/profile'),
          throwsA(isA<UnauthorizedException>()),
        );

        // Allow async refresh handling to settle
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Exactly 1 initial request and 1 failed refresh attempt
        expect(ordersCallCount, equals(1));
        expect(refreshCallCount, equals(1));
        expect(sessionExpiredCalled, isTrue);
        // Secure storage credentials cleared
        expect(mockStorage.data.containsKey(StorageKeys.authToken), isFalse);
        expect(mockStorage.data.containsKey(StorageKeys.refreshToken), isFalse);
      },
    );
  });
}
