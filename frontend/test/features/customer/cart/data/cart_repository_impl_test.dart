import 'dart:convert';

import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/customer/cart/data/cart_repository_impl.dart';
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
  group('CartRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late CartRepositoryImpl cartRepository;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com/api',
        transport: mockTransport,
      );
      cartRepository = CartRepositoryImpl(apiClient: apiClient);
    });

    test('getCart sends GET /cart and parses backend Cart response on 200', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'userId': 'usr-1',
        'storeId': 'store-100',
        'items': [
          {
            'itemId': 'item-1',
            'name': 'Fresh Milk 1L',
            'price': 1.50,
            'quantity': 2,
            'imageUrl': 'https://example.com/milk.jpg',
          },
        ],
        'subtotal': 3.00,
        'updatedAt': '2026-09-10T12:00:00.000Z',
      });

      final result = await cartRepository.getCart();

      expect(result.isSuccess, isTrue);
      final cart = result.dataOrNull!;
      expect(cart.userId, equals('usr-1'));
      expect(cart.storeId, equals('store-100'));
      expect(cart.items.length, equals(1));
      expect(cart.items.first.itemId, equals('item-1'));
      expect(cart.items.first.name, equals('Fresh Milk 1L'));
      expect(cart.items.first.price, equals(1.50));
      expect(cart.items.first.quantity, equals(2));
      expect(cart.subtotal, equals(3.00));
      expect(mockTransport.lastUri?.path, equals('/api/cart'));
      expect(mockTransport.lastMethod, equals(HttpMethod.get));
    });

    test('addItem sends POST /cart/items with itemId and quantity payload', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'userId': 'usr-1',
        'storeId': 'store-100',
        'items': [
          {
            'itemId': 'item-1',
            'name': 'Fresh Milk 1L',
            'price': 1.50,
            'quantity': 3,
          },
        ],
        'subtotal': 4.50,
        'updatedAt': '2026-09-10T12:00:00.000Z',
      });

      final result = await cartRepository.addItem(
        itemId: 'item-1',
        quantity: 3,
      );

      expect(result.isSuccess, isTrue);
      final cart = result.dataOrNull!;
      expect(cart.items.first.quantity, equals(3));
      expect(cart.subtotal, equals(4.50));
      expect(mockTransport.lastUri?.path, equals('/api/cart/items'));
      expect(mockTransport.lastMethod, equals(HttpMethod.post));
      final sentBody = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
      expect(sentBody['itemId'], equals('item-1'));
      expect(sentBody['quantity'], equals(3));
    });

    test('setItemQuantity sends PATCH /cart/items/:itemId with quantity payload', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'userId': 'usr-1',
        'storeId': 'store-100',
        'items': [
          {
            'itemId': 'item-1',
            'name': 'Fresh Milk 1L',
            'price': 1.50,
            'quantity': 5,
          },
        ],
        'subtotal': 7.50,
        'updatedAt': '2026-09-10T12:00:00.000Z',
      });

      final result = await cartRepository.setItemQuantity(
        itemId: 'item-1',
        quantity: 5,
      );

      expect(result.isSuccess, isTrue);
      final cart = result.dataOrNull!;
      expect(cart.items.first.quantity, equals(5));
      expect(mockTransport.lastUri?.path, equals('/api/cart/items/item-1'));
      expect(mockTransport.lastMethod, equals(HttpMethod.patch));
      final sentBody = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
      expect(sentBody['quantity'], equals(5));
    });

    test('removeItem sends PATCH /cart/items/:itemId with quantity 0', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'userId': 'usr-1',
        'storeId': null,
        'items': [],
        'subtotal': 0.0,
        'updatedAt': '2026-09-10T12:00:00.000Z',
      });

      final result = await cartRepository.removeItem(itemId: 'item-1');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.isEmpty, isTrue);
      expect(mockTransport.lastUri?.path, equals('/api/cart/items/item-1'));
      expect(mockTransport.lastMethod, equals(HttpMethod.patch));
      final sentBody = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
      expect(sentBody['quantity'], equals(0));
    });

    test('clearCart sends DELETE /cart and returns empty CartModel', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'message': 'Cart cleared',
      });

      final result = await cartRepository.clearCart();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.isEmpty, isTrue);
      expect(mockTransport.lastUri?.path, equals('/api/cart'));
      expect(mockTransport.lastMethod, equals(HttpMethod.delete));
    });

    test('addItem maps 400 CART_STORE_MISMATCH to ValidationFailure', () async {
      mockTransport.statusCode = 400;
      mockTransport.responseBody = jsonEncode({
        'error': {
          'code': 'CART_STORE_MISMATCH',
          'message': 'Your cart contains items from a different store. Clear it first.',
        },
      });

      final result = await cartRepository.addItem(
        itemId: 'item-different-store',
        quantity: 1,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.failureOrNull?.message,
        equals('Your cart contains items from a different store. Clear it first.'),
      );
    });

    test('getCart maps 500 server error to ServerFailure', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({
        'error': {
          'code': 'INTERNAL_ERROR',
          'message': 'An unexpected error occurred',
        },
      });

      final result = await cartRepository.getCart();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ServerFailure>());
    });
  });
}
