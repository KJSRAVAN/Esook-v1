import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/customer/domain/models/order_item_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/presentation/widgets/order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderCard', () {
    testWidgets(
      'renders order details, status badge, and invokes onTap callback',
      (tester) async {
        bool wasTapped = false;
        final order = OrderModel(
          id: 'ord-12345678',
          orderNumber: 'ESK-2026-999',
          customerId: 'usr-1',
          storeId: 'store-1',
          storeName: 'eSOuQ Olaya Flagship',
          status: OrderStatus.preparing,
          fulfillment: FulfillmentType.delivery,
          subtotal: 12.50,
          total: 12.50,
          items: const [
            OrderItemModel(
              itemId: 'prod-1',
              itemName: 'Milk',
              itemPrice: 6.25,
              quantity: 2,
            ),
          ],
          createdAt: DateTime.parse('2026-09-15T14:30:00Z'),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: OrderCard(order: order, onTap: () => wasTapped = true),
            ),
          ),
        );

        expect(find.text('Order #ESK-2026-999'), findsOneWidget);
        expect(find.text('Preparing'), findsOneWidget);
        expect(find.text('eSOuQ Olaya Flagship'), findsOneWidget);
        expect(find.text('Delivery • 2 items'), findsOneWidget);
        expect(find.text('12.50 SAR'), findsOneWidget);

        await tester.tap(find.byType(OrderCard));
        expect(wasTapped, isTrue);
      },
    );
  });
}
