import 'dart:convert';

import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/rider/data/repositories/rider_repository_impl.dart';
import 'package:esouq/features/rider/domain/models/rider_order_model.dart';
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

final _backendOrderPreparing = {
  'id': 'order-001',
  'order_number': 'ESK-ORDER-001',
  'status': 'preparing',
  'fulfillment_type': 'delivery',
  'delivery_address': 'Villa 12, Riyadh',
  'store_id': 's1',
  'store_name': 'Store A',
  'customer_id': 'c1',
  'customer': {
    'full_name': 'Ahmed Customer',
    'phone_number': '+966501234567',
  },
  'total_amount': '85.50',
  'created_at': '2026-09-17T12:00:00Z',
};

final _backendOrderOutForDelivery = {
  ..._backendOrderPreparing,
  'id': 'order-002',
  'order_number': 'ESK-ORDER-002',
  'status': 'out_for_delivery',
};

final _backendOrderPickup = {
  ..._backendOrderPreparing,
  'id': 'order-003',
  'order_number': 'ESK-ORDER-003',
  'fulfillment_type': 'pickup',
  'status': 'preparing',
};

void main() {
  group('RiderRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late RiderRepositoryImpl repository;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: mockTransport,
      );
      repository = RiderRepositoryImpl(apiClient: apiClient);
    });

    // -----------------------------------------------------------------------
    // GET /orders (Available Orders)
    // -----------------------------------------------------------------------
    group('getAvailableOrders', () {
      test('calls GET /orders and filters delivery orders in preparing status',
          () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'orders': [
            _backendOrderPreparing,
            _backendOrderPickup, // Should be filtered out (pickup)
            _backendOrderOutForDelivery, // Should be filtered out (already active)
          ],
        });

        final result = await repository.getAvailableOrders();

        expect(result.isSuccess, isTrue);
        final orders = result.dataOrNull!;
        expect(orders, hasLength(1));
        expect(orders.first.id, 'order-001');
        expect(orders.first.orderNumber, 'ESK-ORDER-001');
        expect(orders.first.status, RiderOrderStatus.ready);
        expect(orders.first.store.name, 'Store A');
        expect(orders.first.customer.phone, '+966501234567');
        expect(orders.first.customer.name, 'Ahmed Customer');
        expect(orders.first.deliveryAddress, 'Villa 12, Riyadh');
        expect(mockTransport.lastUri?.path, '/orders');
        expect(mockTransport.lastMethod, HttpMethod.get);
      });

      test('returns empty list when no orders available', () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({'orders': []});

        final result = await repository.getAvailableOrders();

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isEmpty);
        expect(mockTransport.lastUri?.path, '/orders');
      });

      test('returns failure on 401 unauthorized', () async {
        mockTransport.statusCode = 401;
        mockTransport.responseBody =
            jsonEncode({'message': 'Invalid credentials'});

        final result = await repository.getAvailableOrders();

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.statusCode, 401);
      });

      test('returns failure on 500 server error', () async {
        mockTransport.statusCode = 500;
        mockTransport.responseBody =
            jsonEncode({'message': 'Internal server error'});

        final result = await repository.getAvailableOrders();

        expect(result.isFailure, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // GET /orders (Active Order)
    // -----------------------------------------------------------------------
    group('getActiveOrder', () {
      test('calls GET /orders and extracts active delivery order (out_for_delivery)',
          () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'orders': [
            _backendOrderPreparing,
            _backendOrderOutForDelivery,
          ],
        });

        final result = await repository.getActiveOrder();

        expect(result.isSuccess, isTrue);
        final order = result.dataOrNull;
        expect(order, isNotNull);
        expect(order!.id, 'order-002');
        expect(order.status, RiderOrderStatus.outForDelivery);
        expect(mockTransport.lastUri?.path, '/orders');
        expect(mockTransport.lastMethod, HttpMethod.get);
      });

      test('returns null when no active delivery order', () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({
          'orders': [_backendOrderPreparing],
        });

        final result = await repository.getActiveOrder();

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
      });

      test('returns null when response orders list is empty', () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({'orders': []});

        final result = await repository.getActiveOrder();

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
      });

      test('returns failure on 403 forbidden', () async {
        mockTransport.statusCode = 403;
        mockTransport.responseBody =
            jsonEncode({'error': 'Forbidden: Delivery rider is not assigned to a store'});

        final result = await repository.getActiveOrder();

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.statusCode, 403);
      });
    });

    // -----------------------------------------------------------------------
    // PATCH /orders/:orderId/status (Start Delivery / Accept)
    // -----------------------------------------------------------------------
    group('acceptOrder', () {
      test('calls PATCH /orders/:orderId/status with out_for_delivery body',
          () async {
        final updatedOrder = {
          ..._backendOrderPreparing,
          'status': 'out_for_delivery',
        };

        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({'order': updatedOrder});

        final result = await repository.acceptOrder('order-001');

        expect(result.isSuccess, isTrue);
        final order = result.dataOrNull!;
        expect(order.status, RiderOrderStatus.outForDelivery);
        expect(
          mockTransport.lastUri?.path,
          '/orders/order-001/status',
        );
        expect(mockTransport.lastMethod, HttpMethod.patch);

        final body = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(body['status'], 'out_for_delivery');
      });

      test('returns ConflictFailure on 409 conflict', () async {
        mockTransport.statusCode = 409;
        mockTransport.responseBody = jsonEncode({
          'message': 'Order was already modified by another user',
        });

        final result = await repository.acceptOrder('order-001');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<ConflictFailure>());
      });

      test('returns NotFoundFailure on 404', () async {
        mockTransport.statusCode = 404;
        mockTransport.responseBody =
            jsonEncode({'error': 'Order not found'});

        final result = await repository.acceptOrder('order-999');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<NotFoundFailure>());
      });
    });

    // -----------------------------------------------------------------------
    // PATCH /orders/:orderId/status (Complete Delivery)
    // -----------------------------------------------------------------------
    group('markDelivered', () {
      test('calls PATCH /orders/:orderId/status with lowercase completed body',
          () async {
        final completedOrder = {
          ..._backendOrderOutForDelivery,
          'status': 'completed',
        };

        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({'order': completedOrder});

        final result = await repository.markDelivered('order-002');

        expect(result.isSuccess, isTrue);
        final order = result.dataOrNull!;
        expect(order.status, RiderOrderStatus.delivered);
        expect(
          mockTransport.lastUri?.path,
          '/orders/order-002/status',
        );
        expect(mockTransport.lastMethod, HttpMethod.patch);

        // Verify the request body contains { "status": "completed" } and never "DELIVERED"
        final body = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(body['status'], 'completed');
        expect(mockTransport.lastBody, isNot(contains('DELIVERED')));
      });

      test('returns ForbiddenFailure on 403', () async {
        mockTransport.statusCode = 403;
        mockTransport.responseBody = jsonEncode({
          'error': 'Forbidden: Cannot access orders belonging to another store',
        });

        final result = await repository.markDelivered('order-002');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<ForbiddenFailure>());
      });

      test('returns NotFoundFailure on 404', () async {
        mockTransport.statusCode = 404;
        mockTransport.responseBody =
            jsonEncode({'error': 'Order not found'});

        final result = await repository.markDelivered('order-999');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<NotFoundFailure>());
      });
    });
  });
}
