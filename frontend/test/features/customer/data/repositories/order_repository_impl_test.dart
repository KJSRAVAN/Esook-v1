import 'dart:convert';

import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/customer/data/repositories/order_repository_impl.dart';
import 'package:esouq/features/customer/domain/models/order_item_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
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
  group('OrderRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late OrderRepositoryImpl orderRepository;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com/api',
        transport: mockTransport,
      );
      orderRepository = OrderRepositoryImpl(apiClient: apiClient);
    });

    test(
      'createOrder sends POST /orders with correct body and X-Idempotency-Key header',
      () async {
        mockTransport.statusCode = 201;
        mockTransport.responseBody = jsonEncode({
          'order': {
            'id': 'ord-100',
            'orderNumber': 'ESK-2026-001',
            'customerId': 'usr-1',
            'storeId': 'store-1',
            'status': 'PENDING',
            'fulfillment': 'DELIVERY',
            'deliveryAddress': 'Building 4B, Riyadh',
            'couponCode': 'SAVE5',
            'notes': 'Doorbell broken',
            'subtotal': 10.00,
            'total': 10.00,
            'items': [
              {
                'id': 'line-1',
                'itemId': 'prod-1',
                'itemName': 'Fresh Milk',
                'itemPrice': 2.50,
                'quantity': 4,
                'subtotal': 10.00,
              },
            ],
          },
        });

        final result = await orderRepository.createOrder(
          storeId: 'store-1',
          fulfillment: FulfillmentType.delivery,
          deliveryAddress: 'Building 4B, Riyadh',
          couponCode: 'SAVE5',
          notes: 'Doorbell broken',
          items: const [OrderItemInput(itemId: 'prod-1', quantity: 4)],
          idempotencyKey: 'a1b2c3d4-e5f6-47a8-b9c0-d1e2f3a4b5c6',
        );

        expect(result.isSuccess, isTrue);
        final order = result.dataOrNull!;
        expect(order.id, equals('ord-100'));
        expect(order.orderNumber, equals('ESK-2026-001'));
        expect(order.status, equals(OrderStatus.pending));
        expect(order.fulfillment, equals(FulfillmentType.delivery));
        expect(order.deliveryAddress, equals('Building 4B, Riyadh'));
        expect(order.items.length, equals(1));
        expect(order.items.first.quantity, equals(4));

        expect(mockTransport.lastUri?.path, equals('/api/orders'));
        expect(mockTransport.lastMethod, equals(HttpMethod.post));
        expect(
          mockTransport.lastHeaders?['X-Idempotency-Key'],
          equals('a1b2c3d4-e5f6-47a8-b9c0-d1e2f3a4b5c6'),
        );

        final decodedBody =
            jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(decodedBody['storeId'], equals('store-1'));
        expect(decodedBody['fulfillment'], equals('DELIVERY'));
        expect(decodedBody['deliveryAddress'], equals('Building 4B, Riyadh'));
        expect(decodedBody['couponCode'], equals('SAVE5'));
        expect(decodedBody['notes'], equals('Doorbell broken'));
        expect(
          decodedBody['items'],
          equals([
            {'itemId': 'prod-1', 'quantity': 4},
          ]),
        );
        expect(decodedBody.containsKey('store_id'), isFalse);
        expect(decodedBody.containsKey('fulfillment_type'), isFalse);
        expect(decodedBody.containsKey('delivery_address'), isFalse);
        expect(decodedBody.containsKey('coupon_code'), isFalse);
      },
    );

    test(
      'createOrder without delivery address on PICKUP fulfillment omits deliveryAddress',
      () async {
        mockTransport.statusCode = 201;
        mockTransport.responseBody = jsonEncode({
          'order': {
            'id': 'ord-101',
            'storeId': 'store-1',
            'status': 'PENDING',
            'fulfillment': 'PICKUP',
            'subtotal': 5.00,
            'total': 5.00,
            'items': [],
          },
        });

        final result = await orderRepository.createOrder(
          storeId: 'store-1',
          fulfillment: FulfillmentType.pickup,
          items: const [OrderItemInput(itemId: 'prod-2', quantity: 1)],
        );

        expect(result.isSuccess, isTrue);
        final decodedBody =
            jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(decodedBody['storeId'], equals('store-1'));
        expect(decodedBody['fulfillment'], equals('PICKUP'));
        expect(
          decodedBody['items'],
          equals([
            {'itemId': 'prod-2', 'quantity': 1},
          ]),
        );
        expect(decodedBody.containsKey('delivery_address'), isFalse);
        expect(decodedBody.containsKey('deliveryAddress'), isFalse);
        expect(decodedBody.containsKey('store_id'), isFalse);
        expect(decodedBody.containsKey('fulfillment_type'), isFalse);
      },
    );

    test(
      'createOrder maps 400 validation error to ValidationFailure',
      () async {
        mockTransport.statusCode = 400;
        mockTransport.responseBody = jsonEncode({
          'errors': ['delivery_address is required for delivery orders'],
        });

        final result = await orderRepository.createOrder(
          storeId: 'store-1',
          fulfillment: FulfillmentType.delivery,
          items: const [OrderItemInput(itemId: 'prod-1', quantity: 1)],
        );

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<ValidationFailure>());
      },
    );

    test(
      'getMyOrders returns parsed list from GET /orders/my with query parameters',
      () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'orders': [
            {
              'id': 'ord-1',
              'orderNumber': 'ESK-001',
              'customerId': 'usr-1',
              'storeId': 'store-1',
              'status': 'DELIVERED',
              'fulfillment': 'DELIVERY',
              'subtotal': 25.0,
              'total': 25.0,
              'items': [
                {
                  'itemId': 'prod-1',
                  'itemName': 'Apples',
                  'itemPrice': 5.0,
                  'quantity': 5,
                  'subtotal': 25.0,
                },
              ],
            },
            {
              'id': 'ord-2',
              'orderNumber': 'ESK-002',
              'customerId': 'usr-1',
              'total': 12.0,
              'items': [],
            },
          ],
        });

        final result = await orderRepository.getMyOrders(
          page: 1,
          limit: 10,
          status: OrderStatus.delivered,
        );

        expect(result.isSuccess, isTrue);
        final orders = result.dataOrNull!;
        expect(orders.length, equals(2));
        expect(orders[0].id, equals('ord-1'));
        expect(orders[0].status, equals(OrderStatus.delivered));
        expect(orders[1].id, equals('ord-2'));
        expect(orders[1].status, equals(OrderStatus.pending));

        expect(mockTransport.lastUri?.path, equals('/api/orders/my'));
        expect(mockTransport.lastUri?.queryParameters['page'], equals('1'));
        expect(mockTransport.lastUri?.queryParameters['limit'], equals('10'));
        expect(
          mockTransport.lastUri?.queryParameters['status'],
          equals('DELIVERED'),
        );
      },
    );

    test(
      'getOrderById returns single order details from GET /orders/:id',
      () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'order': {
            'id': 'ord-555',
            'orderNumber': 'ESK-555',
            'customerId': 'usr-1',
            'storeId': 'store-1',
            'status': 'READY',
            'fulfillment': 'PICKUP',
            'subtotal': 30.0,
            'total': 30.0,
            'items': [
              {
                'itemId': 'prod-9',
                'itemName': 'Coffee Beans 500g',
                'itemPrice': 15.0,
                'quantity': 2,
                'subtotal': 30.0,
              },
            ],
          },
        });

        final result = await orderRepository.getOrderById('ord-555');

        expect(result.isSuccess, isTrue);
        final order = result.dataOrNull!;
        expect(order.id, equals('ord-555'));
        expect(order.status, equals(OrderStatus.ready));
        expect(order.items.length, equals(1));
        expect(mockTransport.lastUri?.path, equals('/api/orders/ord-555'));
        expect(mockTransport.lastMethod, equals(HttpMethod.get));
      },
    );

    test('getOrderById maps 404 to NotFoundFailure', () async {
      mockTransport.statusCode = 404;
      mockTransport.responseBody = jsonEncode({'error': 'Order not found'});

      final result = await orderRepository.getOrderById('nonexistent');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('getMyOrders maps 500 server error to ServerFailure', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({
        'error': 'Internal server error',
      });

      final result = await orderRepository.getMyOrders();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ServerFailure>());
    });
  });
}
