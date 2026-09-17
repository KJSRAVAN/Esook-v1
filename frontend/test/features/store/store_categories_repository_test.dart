import 'dart:convert';

import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/store/data/repositories/store_categories_repository_impl.dart';
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
  group('StoreCategoriesRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late StoreCategoriesRepositoryImpl categoriesRepository;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: mockTransport,
      );
      categoriesRepository = StoreCategoriesRepositoryImpl(apiClient: apiClient);
    });

    test('getCategories queries GET /stores/:storeId/categories', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'categories': [
          {
            'id': 'cat-1',
            'store_id': 'store-1',
            'name': 'Dairy & Eggs',
            'sort_order': 1,
            'product_count': 12,
          },
          {
            'id': 'cat-2',
            'store_id': 'store-1',
            'name': 'Fresh Bakery',
            'sort_order': 2,
            'product_count': 8,
          },
        ]
      });

      final result = await categoriesRepository.getCategories('store-1');

      expect(result.isSuccess, isTrue);
      final categories = result.dataOrNull!;
      expect(categories.length, 2);
      expect(categories[0].name, 'Dairy & Eggs');
      expect(categories[0].productCount, 12);
      expect(categories[1].name, 'Fresh Bakery');
      expect(mockTransport.lastUri?.path, '/stores/store-1/categories');
    });

    test('createCategory sends POST /stores/:storeId/categories', () async {
      mockTransport.statusCode = 201;
      mockTransport.responseBody = jsonEncode({
        'category': {
          'id': 'cat-3',
          'store_id': 'store-1',
          'name': 'Beverages',
          'sort_order': 3,
        }
      });

      final result = await categoriesRepository.createCategory(
        storeId: 'store-1',
        name: 'Beverages',
        sortOrder: 3,
      );

      expect(result.isSuccess, isTrue);
      final category = result.dataOrNull!;
      expect(category.id, 'cat-3');
      expect(category.name, 'Beverages');
      expect(mockTransport.lastUri?.path, '/stores/store-1/categories');
      expect(mockTransport.lastMethod, HttpMethod.post);
      expect(mockTransport.lastBody, contains('Beverages'));
    });
  });
}
