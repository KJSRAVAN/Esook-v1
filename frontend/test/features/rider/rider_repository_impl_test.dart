import 'dart:convert';

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

final _sampleOrder = {
  'id': 'order-001',
  'status': 'READY',
  'fulfillment': 'DELIVERY',
  'deliveryAddress': 'Villa 12, Riyadh',
  'notes': 'Leave at gate',
  'driverId': null,
  'createdAt': '2026-09-17T12:00:00Z',
  'store': {
    'id': 's1',
    'name': 'Store A',
    'address': 'Al Olaya, Riyadh',
    'phone': '+9661',
  },
  'customer': {'phone': '+966501234567'},
};

final _activeOrder = {
  ..._sampleOrder,
  'status': 'OUT_FOR_DELIVERY',
  'driverId': 'driver-001',
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
    // GET /drivers/orders/available
    // -----------------------------------------------------------------------
    group('getAvailableOrders', () {
      test('calls GET /drivers/orders/available and parses order list',
          () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode([_sampleOrder]);

        final result = await repository.getAvailableOrders();

        expect(result.isSuccess, isTrue);
        final orders = result.dataOrNull!;
        expect(orders, hasLength(1));
        expect(orders.first.id, 'order-001');
        expect(orders.first.status, RiderOrderStatus.ready);
        expect(orders.first.store.name, 'Store A');
        expect(orders.first.customer.phone, '+966501234567');
        expect(mockTransport.lastUri?.path, '/drivers/orders/available');
        expect(mockTransport.lastMethod, HttpMethod.get);
      });

      test('returns empty list when no orders available', () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode([]);

        final result = await repository.getAvailableOrders();

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isEmpty);
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
    // GET /drivers/orders/active
    // -----------------------------------------------------------------------
    group('getActiveOrder', () {
      test('calls GET /drivers/orders/active and parses active order',
          () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode(_activeOrder);

        final result = await repository.getActiveOrder();

        expect(result.isSuccess, isTrue);
        final order = result.dataOrNull;
        expect(order, isNotNull);
        expect(order!.id, 'order-001');
        expect(order.status, RiderOrderStatus.outForDelivery);
        expect(order.driverId, 'driver-001');
        expect(mockTransport.lastUri?.path, '/drivers/orders/active');
        expect(mockTransport.lastMethod, HttpMethod.get);
      });

      test('returns null when no active order (null response)', () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = 'null';

        final result = await repository.getActiveOrder();

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
      });

      test('returns null when no active order (empty string)', () async {
        mockTransport.statusCode = 200;
        mockTransport.responseBody = '';

        final result = await repository.getActiveOrder();

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
      });

      test('returns failure on 403 forbidden', () async {
        mockTransport.statusCode = 403;
        mockTransport.responseBody =
            jsonEncode({'message': 'Not authorized'});

        final result = await repository.getActiveOrder();

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.statusCode, 403);
      });
    });

    // -----------------------------------------------------------------------
    // POST /drivers/orders/:orderId/accept
    // -----------------------------------------------------------------------
    group('acceptOrder', () {
      test('calls POST /drivers/orders/:orderId/accept and returns accepted order',
          () async {
        final accepted = {
          ..._sampleOrder,
          'status': 'OUT_FOR_DELIVERY',
          'driverId': 'driver-001',
        };

        mockTransport.statusCode = 201;
        mockTransport.responseBody = jsonEncode(accepted);

        final result = await repository.acceptOrder('order-001');

        expect(result.isSuccess, isTrue);
        final order = result.dataOrNull!;
        expect(order.status, RiderOrderStatus.outForDelivery);
        expect(order.driverId, 'driver-001');
        expect(
          mockTransport.lastUri?.path,
          '/drivers/orders/order-001/accept',
        );
        expect(mockTransport.lastMethod, HttpMethod.post);
      });

      test('returns ConflictFailure on 409 DRIVER_BUSY', () async {
        mockTransport.statusCode = 409;
        mockTransport.responseBody = jsonEncode({
          'code': 'DRIVER_BUSY',
          'message':
              'You already have an active delivery. Complete it before accepting another.',
        });

        final result = await repository.acceptOrder('order-001');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.statusCode, 409);
        expect(result.failureOrNull?.message, contains('active delivery'));
      });

      test('returns ConflictFailure on 409 ORDER_UNAVAILABLE', () async {
        mockTransport.statusCode = 409;
        mockTransport.responseBody = jsonEncode({
          'code': 'ORDER_UNAVAILABLE',
          'message': 'Order is no longer available for pickup',
        });

        final result = await repository.acceptOrder('order-001');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.statusCode, 409);
      });

      test('returns NotFoundFailure on 404', () async {
        mockTransport.statusCode = 404;
        mockTransport.responseBody =
            jsonEncode({'message': 'Order not found'});

        final result = await repository.acceptOrder('order-999');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.statusCode, 404);
      });

      test('returns ValidationFailure on 400 NOT_DELIVERY', () async {
        mockTransport.statusCode = 400;
        mockTransport.responseBody = jsonEncode({
          'code': 'NOT_DELIVERY',
          'message': 'This order is not a delivery order',
        });

        final result = await repository.acceptOrder('order-pickup');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.statusCode, 400);
      });
    });

    // -----------------------------------------------------------------------
    // PATCH /drivers/orders/:orderId/status
    // -----------------------------------------------------------------------
    group('markDelivered', () {
      test('calls PATCH /drivers/orders/:orderId/status with DELIVERED body',
          () async {
        final delivered = {
          ..._sampleOrder,
          'status': 'DELIVERED',
          'driverId': 'driver-001',
        };

        mockTransport.statusCode = 200;
        mockTransport.responseBody = jsonEncode(delivered);

        final result = await repository.markDelivered('order-001');

        expect(result.isSuccess, isTrue);
        final order = result.dataOrNull!;
        expect(order.status, RiderOrderStatus.delivered);
        expect(
          mockTransport.lastUri?.path,
          '/drivers/orders/order-001/status',
        );
        expect(mockTransport.lastMethod, HttpMethod.patch);

        // Verify the request body contains { "status": "DELIVERED" }
        final body = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
        expect(body['status'], 'DELIVERED');
      });

      test('returns ForbiddenFailure on 403 (different driver)', () async {
        mockTransport.statusCode = 403;
        mockTransport.responseBody = jsonEncode({
          'message': 'This order is not assigned to you',
        });

        final result = await repository.markDelivered('order-001');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.statusCode, 403);
        expect(result.failureOrNull?.message, contains('not assigned'));
      });

      test('returns NotFoundFailure on 404', () async {
        mockTransport.statusCode = 404;
        mockTransport.responseBody =
            jsonEncode({'message': 'Order not found'});

        final result = await repository.markDelivered('order-999');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.statusCode, 404);
      });

      test('returns ValidationFailure on 400 INVALID_TRANSITION', () async {
        mockTransport.statusCode = 400;
        mockTransport.responseBody = jsonEncode({
          'code': 'INVALID_TRANSITION',
          'message':
              'Cannot transition from DELIVERED to DELIVERED',
        });

        final result = await repository.markDelivered('order-001');

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.statusCode, 400);
      });
    });
  });
}
