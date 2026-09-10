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

    test('getProductsByStore returns parsed list of ProductModel on 200', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'products': [
          {
            'id': 'p-1',
            'store_id': 's-100',
            'name': 'Organic Eggs',
            'price': '3.20',
            'category': 'Dairy',
            'is_available': true,
            'loyalty_points_per_unit': 5,
          },
          {
            'id': 'p-2',
            'store_id': 's-100',
            'name': 'Brown Bread',
            'price': '1.00',
            'category': 'Bakery',
            'is_available': true,
            'loyalty_points_per_unit': 0,
          },
        ]
      });

      final result = await productRepository.getProductsByStore('s-100');

      expect(result.isSuccess, isTrue);
      final products = result.dataOrNull!;
      expect(products.length, equals(2));
      expect(products[0].name, equals('Organic Eggs'));
      expect(products[0].price, equals(3.20));
      expect(products[1].name, equals('Brown Bread'));
      expect(mockTransport.lastUri?.path, equals('/api/products/store/s-100'));
      expect(mockTransport.lastMethod, equals(HttpMethod.get));
    });

    test('getProductById returns product on 200', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'product': {
          'id': 'p-123',
          'store_id': 's-100',
          'name': 'Labneh 500g',
          'price': '2.50',
          'is_available': true,
          'loyalty_points_per_unit': 3,
        }
      });

      final result = await productRepository.getProductById('p-123');

      expect(result.isSuccess, isTrue);
      final product = result.dataOrNull!;
      expect(product.id, equals('p-123'));
      expect(product.name, equals('Labneh 500g'));
      expect(product.price, equals(2.50));
      expect(mockTransport.lastUri?.path, equals('/api/products/p-123'));
    });

    test('getProductsByStore maps 404 to NotFoundFailure', () async {
      mockTransport.statusCode = 404;
      mockTransport.responseBody = jsonEncode({
        'error': 'Store not found or unavailable',
      });

      final result = await productRepository.getProductsByStore('inactive-store');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(result.failureOrNull?.message, equals('Store not found or unavailable'));
    });

    test('getProductById maps 500 server error to ServerFailure', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({
        'error': 'Internal server error',
      });

      final result = await productRepository.getProductById('p-123');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ServerFailure>());
    });
  });
}
