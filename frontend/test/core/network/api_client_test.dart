import 'dart:convert';

import 'package:esouq/core/error/exceptions.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
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

    test('injects Authorization Bearer token and JSON headers automatically', () async {
      mockTransport.responseBody = jsonEncode({'success': true});

      final response = await apiClient.get<Map<String, dynamic>>('/test');

      expect(response.statusCode, equals(200));
      expect(mockTransport.lastHeaders?['Authorization'], equals('Bearer test_token_123'));
      expect(mockTransport.lastHeaders?['Content-Type'], equals('application/json'));
      expect(mockTransport.lastHeaders?['Accept'], equals('application/json'));
    });

    test('handles query parameters properly', () async {
      mockTransport.responseBody = jsonEncode({'items': []});

      await apiClient.get<Map<String, dynamic>>(
        '/products',
        queryParameters: {'category': 'tech', 'limit': 10},
      );

      expect(mockTransport.lastUri?.queryParameters['category'], equals('tech'));
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
      mockTransport.responseBody = jsonEncode({'id': 'item_1', 'status': 'updated'});

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
      mockTransport.responseBody = jsonEncode({'message': 'Invalid credentials'});

      expect(
        () => apiClient.get<dynamic>('/protected'),
        throwsA(isA<UnauthorizedException>().having(
          (e) => e.message,
          'message',
          contains('Invalid credentials'),
        )),
      );
    });

    test('throws ValidationException on 400 response with error details', () async {
      mockTransport.statusCode = 400;
      mockTransport.responseBody = jsonEncode({
        'message': 'Validation failed',
        'errors': {'email': 'Invalid email format'},
      });

      expect(
        () => apiClient.post<dynamic>('/register', body: {}),
        throwsA(isA<ValidationException>().having(
          (e) => e.validationErrors?['email'],
          'email error',
          equals('Invalid email format'),
        )),
      );
    });

    test('throws NotFoundException on 404 response', () async {
      mockTransport.statusCode = 404;
      mockTransport.responseBody = jsonEncode({'message': 'Resource not found'});

      expect(
        () => apiClient.get<dynamic>('/not-found'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('throws ServerException on 500 response', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({'message': 'Internal database error'});

      expect(
        () => apiClient.get<dynamic>('/error'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
