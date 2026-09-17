import 'dart:convert';

import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/admin/data/repositories/admin_stores_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class MockHttpTransport implements HttpTransport {
  int statusCode = 200;
  String responseBody = '[]';
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
  group('AdminStoresRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late AdminStoresRepositoryImpl storesRepository;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: mockTransport,
      );
      storesRepository = AdminStoresRepositoryImpl(apiClient: apiClient);
    });

    test('getStores parses store list from GET /stores', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode([
        {
          'id': 'store-1',
          'name': 'Fresh Mart Riyadh',
          'areaId': 'area-1',
          'area': {'id': 'area-1', 'name': 'Riyadh'},
          'address': 'King Fahd Road',
          'phone': '+966112345678',
          'isActive': true,
        }
      ]);

      final result = await storesRepository.getStores();

      expect(result.isSuccess, isTrue);
      final stores = result.dataOrNull!;
      expect(stores.length, 1);
      expect(stores.first.id, 'store-1');
      expect(stores.first.name, 'Fresh Mart Riyadh');
      expect(stores.first.areaName, 'Riyadh');
      expect(mockTransport.lastUri?.path, '/stores');
    });

    test('getAreas parses delivery areas from GET /stores/areas', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode([
        {'id': 'area-1', 'name': 'Riyadh'},
        {'id': 'area-2', 'name': 'Jeddah'}
      ]);

      final result = await storesRepository.getAreas();

      expect(result.isSuccess, isTrue);
      final areas = result.dataOrNull!;
      expect(areas.length, 2);
      expect(areas[0].name, 'Riyadh');
      expect(areas[1].name, 'Jeddah');
      expect(mockTransport.lastUri?.path, '/stores/areas');
    });

    test('createStore sends POST /stores and returns new store', () async {
      mockTransport.statusCode = 201;
      mockTransport.responseBody = jsonEncode({
        'id': 'store-2',
        'name': 'Green Basket Jeddah',
        'areaId': 'area-2',
        'address': 'Tahlia Street',
        'phone': '+966122345678',
        'isActive': true,
      });

      final result = await storesRepository.createStore(
        name: 'Green Basket Jeddah',
        areaId: 'area-2',
        address: 'Tahlia Street',
        phone: '+966122345678',
      );

      expect(result.isSuccess, isTrue);
      final store = result.dataOrNull!;
      expect(store.id, 'store-2');
      expect(store.name, 'Green Basket Jeddah');
      expect(mockTransport.lastUri?.path, '/stores');
      expect(mockTransport.lastMethod, HttpMethod.post);
    });

    test('updateStore sends PATCH /stores/:storeId and returns updated store', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'id': 'store-2',
        'name': 'Green Basket Jeddah Updated',
        'areaId': 'area-2',
        'isActive': false,
      });

      final result = await storesRepository.updateStore(
        storeId: 'store-2',
        name: 'Green Basket Jeddah Updated',
        isActive: false,
      );

      expect(result.isSuccess, isTrue);
      final store = result.dataOrNull!;
      expect(store.name, 'Green Basket Jeddah Updated');
      expect(store.isActive, isFalse);
      expect(mockTransport.lastUri?.path, '/stores/store-2');
      expect(mockTransport.lastMethod, HttpMethod.patch);
    });
  });
}
