import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esouq/core/error/failures.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/presentation/screens/customer_order_history_screen.dart';
import '../../mocks/mock_order_repository.dart';

void main() {
  late MockOrderRepository mockOrderRepo;

  setUp(() {
    mockOrderRepo = MockOrderRepository();
  });

  OrderModel createTestOrder({
    required String id,
    required OrderStatus status,
    required double total,
    required DateTime createdAt,
    String? rejectedReason,
    String? orderNumber,
  }) {
    return OrderModel(
      id: id,
      orderNumber: orderNumber ?? 'ESK-$id',
      customerId: 'cust-1',
      storeId: 'store-1',
      storeName: 'eSOuQ Supermarket',
      status: status,
      fulfillment: FulfillmentType.delivery,
      subtotal: total - 1.5,
      deliveryFee: 1.5,
      discount: 0,
      total: total,
      pointsEarned: 10,
      items: const [],
      paymentMethod: PaymentMethod.card,
      createdAt: createdAt,
      rejectedReason: rejectedReason,
    );
  }

  Widget createWidgetUnderTest({MockOrderRepository? repo}) {
    return MaterialApp(
      home: CustomerOrderHistoryScreen(
        orderRepository: repo ?? mockOrderRepo,
      ),
    );
  }

  group('CustomerOrderHistoryScreen Tests', () {
    testWidgets('shows loading then displays orders and highlights', (tester) async {
      final pendingOrder = createTestOrder(
        id: 'ord-pending',
        status: OrderStatus.pending,
        total: 25.0,
        createdAt: DateTime(2026, 9, 20, 14, 30),
      );
      final completedOrder = createTestOrder(
        id: 'ord-completed',
        status: OrderStatus.delivered,
        total: 50.0,
        createdAt: DateTime(2026, 9, 18, 11, 0),
      );
      final cancelledOrder = createTestOrder(
        id: 'ord-cancelled',
        status: OrderStatus.cancelled,
        total: 15.0,
        createdAt: DateTime(2026, 9, 15, 9, 0),
      );
      final rejectedOrder = createTestOrder(
        id: 'ord-rejected',
        status: OrderStatus.rejected,
        total: 30.0,
        createdAt: DateTime(2026, 9, 10, 8, 0),
        rejectedReason: 'Out of stock at store',
      );

      mockOrderRepo.ordersToReturn = [
        pendingOrder,
        completedOrder,
        cancelledOrder,
        rejectedOrder,
      ];

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify Latest Pending highlight card
      expect(find.byKey(const Key('latest_pending_order_card')), findsOneWidget);
      expect(find.text('Latest Pending Order'), findsOneWidget);
      expect(find.text('25.00 SAR'), findsWidgets);

      // Verify Latest Completed highlight card
      expect(find.byKey(const Key('latest_completed_order_card')), findsOneWidget);
      expect(find.text('Latest Completed Order'), findsOneWidget);
      expect(find.text('50.00 SAR'), findsWidgets);

      // Verify order cards in the list
      expect(find.byKey(const Key('history_order_card_ord-pending')), findsOneWidget);
      expect(find.byKey(const Key('history_order_card_ord-completed')), findsOneWidget);
      expect(find.byKey(const Key('history_order_card_ord-cancelled')), findsOneWidget);
      expect(find.byKey(const Key('history_order_card_ord-rejected')), findsOneWidget);

      // Verify rejected order shows rejection reason
      expect(find.byKey(const Key('rejected_reason_ord-rejected')), findsOneWidget);
      expect(find.text('Rejected: Out of stock at store'), findsOneWidget);

      // Verify status badges
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Delivered'), findsWidgets);
      expect(find.text('Cancelled'), findsWidgets);
      expect(find.text('Rejected'), findsWidgets);
    });

    testWidgets('status filter chips filter the orders', (tester) async {
      mockOrderRepo.ordersToReturn = [];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(mockOrderRepo.lastStatusParam, isNull);

      // Tap PENDING chip
      await tester.tap(find.byKey(const Key('order_history_chip_PENDING')));
      await tester.pumpAndSettle();
      expect(mockOrderRepo.lastStatusParam, equals(OrderStatus.pending));

      // Tap DELIVERED chip
      await tester.tap(find.byKey(const Key('order_history_chip_DELIVERED')));
      await tester.pumpAndSettle();
      expect(mockOrderRepo.lastStatusParam, equals(OrderStatus.delivered));

      // Tap CANCELLED chip
      await tester.tap(find.byKey(const Key('order_history_chip_CANCELLED')));
      await tester.pumpAndSettle();
      expect(mockOrderRepo.lastStatusParam, equals(OrderStatus.cancelled));

      // Tap REJECTED chip
      await tester.tap(find.byKey(const Key('order_history_chip_REJECTED')));
      await tester.pumpAndSettle();
      expect(mockOrderRepo.lastStatusParam, equals(OrderStatus.rejected));

      // Tap ALL chip
      await tester.tap(find.byKey(const Key('order_history_chip_ALL')));
      await tester.pumpAndSettle();
      expect(mockOrderRepo.lastStatusParam, isNull);
    });

    testWidgets('displays empty state when no orders returned', (tester) async {
      mockOrderRepo.ordersToReturn = [];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('No Orders Found'), findsOneWidget);
      expect(find.text('You have not placed any orders yet.'), findsOneWidget);
    });

    testWidgets('displays error state and retries on button tap', (tester) async {
      mockOrderRepo.failureToReturn = const ServerFailure(message: 'Network connection failed');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load order history'), findsOneWidget);
      expect(find.text('Network connection failed'), findsOneWidget);
      expect(find.byKey(const Key('order_history_retry_btn')), findsOneWidget);

      // Now set success and tap retry
      mockOrderRepo.failureToReturn = null;
      mockOrderRepo.ordersToReturn = [
        createTestOrder(
          id: 'ord-retry',
          status: OrderStatus.delivered,
          total: 12.0,
          createdAt: DateTime(2026, 9, 20),
        ),
      ];

      await tester.tap(find.byKey(const Key('order_history_retry_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load order history'), findsNothing);
      expect(find.byKey(const Key('history_order_card_ord-retry')), findsOneWidget);
    });
  });
}
