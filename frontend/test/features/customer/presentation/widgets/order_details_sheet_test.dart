import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/customer/cart/application/cart_notifier.dart';
import 'package:esouq/features/customer/domain/models/order_item_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/presentation/widgets/order_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_cart_repository.dart';
import '../../mocks/mock_order_repository.dart';

void main() {
  group('OrderDetailsSheet', () {
    late MockOrderRepository mockOrderRepository;

    setUp(() {
      mockOrderRepository = MockOrderRepository();
    });

    testWidgets('renders complete order breakdown, items, and pricing', (
      tester,
    ) async {
      final order = OrderModel(
        id: 'ord-12345678',
        orderNumber: 'ESK-2026-888',
        customerId: 'usr-1',
        storeId: 'store-1',
        storeName: 'eSOuQ Olaya Flagship',
        status: OrderStatus.ready,
        fulfillment: FulfillmentType.delivery,
        deliveryAddress: 'Building 12, King Fahd Rd',
        notes: 'Leave with reception',
        subtotal: 20.0,
        discount: 2.0,
        deliveryFee: 1.5,
        total: 19.5,
        pointsEarned: 10,
        items: const [
          OrderItemModel(
            itemId: 'prod-1',
            itemName: 'Fresh Whole Milk 1L',
            itemPrice: 5.0,
            quantity: 2,
            subtotal: 10.0,
          ),
          OrderItemModel(
            itemId: 'prod-2',
            itemName: 'Organic Bananas 1kg',
            itemPrice: 10.0,
            quantity: 1,
            subtotal: 10.0,
          ),
        ],
        createdAt: DateTime.parse('2026-09-15T15:00:00Z'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  OrderDetailsSheet.show(
                    context,
                    order: order,
                    orderRepository: mockOrderRepository,
                  );
                },
                child: const Text('Open Order Details'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Order Details'));
      await tester.pumpAndSettle();

      expect(find.text('Order #ESK-2026-888'), findsOneWidget);
      expect(find.text('eSOuQ Olaya Flagship'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Fulfillment Details'), findsOneWidget);
      expect(find.text('Building 12, King Fahd Rd'), findsOneWidget);
      expect(find.text('Notes: Leave with reception'), findsOneWidget);
      expect(find.text('Items (3)'), findsOneWidget);
      expect(find.text('2x Fresh Whole Milk 1L'), findsOneWidget);
      expect(find.text('1x Organic Bananas 1kg'), findsOneWidget);
      expect(find.text('20.00 SAR'), findsWidgets);
      expect(find.text('-2.00 SAR'), findsOneWidget);
      expect(find.text('1.50 SAR'), findsOneWidget);
      expect(find.text('19.50 SAR'), findsOneWidget);
      expect(find.text('+10 loyalty points earned'), findsOneWidget);
      expect(find.byKey(const Key('order_details_payment_method')), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
    });

    testWidgets('renders Cancel Order button for PENDING orders and prompts dialog', (
      tester,
    ) async {
      final pendingOrder = OrderModel(
        id: 'ord-pending-1',
        orderNumber: 'ESK-2026-999',
        customerId: 'usr-1',
        storeId: 'store-1',
        status: OrderStatus.pending,
        fulfillment: FulfillmentType.delivery,
        subtotal: 20.0,
        total: 20.0,
        items: const [
          OrderItemModel(
            itemId: 'prod-1',
            itemName: 'Milk',
            itemPrice: 10.0,
            quantity: 2,
            subtotal: 20.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  OrderDetailsSheet.show(
                    context,
                    order: pendingOrder,
                    orderRepository: mockOrderRepository,
                  );
                },
                child: const Text('Open Order Details'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Order Details'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('order_details_cancel_order_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('order_details_cancel_order_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('details_cancel_order_dialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('details_confirm_cancel_order_btn')));
      await tester.pumpAndSettle();

      expect(mockOrderRepository.cancelOrderCallCount, equals(1));
      expect(mockOrderRepository.lastOrderIdParam, equals('ord-pending-1'));
    });

    testWidgets('tapping Reorder adds items to cart without submitting order', (
      tester,
    ) async {
      final mockCartRepo = MockCartRepository();
      final cartNotifier = CartNotifier(cartRepository: mockCartRepo);

      final orderToReorder = OrderModel(
        id: 'ord-reorder-1',
        orderNumber: 'ESK-2026-REORDER',
        customerId: 'usr-1',
        storeId: 'store-1',
        status: OrderStatus.delivered,
        fulfillment: FulfillmentType.delivery,
        paymentMethod: PaymentMethod.card,
        subtotal: 15.0,
        total: 15.0,
        items: const [
          OrderItemModel(
            itemId: 'prod-1',
            itemName: 'Milk 1L',
            itemPrice: 5.0,
            quantity: 3,
            subtotal: 15.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  OrderDetailsSheet.show(
                    context,
                    order: orderToReorder,
                    orderRepository: mockOrderRepository,
                    cartNotifier: cartNotifier,
                  );
                },
                child: const Text('Open Order'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Order'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('order_details_payment_method')), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
      expect(find.byKey(const Key('order_details_reorder_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('order_details_reorder_button')));
      await tester.pumpAndSettle();

      expect(mockCartRepo.addItemCallCount, equals(1));
      expect(mockCartRepo.lastProductIdParam, equals('prod-1'));
      expect(mockCartRepo.lastQuantityParam, equals(3));
      expect(mockOrderRepository.createOrderCallCount, equals(0));
      expect(find.textContaining('added to cart from Order'), findsOneWidget);
    });

    testWidgets('renders Points Discount row when pointsDiscount and redeemedPoints are present', (
      tester,
    ) async {
      final orderWithPoints = OrderModel(
        id: 'ord-pts-1',
        orderNumber: 'ESK-PTS-100',
        customerId: 'usr-1',
        storeId: 'store-1',
        storeName: 'eSOuQ Olaya Flagship',
        status: OrderStatus.accepted,
        fulfillment: FulfillmentType.delivery,
        subtotal: 50.0,
        discount: 0.0,
        pointsDiscount: 5.0,
        redeemedPoints: 500,
        deliveryFee: 10.0,
        total: 55.0,
        pointsEarned: 25,
        items: const [
          OrderItemModel(
            itemId: 'prod-1',
            itemName: 'Fresh Milk 1L',
            itemPrice: 25.0,
            quantity: 2,
            subtotal: 50.0,
          ),
        ],
        createdAt: DateTime.parse('2026-09-15T15:00:00Z'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  OrderDetailsSheet.show(
                    context,
                    order: orderWithPoints,
                    orderRepository: mockOrderRepository,
                  );
                },
                child: const Text('Open Order'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Order'));
      await tester.pumpAndSettle();

      expect(find.text('Points Discount (500 pts)'), findsOneWidget);
      expect(find.text('-5.00 SAR'), findsOneWidget);
    });
  });
}
