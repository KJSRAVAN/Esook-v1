import 'dart:convert';

import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/customer/data/repositories/store_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class MockHttpTransport implements HttpTransport {
  int statusCode = 200;
  String responseBody = '[]';
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

    test('getStores returns parsed list of StoreModel from backend top-level array', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode([
        {
          'id': 's-1',
          'name': 'Esook Riyadh Central',
          'areaId': 'area-1',
          'address': 'King Fahd Road, Riyadh',
          'phone': '+966112345678',
          'isActive': true,
          'area': {
            'id': 'area-1',
            'name': 'Riyadh',
            'createdAt': '2026-09-07T19:06:18.000Z',
          },
          '_count': {
            'items': 10,
          },
          'createdAt': '2026-09-07T19:06:18.000Z',
          'updatedAt': '2026-09-07T19:06:18.000Z',
        },
        {
          'id': 's-2',
          'name': 'Esook Jeddah North',
          'areaId': 'area-2',
          'address': 'Corniche Road',
          'phone': '+966122345678',
          'isActive': true,
          'area': {
            'id': 'area-2',
            'name': 'Jeddah',
            'createdAt': '2026-09-07T19:06:18.000Z',
          },
          '_count': {
            'items': 25,
          },
          'createdAt': '2026-09-07T19:06:18.000Z',
          'updatedAt': '2026-09-07T19:06:18.000Z',
        },
      ]);

      final result = await storeRepository.getStores();

      expect(result.isSuccess, isTrue);
      final stores = result.dataOrNull!;
      expect(stores.length, equals(2));
      expect(stores[0].id, equals('s-1'));
      expect(stores[0].name, equals('Esook Riyadh Central'));
      expect(stores[0].area, equals('Riyadh'));
      expect(stores[0].areaId, equals('area-1'));
      expect(stores[0].phoneNumber, equals('+966112345678'));
      expect(stores[0].itemCount, equals(10));
      expect(stores[1].name, equals('Esook Jeddah North'));
      expect(stores[1].area, equals('Jeddah'));
      expect(stores[1].itemCount, equals(25));
      expect(mockTransport.lastUri?.path, equals('/api/stores'));
      expect(mockTransport.lastMethod, equals(HttpMethod.get));
    });

    test('getAreas returns parsed list of AreaModel from GET /stores/areas on 200', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode([
        {
          'id': 'area-1',
          'name': 'Riyadh - Olaya',
          'createdAt': '2026-09-07T19:06:18.000Z',
        },
        {
          'id': 'area-2',
          'name': 'Riyadh - Al Malqa',
          'createdAt': '2026-09-07T19:06:18.000Z',
        },
      ]);

      final result = await storeRepository.getAreas();

      expect(result.isSuccess, isTrue);
      final areas = result.dataOrNull!;
      expect(areas.length, equals(2));
      expect(areas[0].id, equals('area-1'));
      expect(areas[0].name, equals('Riyadh - Olaya'));
      expect(areas[1].id, equals('area-2'));
      expect(areas[1].name, equals('Riyadh - Al Malqa'));
      expect(mockTransport.lastUri?.path, equals('/api/stores/areas'));
      expect(mockTransport.lastMethod, equals(HttpMethod.get));
    });

    test('getStoreById returns store from backend object response on 200', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'id': 's-123',
        'name': 'Esook Riyadh Central',
        'areaId': 'area-1',
        'address': 'King Fahd Road',
        'phone': '+966112345678',
        'isActive': true,
        'area': {
          'id': 'area-1',
          'name': 'Riyadh',
          'createdAt': '2026-09-07T19:06:18.000Z',
        },
        'createdAt': '2026-09-07T19:06:18.000Z',
        'updatedAt': '2026-09-07T19:06:18.000Z',
      });

      final result = await storeRepository.getStoreById('s-123');

      expect(result.isSuccess, isTrue);
      final store = result.dataOrNull!;
      expect(store.id, equals('s-123'));
      expect(store.name, equals('Esook Riyadh Central'));
      expect(store.area, equals('Riyadh'));
      expect(store.areaId, equals('area-1'));
      expect(store.phoneNumber, equals('+966112345678'));
      expect(mockTransport.lastUri?.path, equals('/api/stores/s-123'));
      expect(mockTransport.lastMethod, equals(HttpMethod.get));
    });

    test('getStoreById maps 404 to NotFoundFailure', () async {
      mockTransport.statusCode = 404;
      mockTransport.responseBody = jsonEncode({
        'error': {
          'code': 'NOT_FOUND',
          'message': 'Store not found',
        },
      });

      final result = await storeRepository.getStoreById('nonexistent');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(result.failureOrNull?.message, equals('Store not found'));
    });

    test('getStores maps 500 server error to ServerFailure', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({
        'error': {
          'code': 'INTERNAL_ERROR',
          'message': 'An unexpected error occurred',
        },
      });

      final result = await storeRepository.getStores();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ServerFailure>());
    });

    test('getAreas maps 500 server error to ServerFailure', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({
        'error': {
          'code': 'INTERNAL_ERROR',
          'message': 'An unexpected error occurred',
        },
      });

      final result = await storeRepository.getAreas();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ServerFailure>());
    });
  });
}
