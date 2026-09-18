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

    test('getStores parses store list from GET /stores with area, phone_number, is_active', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'stores': [
          {
            'id': 'store-1',
            'name': 'Fresh Mart Riyadh',
            'area': 'Riyadh-North',
            'address': 'King Fahd Road',
            'phone_number': '+966112345678',
            'is_active': true,
          }
        ]
      });

      final result = await storesRepository.getStores();

      expect(result.isSuccess, isTrue);
      final stores = result.dataOrNull!;
      expect(stores.length, 1);
      expect(stores.first.id, 'store-1');
      expect(stores.first.name, 'Fresh Mart Riyadh');
      expect(stores.first.area, 'Riyadh-North');
      expect(stores.first.phone, '+966112345678');
      expect(stores.first.isActive, isTrue);
      expect(mockTransport.lastUri?.path, '/stores');
    });

    test('getAreas makes no HTTP request to /stores/areas', () async {
      final result = await storesRepository.getAreas();

      expect(result.isSuccess, isTrue);
      expect(mockTransport.lastUri, isNull);
    });

    test('createStore sends POST /stores with area, phone_number, is_active', () async {
      mockTransport.statusCode = 201;
      mockTransport.responseBody = jsonEncode({
        'store': {
          'id': 'store-2',
          'name': 'Green Basket Jeddah',
          'area': 'Jeddah-Corniche',
          'address': 'Tahlia Street',
          'phone_number': '+966122345678',
          'is_active': true,
        }
      });

      final result = await storesRepository.createStore(
        name: 'Green Basket Jeddah',
        area: 'Jeddah-Corniche',
        address: 'Tahlia Street',
        phone: '+966122345678',
        isActive: true,
      );

      expect(result.isSuccess, isTrue);
      final store = result.dataOrNull!;
      expect(store.id, 'store-2');
      expect(store.name, 'Green Basket Jeddah');
      expect(store.area, 'Jeddah-Corniche');
      expect(mockTransport.lastUri?.path, '/stores');
      expect(mockTransport.lastMethod, HttpMethod.post);

      final sentBody = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
      expect(sentBody['area'], 'Jeddah-Corniche');
      expect(sentBody['phone_number'], '+966122345678');
      expect(sentBody['is_active'], isTrue);
      expect(sentBody.containsKey('areaId'), isFalse);
      expect(sentBody.containsKey('phone'), isFalse);
      expect(sentBody.containsKey('isActive'), isFalse);
    });

    test('updateStore sends PATCH /stores/:storeId with phone_number, is_active', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'store': {
          'id': 'store-2',
          'name': 'Green Basket Jeddah Updated',
          'area': 'Jeddah-Corniche',
          'phone_number': '+966129999999',
          'is_active': false,
        }
      });

      final result = await storesRepository.updateStore(
        storeId: 'store-2',
        name: 'Green Basket Jeddah Updated',
        phone: '+966129999999',
        isActive: false,
      );

      expect(result.isSuccess, isTrue);
      final store = result.dataOrNull!;
      expect(store.name, 'Green Basket Jeddah Updated');
      expect(store.isActive, isFalse);
      expect(mockTransport.lastUri?.path, '/stores/store-2');
      expect(mockTransport.lastMethod, HttpMethod.patch);

      final sentBody = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
      expect(sentBody['phone_number'], '+966129999999');
      expect(sentBody['is_active'], isFalse);
      expect(sentBody.containsKey('phone'), isFalse);
      expect(sentBody.containsKey('isActive'), isFalse);
    });
  });
}
