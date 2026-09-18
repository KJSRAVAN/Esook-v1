import 'dart:convert';

import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/store/data/repositories/store_products_repository_impl.dart';
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
  group('StoreProductsRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late StoreProductsRepositoryImpl productsRepository;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: mockTransport,
      );
      productsRepository = StoreProductsRepositoryImpl(apiClient: apiClient);
    });

    test('getStoreProducts queries GET /products/store/:storeId', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'products': [
          {
            'id': 'prod-1',
            'store_id': 'store-1',
            'name': 'Fresh Apples 1kg',
            'price': '8.50',
            'category': 'Fresh Fruits',
            'is_available': true,
          }
        ]
      });

      final result = await productsRepository.getStoreProducts('store-1');

      expect(result.isSuccess, isTrue);
      final products = result.dataOrNull!;
      expect(products.length, 1);
      expect(products.first.name, 'Fresh Apples 1kg');
      expect(products.first.price, 8.50);
      expect(products.first.isAvailable, isTrue);
      expect(mockTransport.lastUri?.path, '/products/store/store-1');
      expect(mockTransport.lastMethod, HttpMethod.get);
    });

    test('createProduct sends POST /products with backend body', () async {
      mockTransport.statusCode = 201;
      mockTransport.responseBody = jsonEncode({
        'product': {
          'id': 'prod-2',
          'store_id': 'store-1',
          'name': 'Organic Bananas 1kg',
          'price': '6.00',
          'category': 'Fresh Fruits',
          'is_available': true,
        }
      });

      final result = await productsRepository.createProduct(
        storeId: 'store-1',
        name: 'Organic Bananas 1kg',
        price: 6.00,
        category: 'Fresh Fruits',
      );

      expect(result.isSuccess, isTrue);
      final product = result.dataOrNull!;
      expect(product.id, 'prod-2');
      expect(product.name, 'Organic Bananas 1kg');
      expect(mockTransport.lastUri?.path, '/products');
      expect(mockTransport.lastMethod, HttpMethod.post);
      expect(mockTransport.lastBody, contains('"store_id":"store-1"'));
      expect(mockTransport.lastBody, contains('"name":"Organic Bananas 1kg"'));
      expect(mockTransport.lastBody, contains('"category":"Fresh Fruits"'));
      expect(mockTransport.lastBody, isNot(contains('category_id')));
      expect(mockTransport.lastBody, isNot(contains('sort_order')));
    });

    test('updateProduct sends PATCH /products/:id with backend body', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'product': {
          'id': 'prod-2',
          'store_id': 'store-1',
          'name': 'Organic Bananas 1kg (Sale)',
          'price': '5.50',
          'is_available': true,
        }
      });

      final result = await productsRepository.updateProduct(
        storeId: 'store-1',
        productId: 'prod-2',
        name: 'Organic Bananas 1kg (Sale)',
        price: 5.50,
      );

      expect(result.isSuccess, isTrue);
      final product = result.dataOrNull!;
      expect(product.price, 5.50);
      expect(mockTransport.lastUri?.path, '/products/prod-2');
      expect(mockTransport.lastMethod, HttpMethod.patch);
      expect(mockTransport.lastBody, isNot(contains('category_id')));
      expect(mockTransport.lastBody, isNot(contains('sort_order')));
    });

    test('toggleAvailability updates is_available via PATCH /products/:id', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'product': {
          'id': 'prod-2',
          'store_id': 'store-1',
          'name': 'Organic Bananas 1kg',
          'price': '6.00',
          'is_available': false,
        }
      });

      final result = await productsRepository.toggleAvailability(
        storeId: 'store-1',
        productId: 'prod-2',
        isAvailable: false,
      );

      expect(result.isSuccess, isTrue);
      final product = result.dataOrNull!;
      expect(product.isAvailable, isFalse);
      expect(mockTransport.lastUri?.path, '/products/prod-2');
      expect(mockTransport.lastBody, contains('"is_available":false'));
    });

    test('deleteProduct sends DELETE /products/:id', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({'message': 'Product deleted successfully'});

      final result = await productsRepository.deleteProduct(
        storeId: 'store-1',
        productId: 'prod-2',
      );

      expect(result.isSuccess, isTrue);
      expect(mockTransport.lastUri?.path, '/products/prod-2');
      expect(mockTransport.lastMethod, HttpMethod.delete);
    });
  });
}
