import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/customer/domain/models/order_item_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/presentation/widgets/order_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    });
  });
}
