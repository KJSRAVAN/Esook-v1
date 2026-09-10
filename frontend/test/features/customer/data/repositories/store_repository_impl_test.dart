import 'dart:convert';

import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/customer/data/repositories/store_repository_impl.dart';
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
  group('StoreRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late StoreRepositoryImpl storeRepository;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com/api',
        transport: mockTransport,
      );
      storeRepository = StoreRepositoryImpl(apiClient: apiClient);
    });

    test('getStores returns parsed list of StoreModel on 200', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'stores': [
          {
            'id': 's-1',
            'name': 'Store 1',
            'area': 'Area 1',
            'is_active': true,
          },
          {
            'id': 's-2',
            'name': 'Store 2',
            'area': 'Area 2',
            'is_active': true,
          },
        ]
      });

      final result = await storeRepository.getStores();

      expect(result.isSuccess, isTrue);
      final stores = result.dataOrNull!;
      expect(stores.length, equals(2));
      expect(stores[0].name, equals('Store 1'));
      expect(stores[1].area, equals('Area 2'));
      expect(mockTransport.lastUri?.path, equals('/api/stores'));
      expect(mockTransport.lastMethod, equals(HttpMethod.get));
    });

    test('getStoreById returns store on 200', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'store': {
          'id': 's-123',
          'name': 'Olaya Store',
          'area': 'Olaya',
          'is_active': true,
        }
      });

      final result = await storeRepository.getStoreById('s-123');

      expect(result.isSuccess, isTrue);
      final store = result.dataOrNull!;
      expect(store.id, equals('s-123'));
      expect(store.name, equals('Olaya Store'));
      expect(mockTransport.lastUri?.path, equals('/api/stores/s-123'));
    });

    test('getStoreByArea returns store on 200', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'store': {
          'id': 's-456',
          'name': 'Seeb Store',
          'area': 'Seeb',
          'is_active': true,
        }
      });

      final result = await storeRepository.getStoreByArea('Seeb');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.name, equals('Seeb Store'));
      expect(mockTransport.lastUri?.path, equals('/api/stores/area/Seeb'));
    });

    test('getStoreById maps 404 to NotFoundFailure', () async {
      mockTransport.statusCode = 404;
      mockTransport.responseBody = jsonEncode({
        'error': 'Store not found or unavailable',
      });

      final result = await storeRepository.getStoreById('nonexistent');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(result.failureOrNull?.message, equals('Store not found or unavailable'));
    });

    test('getStores maps 500 server error to ServerFailure', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({
        'error': 'Internal server error',
      });

      final result = await storeRepository.getStores();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ServerFailure>());
    });
  });
}
