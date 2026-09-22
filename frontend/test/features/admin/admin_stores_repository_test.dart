import 'dart:convert';

import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/admin/data/repositories/admin_stores_repository_impl.dart';
import 'package:esouq/features/admin/domain/models/store_delivery_area.dart';
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

    test(
      'getStores parses store list from GET /stores with area, phone_number, is_active',
      () async {
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
            },
          ],
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
      },
    );

    test('getAreas calls GET /stores/areas and parses area list', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode([
        {'id': 'area-1', 'name': 'Riyadh-North'},
        {'id': 'area-2', 'name': 'Jeddah-Corniche'},
      ]);

      final result = await storesRepository.getAreas();

      expect(result.isSuccess, isTrue);
      final areas = result.dataOrNull!;
      expect(areas.length, 2);
      expect(areas[0].id, 'area-1');
      expect(areas[0].name, 'Riyadh-North');
      expect(mockTransport.lastUri?.path, '/stores/areas');
    });

    test('createStore sends POST /stores with areaId and phone', () async {
      mockTransport.statusCode = 201;
      mockTransport.responseBody = jsonEncode({
        'store': {
          'id': 'store-2',
          'name': 'Green Basket Jeddah',
          'areaId': 'area-2',
          'address': 'Tahlia Street',
          'phone': '+966122345678',
          'isActive': true,
        },
      });

      final result = await storesRepository.createStore(
        name: 'Green Basket Jeddah',
        area: 'area-2',
        address: 'Tahlia Street',
        phone: '+966122345678',
        isActive: true,
      );

      expect(result.isSuccess, isTrue);
      final store = result.dataOrNull!;
      expect(store.id, 'store-2');
      expect(store.name, 'Green Basket Jeddah');
      expect(mockTransport.lastUri?.path, '/stores');
      expect(mockTransport.lastMethod, HttpMethod.post);

      final sentBody =
          jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
      expect(sentBody['name'], 'Green Basket Jeddah');
      expect(sentBody['areaId'], 'area-2');
      expect(sentBody['address'], 'Tahlia Street');
      expect(sentBody['phone'], '+966122345678');
      expect(sentBody.containsKey('phone_number'), isFalse);
    });

    test(
      'createStore sends exact Riyadh CUID when Riyadh area or areaId is given',
      () async {
        mockTransport.statusCode = 201;
        mockTransport.responseBody = jsonEncode({
          'store': {
            'id': 'store-riyadh',
            'name': 'Riyadh Store',
            'areaId': StoreDeliveryArea.riyadhId,
          },
        });

        // Test passing Riyadh CUID directly
        await storesRepository.createStore(
          name: 'Riyadh Store',
          areaId: StoreDeliveryArea.riyadhId,
        );
        var sentBody =
            jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(sentBody['areaId'], 'cmu5u0i810000vy8ilejcv1rz');

        // Test resolving raw 'Riyadh' name to CUID
        await storesRepository.createStore(
          name: 'Riyadh Store 2',
          area: 'Riyadh',
        );
        sentBody = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(sentBody['areaId'], 'cmu5u0i810000vy8ilejcv1rz');
        expect(sentBody['areaId'], isNot('Riyadh'));
      },
    );

    test(
      'createStore sends exact Jeddah CUID when Jeddah area or areaId is given',
      () async {
        mockTransport.statusCode = 201;
        mockTransport.responseBody = jsonEncode({
          'store': {
            'id': 'store-jeddah',
            'name': 'Jeddah Store',
            'areaId': StoreDeliveryArea.jeddahId,
          },
        });

        // Test passing Jeddah CUID directly
        await storesRepository.createStore(
          name: 'Jeddah Store',
          areaId: StoreDeliveryArea.jeddahId,
        );
        var sentBody =
            jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(sentBody['areaId'], 'cmu5u0ink0001vy8i7hu36wkg');

        // Test resolving raw 'Jeddah' name to CUID
        await storesRepository.createStore(
          name: 'Jeddah Store 2',
          area: 'Jeddah',
        );
        sentBody = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(sentBody['areaId'], 'cmu5u0ink0001vy8i7hu36wkg');
        expect(sentBody['areaId'], isNot('Jeddah'));
      },
    );

    test(
      'updateStore sends PATCH /stores/:storeId with areaId, phone, isActive',
      () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'store': {
            'id': 'store-2',
            'name': 'Green Basket Jeddah Updated',
            'areaId': 'area-2',
            'phone': '+966129999999',
            'isActive': false,
          },
        });

        final result = await storesRepository.updateStore(
          storeId: 'store-2',
          name: 'Green Basket Jeddah Updated',
          area: 'area-2',
          phone: '+966129999999',
          isActive: false,
        );

        expect(result.isSuccess, isTrue);
        final store = result.dataOrNull!;
        expect(store.name, 'Green Basket Jeddah Updated');
        expect(store.isActive, isFalse);
        expect(mockTransport.lastUri?.path, '/stores/store-2');
        expect(mockTransport.lastMethod, HttpMethod.patch);

        final sentBody =
            jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(sentBody['name'], 'Green Basket Jeddah Updated');
        expect(sentBody['areaId'], 'area-2');
        expect(sentBody['phone'], '+966129999999');
        expect(sentBody['isActive'], isFalse);
        expect(sentBody.containsKey('phone_number'), isFalse);
        expect(sentBody.containsKey('is_active'), isFalse);
      },
    );

    test(
      'updateStore converts area name to CUID and preserves areaId',
      () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'store': {
            'id': 'store-3',
            'name': 'Store 3',
            'areaId': StoreDeliveryArea.riyadhId,
          },
        });

        // Updating area to Riyadh
        await storesRepository.updateStore(
          storeId: 'store-3',
          area: 'Riyadh',
        );
        var sentBody =
            jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(sentBody['areaId'], 'cmu5u0i810000vy8ilejcv1rz');

        // Updating areaId to Jeddah CUID
        await storesRepository.updateStore(
          storeId: 'store-3',
          areaId: StoreDeliveryArea.jeddahId,
        );
        sentBody = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(sentBody['areaId'], 'cmu5u0ink0001vy8i7hu36wkg');
      },
    );
  });
}
