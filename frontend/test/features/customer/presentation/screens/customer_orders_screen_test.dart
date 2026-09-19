import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/customer/domain/models/order_item_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/presentation/screens/customer_orders_screen.dart';
import 'package:esouq/features/customer/presentation/widgets/order_card.dart';
import 'package:esouq/features/customer/presentation/widgets/order_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_order_repository.dart';

void main() {
  group('CustomerOrdersScreen', () {
    late MockOrderRepository mockOrderRepository;

    setUp(() {
      mockOrderRepository = MockOrderRepository();
    });

    Widget buildOrdersScreen() {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: CustomerOrdersScreen(orderRepository: mockOrderRepository),
      );
    }

    testWidgets('displays empty state when customer has no orders', (
      tester,
    ) async {
      mockOrderRepository.ordersToReturn = [];

      await tester.pumpWidget(buildOrdersScreen());
      await tester.pumpAndSettle();

      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('No Orders Yet'), findsOneWidget);
      expect(
        find.text(
          'Track active deliveries and view past grocery order history here.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    });

    testWidgets('displays error state with retry button on failure', (
      tester,
    ) async {
      mockOrderRepository.failureToReturn = const ServerFailure(
        message: 'Could not load orders',
      );

      await tester.pumpWidget(buildOrdersScreen());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load orders'), findsOneWidget);
      expect(find.text('Could not load orders'), findsOneWidget);
      expect(
        find.byKey(const Key('orders_error_retry_button')),
        findsOneWidget,
      );

      // Now set success and tap Retry
      mockOrderRepository.failureToReturn = null;
      mockOrderRepository.ordersToReturn = [mockOrderRepository.defaultOrder];

      await tester.tap(find.byKey(const Key('orders_error_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byType(OrderCard), findsOneWidget);
      expect(find.text('Unable to load orders'), findsNothing);
    });

    testWidgets('displays list of orders when orders are loaded', (
      tester,
    ) async {
      final order1 = OrderModel(
        id: 'ord-001',
        orderNumber: 'ESK-001',
        customerId: 'usr-1',
        storeId: 'store-1',
        storeName: 'eSOuQ Olaya Flagship',
        status: OrderStatus.preparing,
        fulfillment: FulfillmentType.delivery,
        deliveryAddress: 'Building 4B',
        subtotal: 25.0,
        total: 25.0,
        items: const [
          OrderItemModel(
            itemId: 'prod-1',
            itemName: 'Milk',
            itemPrice: 5.0,
            quantity: 5,
            subtotal: 25.0,
          ),
        ],
      );

      final order2 = OrderModel(
        id: 'ord-002',
        orderNumber: 'ESK-002',
        customerId: 'usr-1',
        storeId: 'store-2',
        storeName: 'eSOuQ Al Malqa',
        status: OrderStatus.delivered,
        fulfillment: FulfillmentType.pickup,
        subtotal: 10.0,
        total: 10.0,
        items: const [],
      );

      mockOrderRepository.ordersToReturn = [order1, order2];

      await tester.pumpWidget(buildOrdersScreen());
      await tester.pumpAndSettle();

      expect(find.byType(OrderCard), findsNWidgets(2));
      expect(find.text('Order #ESK-001'), findsOneWidget);
      expect(find.text('Order #ESK-002'), findsOneWidget);
      expect(find.text('Preparing'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
    });

    testWidgets('tapping order card opens OrderDetailsSheet', (tester) async {
      mockOrderRepository.ordersToReturn = [mockOrderRepository.defaultOrder];

      await tester.pumpWidget(buildOrdersScreen());
      await tester.pumpAndSettle();

      expect(find.byType(OrderCard), findsOneWidget);

      await tester.tap(find.byType(OrderCard));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailsSheet), findsOneWidget);
      expect(find.text('Fulfillment Details'), findsOneWidget);
      expect(find.text('Building 4B, King Fahd Rd, Riyadh'), findsOneWidget);
    });

    testWidgets('refresh button triggers reload of orders', (tester) async {
      mockOrderRepository.ordersToReturn = [mockOrderRepository.defaultOrder];

      await tester.pumpWidget(buildOrdersScreen());
      await tester.pumpAndSettle();

      final initialCalls = mockOrderRepository.getMyOrdersCallCount;

      await tester.tap(find.byKey(const Key('orders_refresh_button')));
      await tester.pumpAndSettle();

      expect(
        mockOrderRepository.getMyOrdersCallCount,
        equals(initialCalls + 1),
      );
    });

    testWidgets('pull-to-refresh gesture reloads orders from repository', (
      tester,
    ) async {
      mockOrderRepository.ordersToReturn = [mockOrderRepository.defaultOrder];

      await tester.pumpWidget(buildOrdersScreen());
      await tester.pumpAndSettle();

      final initialCalls = mockOrderRepository.getMyOrdersCallCount;

      // Perform a pull-down drag on the ListView to trigger RefreshIndicator
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(
        mockOrderRepository.getMyOrdersCallCount,
        equals(initialCalls + 1),
      );
    });

    testWidgets('refreshSignal triggers reload of orders when notified', (
      tester,
    ) async {
      final refreshNotifier = ValueNotifier<int>(0);
      mockOrderRepository.ordersToReturn = [];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CustomerOrdersScreen(
            orderRepository: mockOrderRepository,
            refreshSignal: refreshNotifier,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Orders Yet'), findsOneWidget);
      expect(mockOrderRepository.getMyOrdersCallCount, equals(1));

      // Simulate order placed notification
      mockOrderRepository.ordersToReturn = [mockOrderRepository.defaultOrder];
      refreshNotifier.value++;
      await tester.pumpAndSettle();

      expect(mockOrderRepository.getMyOrdersCallCount, equals(2));
      expect(find.byType(OrderCard), findsOneWidget);
      expect(find.text('No Orders Yet'), findsNothing);

      refreshNotifier.dispose();
    });

    testWidgets(
      'ordinary widget rebuilds do not trigger duplicate orders reloads',
      (tester) async {
        final refreshNotifier = ValueNotifier<int>(0);
        mockOrderRepository.ordersToReturn = [mockOrderRepository.defaultOrder];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: CustomerOrdersScreen(
              orderRepository: mockOrderRepository,
              refreshSignal: refreshNotifier,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(mockOrderRepository.getMyOrdersCallCount, equals(1));

        // Rebuild the widget with same state
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: CustomerOrdersScreen(
              orderRepository: mockOrderRepository,
              refreshSignal: refreshNotifier,
            ),
          ),
        );
        await tester.pump();

        // Must still be 1 call, not repeated/unbounded
        expect(mockOrderRepository.getMyOrdersCallCount, equals(1));

        refreshNotifier.dispose();
      },
    );
  });
}
