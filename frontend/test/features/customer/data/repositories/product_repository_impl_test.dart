import 'dart:convert';

import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/customer/data/repositories/product_repository_impl.dart';
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
  group('ProductRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late ProductRepositoryImpl productRepository;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com/api',
        transport: mockTransport,
      );
      productRepository = ProductRepositoryImpl(apiClient: apiClient);
    });

    test(
      'getProductsByStore calls GET /stores/:storeId/items and parses data response on 200',
      () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'data': [
            {
              'id': 'item-1',
              'storeId': 'store-100',
              'categoryId': 'cat-1',
              'name': 'Organic Eggs 12pk',
              'description': 'Farm fresh eggs',
              'price': 3.20,
              'imageUrl': 'https://example.com/eggs.jpg',
              'isAvailable': true,
              'sortOrder': 0,
              'category': {
                'id': 'cat-1',
                'storeId': 'store-100',
                'name': 'Dairy & Eggs',
                'sortOrder': 0,
              },
              'createdAt': '2026-09-07T19:06:18.000Z',
              'updatedAt': '2026-09-07T19:06:18.000Z',
            },
            {
              'id': 'item-2',
              'storeId': 'store-100',
              'categoryId': 'cat-2',
              'name': 'Brown Bread 500g',
              'description': null,
              'price': 1.00,
              'imageUrl': null,
              'isAvailable': true,
              'sortOrder': 1,
              'category': {
                'id': 'cat-2',
                'storeId': 'store-100',
                'name': 'Bakery',
                'sortOrder': 1,
              },
              'createdAt': '2026-09-07T19:06:18.000Z',
              'updatedAt': '2026-09-07T19:06:18.000Z',
            },
          ],
          'total': 2,
          'page': 1,
          'limit': 50,
        });

        final result = await productRepository.getProductsByStore(
          'store-100',
          categoryId: 'cat-1',
          search: 'egg',
          isAvailable: true,
          page: 1,
          limit: 20,
        );

        expect(result.isSuccess, isTrue);
        final products = result.dataOrNull!;
        expect(products.length, equals(2));
        expect(products[0].id, equals('item-1'));
        expect(products[0].storeId, equals('store-100'));
        expect(products[0].name, equals('Organic Eggs 12pk'));
        expect(products[0].price, equals(3.20));
        expect(products[0].category, equals('Dairy & Eggs'));
        expect(products[0].categoryId, equals('cat-1'));
        expect(products[1].name, equals('Brown Bread 500g'));
        expect(
          mockTransport.lastUri?.path,
          equals('/api/stores/store-100/items'),
        );
        expect(
          mockTransport.lastUri?.queryParameters['categoryId'],
          equals('cat-1'),
        );
        expect(mockTransport.lastUri?.queryParameters['search'], equals('egg'));
        expect(
          mockTransport.lastUri?.queryParameters['available'],
          equals('true'),
        );
        expect(mockTransport.lastUri?.queryParameters['page'], equals('1'));
        expect(mockTransport.lastUri?.queryParameters['limit'], equals('20'));
        expect(mockTransport.lastMethod, equals(HttpMethod.get));
      },
    );

    test(
      'getProductById calls GET /stores/:storeId/items/:id and returns item on 200',
      () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'id': 'item-123',
          'storeId': 'store-100',
          'categoryId': 'cat-1',
          'name': 'Labneh 500g',
          'description': 'Traditional strained yogurt',
          'price': 2.50,
          'imageUrl': 'https://example.com/labneh.jpg',
          'isAvailable': true,
          'sortOrder': 0,
          'category': {'id': 'cat-1', 'name': 'Dairy & Eggs'},
          'store': {'id': 'store-100', 'name': 'Esook Central'},
        });

        final result = await productRepository.getProductById(
          'item-123',
          storeId: 'store-100',
        );

        expect(result.isSuccess, isTrue);
        final product = result.dataOrNull!;
        expect(product.id, equals('item-123'));
        expect(product.name, equals('Labneh 500g'));
        expect(product.price, equals(2.50));
        expect(product.category, equals('Dairy & Eggs'));
        expect(
          mockTransport.lastUri?.path,
          equals('/api/stores/store-100/items/item-123'),
        );
      },
    );

    test(
      'getCategories calls GET /stores/:storeId/categories on 200',
      () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode([
          {
            'id': 'cat-1',
            'storeId': 'store-100',
            'name': 'Dairy & Eggs',
            '_count': {'items': 2},
          },
          {
            'id': 'cat-2',
            'storeId': 'store-100',
            'name': 'Bakery',
            '_count': {'items': 1},
          },
        ]);

        final result = await productRepository.getCategories('store-100');

        expect(result.isSuccess, isTrue);
        final categories = result.dataOrNull!;
        expect(categories.length, equals(2));
        expect(
          categories.map((c) => c.name).toSet(),
          equals({'Dairy & Eggs', 'Bakery'}),
        );
        expect(
          mockTransport.lastUri?.path,
          equals('/api/stores/store-100/categories'),
        );
        expect(mockTransport.lastMethod, equals(HttpMethod.get));
      },
    );

    test('getProductsByStore maps 404 to NotFoundFailure', () async {
      mockTransport.statusCode = 404;
      mockTransport.responseBody = jsonEncode({
        'error': {'code': 'NOT_FOUND', 'message': 'Store not found'},
      });

      final result = await productRepository.getProductsByStore(
        'inactive-store',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(result.failureOrNull?.message, equals('Store not found'));
    });

    test('getProductById maps 500 server error to ServerFailure', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({
        'error': {
          'code': 'INTERNAL_ERROR',
          'message': 'An unexpected error occurred',
        },
      });

      final result = await productRepository.getProductById(
        'item-123',
        storeId: 'store-100',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ServerFailure>());
    });

    test(
      'getProductById returns ValidationFailure without network call when storeId is null or empty',
      () async {
        mockTransport.lastUri = null;

        final resultNull = await productRepository.getProductById('item-123');
        expect(resultNull.isFailure, isTrue);
        expect(resultNull.failureOrNull, isA<ValidationFailure>());
        expect(
          resultNull.failureOrNull?.message,
          contains('storeId is required'),
        );
        expect(mockTransport.lastUri, isNull);

        final resultEmpty = await productRepository.getProductById(
          'item-123',
          storeId: '',
        );
        expect(resultEmpty.isFailure, isTrue);
        expect(resultEmpty.failureOrNull, isA<ValidationFailure>());
        expect(mockTransport.lastUri, isNull);
      },
    );
  });
}
