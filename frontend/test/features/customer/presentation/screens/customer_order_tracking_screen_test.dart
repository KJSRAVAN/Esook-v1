import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/domain/models/order_item_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/presentation/screens/customer_order_tracking_screen.dart';
import 'package:esouq/features/customer/presentation/widgets/order_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_order_repository.dart';

void main() {
  group('CustomerOrderTrackingScreen', () {
    late MockOrderRepository mockOrderRepository;

    final baseDeliveryOrder = OrderModel(
      id: 'ord-track-1',
      orderNumber: 'ESK-TRK-001',
      customerId: 'usr-1',
      storeId: 'store-1',
      storeName: 'eSOuQ Olaya Flagship',
      status: OrderStatus.pending,
      fulfillment: FulfillmentType.delivery,
      deliveryAddress: 'Villa 12, Olaya Street, Riyadh',
      notes: 'Ring the bell twice',
      subtotal: 50.0,
      deliveryFee: 10.0,
      total: 60.0,
      items: const [
        OrderItemModel(
          id: 'item-1',
          itemId: 'prod-1',
          itemName: 'Organic Milk 1L',
          itemPrice: 10.0,
          quantity: 2,
          subtotal: 20.0,
        ),
        OrderItemModel(
          id: 'item-2',
          itemId: 'prod-2',
          itemName: 'Whole Grain Bread',
          itemPrice: 15.0,
          quantity: 2,
          subtotal: 30.0,
        ),
      ],
      createdAt: DateTime.parse('2026-09-18T10:00:00Z'),
    );

    final basePickupOrder = OrderModel(
      id: 'ord-track-2',
      orderNumber: 'ESK-TRK-002',
      customerId: 'usr-1',
      storeId: 'store-1',
      storeName: 'eSOuQ Al Malqa',
      status: OrderStatus.pending,
      fulfillment: FulfillmentType.pickup,
      subtotal: 30.0,
      total: 30.0,
      items: const [
        OrderItemModel(
          id: 'item-1',
          itemId: 'prod-1',
          itemName: 'Apple Juice 1L',
          itemPrice: 15.0,
          quantity: 2,
          subtotal: 30.0,
        ),
      ],
      createdAt: DateTime.parse('2026-09-18T11:00:00Z'),
    );

    setUp(() {
      mockOrderRepository = MockOrderRepository();
      mockOrderRepository.orderToReturn = baseDeliveryOrder;
    });

    Widget buildTrackingScreen({
      String orderId = 'ord-track-1',
      OrderModel? initialOrder,
    }) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: CustomerOrderTrackingScreen(
          orderId: orderId,
          initialOrder: initialOrder,
          orderRepository: mockOrderRepository,
        ),
      );
    }

    testWidgets('1. initial order renders immediately without loading screen',
        (tester) async {
      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: baseDeliveryOrder),
      );
      // Pump initial frame only
      await tester.pump();

      expect(find.text('Order #ESK-TRK-001'), findsOneWidget);
      expect(find.text('eSOuQ Olaya Flagship'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('2. authoritative order fetch occurs on mount', (tester) async {
      final updatedAuthoritative = baseDeliveryOrder.copyWith(
        status: OrderStatus.accepted,
      );
      mockOrderRepository.orderToReturn = updatedAuthoritative;

      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: baseDeliveryOrder),
      );
      await tester.pumpAndSettle();

      expect(mockOrderRepository.getOrderByIdCallCount, equals(1));
      expect(find.text('Accepted'), findsOneWidget);
    });

    testWidgets('3. loading state is displayed when initialOrder is null',
        (tester) async {
      mockOrderRepository.customGetOrderByIdHandler = (orderId) async {
        // Slow async response
        return Result.success(baseDeliveryOrder);
      };

      await tester.pumpWidget(buildTrackingScreen(initialOrder: null));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Order #ESK-TRK-001'), findsOneWidget);
    });

    testWidgets('4. fetch error state displays message when initial fetch fails',
        (tester) async {
      mockOrderRepository.failureToReturn =
          const ServerFailure(message: 'Network connection lost');

      await tester.pumpWidget(buildTrackingScreen(initialOrder: null));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load order details'), findsOneWidget);
      expect(find.text('Network connection lost'), findsOneWidget);
      expect(find.byKey(const Key('tracking_retry_button')), findsOneWidget);
    });

    testWidgets('5. retry button re-triggers fetch on error', (tester) async {
      mockOrderRepository.failureToReturn =
          const ServerFailure(message: 'Timeout');

      await tester.pumpWidget(buildTrackingScreen(initialOrder: null));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load order details'), findsOneWidget);

      // Now set success and tap Retry
      mockOrderRepository.failureToReturn = null;
      mockOrderRepository.orderToReturn = baseDeliveryOrder;

      await tester.tap(find.byKey(const Key('tracking_retry_button')));
      await tester.pumpAndSettle();

      expect(find.text('Order #ESK-TRK-001'), findsOneWidget);
      expect(find.text('Unable to load order details'), findsNothing);
    });

    testWidgets('6. DELIVERY timeline renders 6 delivery milestones',
        (tester) async {
      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: baseDeliveryOrder),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order Placed'), findsOneWidget);
      expect(find.text('Order Accepted'), findsOneWidget);
      expect(find.text('Preparing'), findsOneWidget);
      expect(find.text('Ready for Driver'), findsOneWidget);
      expect(find.text('Out for Delivery'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
    });

    testWidgets('7. PICKUP timeline renders pickup milestones without Out for Delivery',
        (tester) async {
      mockOrderRepository.orderToReturn = basePickupOrder;

      await tester.pumpWidget(
        buildTrackingScreen(
          orderId: 'ord-track-2',
          initialOrder: basePickupOrder,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order Placed'), findsOneWidget);
      expect(find.text('Order Accepted'), findsOneWidget);
      expect(find.text('Preparing'), findsOneWidget);
      expect(find.text('Ready for Pickup'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Out for Delivery'), findsNothing);
    });

    testWidgets('8. PENDING state renders live status badge', (tester) async {
      mockOrderRepository.orderToReturn =
          baseDeliveryOrder.copyWith(status: OrderStatus.pending);

      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: mockOrderRepository.orderToReturn),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Live Updates'), findsOneWidget);
    });

    testWidgets('9. ACCEPTED state renders active milestone', (tester) async {
      mockOrderRepository.orderToReturn =
          baseDeliveryOrder.copyWith(status: OrderStatus.accepted);

      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: mockOrderRepository.orderToReturn),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accepted'), findsOneWidget);
    });

    testWidgets('10. PREPARING state renders preparing milestone',
        (tester) async {
      mockOrderRepository.orderToReturn =
          baseDeliveryOrder.copyWith(status: OrderStatus.preparing);

      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: mockOrderRepository.orderToReturn),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preparing'), findsAtLeastNWidgets(1));
    });

    testWidgets('11. READY state renders ready milestone', (tester) async {
      mockOrderRepository.orderToReturn =
          baseDeliveryOrder.copyWith(status: OrderStatus.ready);

      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: mockOrderRepository.orderToReturn),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ready'), findsOneWidget);
    });

    testWidgets('12. OUT_FOR_DELIVERY state renders out for delivery milestone',
        (tester) async {
      mockOrderRepository.orderToReturn =
          baseDeliveryOrder.copyWith(status: OrderStatus.outForDelivery);

      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: mockOrderRepository.orderToReturn),
      );
      await tester.pumpAndSettle();

      expect(find.text('Out for Delivery'), findsAtLeastNWidgets(1));
    });

    testWidgets('13. DELIVERED terminal state stops live updates banner',
        (tester) async {
      mockOrderRepository.orderToReturn =
          baseDeliveryOrder.copyWith(status: OrderStatus.delivered);

      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: mockOrderRepository.orderToReturn),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delivered'), findsAtLeastNWidgets(1));
      expect(find.text('Live Updates'), findsNothing);
    });

    testWidgets('14. REJECTED state displays rejection banner with reason',
        (tester) async {
      final rejectedOrder = baseDeliveryOrder.copyWith(
        status: OrderStatus.rejected,
        rejectedReason: 'Items requested are out of stock',
      );
      mockOrderRepository.orderToReturn = rejectedOrder;

      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: rejectedOrder),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracking_rejection_banner')), findsOneWidget);
      expect(find.text('Order Rejected'), findsOneWidget);
      expect(find.text('Items requested are out of stock'), findsOneWidget);
      expect(find.text('Live Updates'), findsNothing);
    });

    testWidgets('15. CANCELLED state displays cancellation banner',
        (tester) async {
      final cancelledOrder = baseDeliveryOrder.copyWith(
        status: OrderStatus.cancelled,
      );
      mockOrderRepository.orderToReturn = cancelledOrder;

      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: cancelledOrder),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracking_cancelled_banner')), findsOneWidget);
      expect(find.text('Order Cancelled'), findsOneWidget);
      expect(find.text('Live Updates'), findsNothing);
    });

    testWidgets('16. manual refresh button triggers getOrderById',
        (tester) async {
      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: baseDeliveryOrder),
      );
      await tester.pumpAndSettle();

      final initialCalls = mockOrderRepository.getOrderByIdCallCount;

      final refreshBtn = find.byKey(const Key('tracking_refresh_button'));
      expect(refreshBtn, findsOneWidget);

      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      expect(mockOrderRepository.getOrderByIdCallCount, equals(initialCalls + 1));
    });

    testWidgets('17. periodic polling updates active order status',
        (tester) async {
      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: baseDeliveryOrder),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending'), findsOneWidget);

      // Change repo return to OUT_FOR_DELIVERY and advance timer by 10 seconds
      mockOrderRepository.orderToReturn =
          baseDeliveryOrder.copyWith(status: OrderStatus.outForDelivery);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.text('Out for Delivery'), findsAtLeastNWidgets(1));
    });

    testWidgets('17b. background polling failure preserves current order and surfaces SnackBar',
        (tester) async {
      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: baseDeliveryOrder),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order #ESK-TRK-001'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);

      // Simulate a network failure during background poll
      mockOrderRepository.failureToReturn =
          const ServerFailure(message: 'Periodic network timeout');

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      // Verify currently displayed order is preserved on screen (not replaced with error state)
      expect(find.text('Order #ESK-TRK-001'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Unable to load order details'), findsNothing);

      // Verify non-destructive SnackBar is surfaced
      expect(find.textContaining('Failed to update tracking: Periodic network timeout'),
          findsOneWidget);
    });

    testWidgets('18. polling stops when order transitions to terminal DELIVERED state',
        (tester) async {
      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: baseDeliveryOrder),
      );
      await tester.pumpAndSettle();

      // Transition to DELIVERED
      mockOrderRepository.orderToReturn =
          baseDeliveryOrder.copyWith(status: OrderStatus.delivered);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      final callsAtDelivered = mockOrderRepository.getOrderByIdCallCount;

      // Advance by another 20 seconds; no additional polls should occur
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();

      expect(mockOrderRepository.getOrderByIdCallCount, equals(callsAtDelivered));
    });

    testWidgets('19. timer is cleanly disposed when widget is unmounted',
        (tester) async {
      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: baseDeliveryOrder),
      );
      await tester.pumpAndSettle();

      // Replace with empty container to trigger dispose()
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Disposed Screen'))),
      );
      await tester.pumpAndSettle();

      final callsAtDispose = mockOrderRepository.getOrderByIdCallCount;

      // Advance time by 30 seconds
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      expect(mockOrderRepository.getOrderByIdCallCount, equals(callsAtDispose));
    });

    testWidgets('20. OrderDetailsSheet Track Order button navigates to CustomerOrderTrackingScreen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_sheet_button'),
                onPressed: () {
                  OrderDetailsSheet.show(
                    context,
                    order: baseDeliveryOrder,
                    orderRepository: mockOrderRepository,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      final trackOrderBtn =
          find.byKey(const Key('order_details_track_order_button'));
      expect(trackOrderBtn, findsOneWidget);

      await tester.tap(trackOrderBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerOrderTrackingScreen), findsOneWidget);
      expect(find.text('Track Order'), findsOneWidget);
    });

    testWidgets('21. does NOT render GPS/map/ETA UI elements', (tester) async {
      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: baseDeliveryOrder),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ETA'), findsNothing);
      expect(find.textContaining('Estimated arrival'), findsNothing);
      expect(find.textContaining('Live GPS'), findsNothing);
      expect(find.byIcon(Icons.map), findsNothing);
    });

    testWidgets('22. does NOT render fake loyalty points', (tester) async {
      await tester.pumpWidget(
        buildTrackingScreen(initialOrder: baseDeliveryOrder),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('loyalty points'), findsNothing);
      expect(find.textContaining('points earned'), findsNothing);
    });
  });
}
