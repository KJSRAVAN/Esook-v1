import 'dart:convert';

import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/store/data/repositories/store_orders_repository_impl.dart';
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
  group('StoreOrdersRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late StoreOrdersRepositoryImpl ordersRepository;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: mockTransport,
      );
      ordersRepository = StoreOrdersRepositoryImpl(apiClient: apiClient);
    });

    test('getStoreOrders queries /orders and maps scoped orders', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'orders': [
          {
            'id': 'ord-101',
            'order_number': 'ESK-101',
            'user_id': 'cust-1',
            'store_id': 'store-1',
            'status': 'pending',
            'fulfillment_type': 'delivery',
            'delivery_address': 'Al Olaya, Riyadh',
            'total_amount': '85.50',
            'items': [
              {
                'product_id': 'prod-1',
                'product_name': 'Fresh Milk 1L',
                'unit_price': '10.50',
                'quantity': 2,
                'subtotal': '21.00',
              }
            ],
            'created_at': '2026-09-17T12:00:00Z',
          }
        ]
      });

      final result = await ordersRepository.getStoreOrders(
        storeId: 'store-1',
        status: 'PENDING',
        page: 1,
        limit: 20,
      );

      expect(result.isSuccess, isTrue);
      final orders = result.dataOrNull!;
      expect(orders.length, 1);
      expect(orders.first.id, 'ord-101');
      expect(orders.first.orderNumber, 'ESK-101');
      expect(orders.first.status, OrderStatus.pending);
      expect(orders.first.total, 85.50);
      expect(mockTransport.lastUri?.path, '/orders');
      expect(mockTransport.lastUri?.path, isNot(contains('store-1')));
    });

    test('getOrderById retrieves single order from /orders/:id', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'order': {
          'id': 'ord-101',
          'order_number': 'ESK-101',
          'user_id': 'cust-1',
          'store_id': 'store-1',
          'status': 'accepted',
          'fulfillment_type': 'pickup',
          'total_amount': '50.00',
          'items': [],
        }
      });

      final result = await ordersRepository.getOrderById('ord-101');

      expect(result.isSuccess, isTrue);
      final order = result.dataOrNull!;
      expect(order.id, 'ord-101');
      expect(order.status, OrderStatus.accepted);
      expect(mockTransport.lastUri?.path, '/orders/ord-101');
    });

    test('updateOrderStatus sends PATCH /orders/:id/status with lowercase backend status', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'order': {
          'id': 'ord-101',
          'order_number': 'ESK-101',
          'user_id': 'cust-1',
          'store_id': 'store-1',
          'status': 'preparing',
          'fulfillment_type': 'delivery',
          'total_amount': '85.50',
          'items': [],
        }
      });

      final result = await ordersRepository.updateOrderStatus(
        orderId: 'ord-101',
        status: OrderStatus.preparing,
      );

      expect(result.isSuccess, isTrue);
      final order = result.dataOrNull!;
      expect(order.status, OrderStatus.preparing);
      expect(mockTransport.lastUri?.path, '/orders/ord-101/status');
      expect(mockTransport.lastMethod, HttpMethod.patch);
      expect(mockTransport.lastBody, contains('"status":"preparing"'));
      expect(mockTransport.lastBody, isNot(contains('"status":"PREPARING"')));
    });

    test('updateOrderStatus maps terminal success state to completed', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'order': {
          'id': 'ord-101',
          'order_number': 'ESK-101',
          'user_id': 'cust-1',
          'store_id': 'store-1',
          'status': 'completed',
          'fulfillment_type': 'delivery',
          'total_amount': '85.50',
          'items': [],
        }
      });

      final result = await ordersRepository.updateOrderStatus(
        orderId: 'ord-101',
        status: OrderStatus.delivered,
      );

      expect(result.isSuccess, isTrue);
      expect(mockTransport.lastBody, contains('"status":"completed"'));
    });

    test('updateOrderStatus handles rejection without sending unsupported rejectedReason to backend', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'order': {
          'id': 'ord-101',
          'order_number': 'ESK-101',
          'user_id': 'cust-1',
          'store_id': 'store-1',
          'status': 'rejected',
          'fulfillment_type': 'delivery',
          'total_amount': '85.50',
          'items': [],
        }
      });

      final result = await ordersRepository.updateOrderStatus(
        orderId: 'ord-101',
        status: OrderStatus.rejected,
        rejectedReason: 'Store closed for maintenance',
      );

      expect(result.isSuccess, isTrue);
      final order = result.dataOrNull!;
      expect(order.status, OrderStatus.rejected);
      expect(mockTransport.lastBody, contains('"status":"rejected"'));
      expect(mockTransport.lastBody, isNot(contains('rejectedReason')));
      expect(mockTransport.lastBody, isNot(contains('rejected_reason')));
      expect(mockTransport.lastBody, isNot(contains('Store closed for maintenance')));
    });
  });
}
