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
  'customer': {'full_name': 'Ahmed Customer', 'phone_number': '+966501234567'},
  'total_amount': '85.50',
  'created_at': '2026-09-17T12:00:00Z',
};

final _backendOrderOutForDelivery = {
  ..._backendOrderPreparing,
  'id': 'order-002',
  'order_number': 'ESK-ORDER-002',
  'status': 'out_for_delivery',
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
    // GET /drivers/orders/available (Available Orders)
    // -----------------------------------------------------------------------
    group('getAvailableOrders', () {
      test('calls GET /drivers/orders/available and parses orders', () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode([_backendOrderPreparing]);

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
        expect(mockTransport.lastUri?.path, '/drivers/orders/available');
        expect(mockTransport.lastMethod, HttpMethod.get);
      });

      test('returns empty list when no orders available', () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode([]);

        final result = await repository.getAvailableOrders();

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isEmpty);
        expect(mockTransport.lastUri?.path, '/drivers/orders/available');
      });

      test('returns failure on 401 unauthorized', () async {
        mockTransport.statusCode = 401;
        mockTransport.responseBody = jsonEncode({
          'message': 'Invalid credentials',
        });

        final result = await repository.getAvailableOrders();

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.statusCode, 401);
      });

      test('returns failure on 500 server error', () async {
        mockTransport.statusCode = 500;
        mockTransport.responseBody = jsonEncode({
          'message': 'Internal server error',
        });

        final result = await repository.getAvailableOrders();

        expect(result.isFailure, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // GET /drivers/orders/active (Active Order)
    // -----------------------------------------------------------------------
    group('getActiveOrder', () {
      test(
        'calls GET /drivers/orders/active and parses active delivery order',
        () async {
          mockTransport.statusCode = 200;
          mockTransport.responseBody = jsonEncode(_backendOrderOutForDelivery);

          final result = await repository.getActiveOrder();

          expect(result.isSuccess, isTrue);
          final order = result.dataOrNull;
          expect(order, isNotNull);
          expect(order!.id, 'order-002');
          expect(order.status, RiderOrderStatus.outForDelivery);
          expect(mockTransport.lastUri?.path, '/drivers/orders/active');
          expect(mockTransport.lastMethod, HttpMethod.get);
        },
      );

      test('returns null when no active delivery order', () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = 'null';

        final result = await repository.getActiveOrder();

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
      });

      test('returns null when response body is empty map', () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode({});

        final result = await repository.getActiveOrder();

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
      });

      test('returns failure on 403 forbidden', () async {
        mockTransport.statusCode = 403;
        mockTransport.responseBody = jsonEncode({
          'error': 'Forbidden: Delivery rider is not assigned to a store',
        });

        final result = await repository.getActiveOrder();

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.statusCode, 403);
      });
    });

    // -----------------------------------------------------------------------
    // POST /drivers/orders/:orderId/accept (Accept / Self-assign)
    // -----------------------------------------------------------------------
    group('acceptOrder', () {
      test('calls POST /drivers/orders/:orderId/accept', () async {
        final updatedOrder = {
          ..._backendOrderPreparing,
          'status': 'OUT_FOR_DELIVERY',
        };

        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode(updatedOrder);

        final result = await repository.acceptOrder('order-001');

        expect(result.isSuccess, isTrue);
        final order = result.dataOrNull!;
        expect(order.status, RiderOrderStatus.outForDelivery);
        expect(mockTransport.lastUri?.path, '/drivers/orders/order-001/accept');
        expect(mockTransport.lastMethod, HttpMethod.post);
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
        mockTransport.responseBody = jsonEncode({'error': 'Order not found'});

        final result = await repository.acceptOrder('order-999');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<NotFoundFailure>());
      });
    });

    // -----------------------------------------------------------------------
    // PATCH /drivers/orders/:orderId/status (Complete Delivery)
    // -----------------------------------------------------------------------
    group('markDelivered', () {
      test(
        'calls PATCH /drivers/orders/:orderId/status with DELIVERED body',
        () async {
          final completedOrder = {
            ..._backendOrderOutForDelivery,
            'status': 'DELIVERED',
          };

          mockTransport.statusCode = 200;
          mockTransport.responseBody = jsonEncode(completedOrder);

          final result = await repository.markDelivered('order-002');

          expect(result.isSuccess, isTrue);
          final order = result.dataOrNull!;
          expect(order.status, RiderOrderStatus.delivered);
          expect(
            mockTransport.lastUri?.path,
            '/drivers/orders/order-002/status',
          );
          expect(mockTransport.lastMethod, HttpMethod.patch);

          final body =
              jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
          expect(body['status'], 'DELIVERED');
        },
      );

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
        mockTransport.responseBody = jsonEncode({'error': 'Order not found'});

        final result = await repository.markDelivered('order-999');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<NotFoundFailure>());
      });
    });
  });
}
