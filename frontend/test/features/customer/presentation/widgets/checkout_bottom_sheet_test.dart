import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/cart/domain/cart_item_model.dart';
import 'package:esouq/features/customer/cart/domain/cart_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/presentation/widgets/checkout_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_order_repository.dart';

void main() {
  group('CheckoutBottomSheet', () {
    late MockOrderRepository mockOrderRepository;
    late CartModel testCart;

    setUp(() {
      mockOrderRepository = MockOrderRepository();
      testCart = const CartModel(
        userId: 'usr-123',
        storeId: 'store-1',
        store: CartStoreRef(id: 'store-1', name: 'eSOuQ Olaya Flagship'),
        items: [
          CartItemModel(
            itemId: 'prod-1',
            name: 'Fresh Whole Milk 1L',
            price: 1.25,
            quantity: 2,
          ),
          CartItemModel(
            itemId: 'prod-2',
            name: 'Organic Bananas 1kg',
            price: 0.85,
            quantity: 1,
          ),
        ],
        subtotal: 3.35,
      );
    });

    Widget buildCheckoutHost({ValueChanged<OrderModel>? onOrderSuccess}) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                CheckoutBottomSheet.show(
                  context,
                  cart: testCart,
                  storeName: 'eSOuQ Olaya Flagship',
                  orderRepository: mockOrderRepository,
                  onOrderSuccess: onOrderSuccess,
                );
              },
              child: const Text('Open Checkout'),
            ),
          ),
        ),
      );
    }

    void setupViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
    }

    testWidgets('renders checkout summary, fulfillment options, and fields', (
      tester,
    ) async {
      setupViewport(tester);
      await tester.pumpWidget(buildCheckoutHost());
      await tester.tap(find.text('Open Checkout'));
      await tester.pumpAndSettle();

      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('eSOuQ Olaya Flagship'), findsOneWidget);
      expect(find.text('Fulfillment Method'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget);
      expect(
        find.byKey(const Key('checkout_delivery_address_input')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('checkout_notes_input')), findsOneWidget);
      expect(find.byKey(const Key('checkout_coupon_input')), findsOneWidget);
      expect(find.text('Order Summary (3 items)'), findsOneWidget);
      expect(find.text('2x Fresh Whole Milk 1L'), findsOneWidget);
      expect(find.text('1x Organic Bananas 1kg'), findsOneWidget);
      expect(
        find.byKey(const Key('checkout_place_order_button')),
        findsOneWidget,
      );
    });

    testWidgets(
      'validates that delivery address is required when fulfillment is Delivery',
      (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(buildCheckoutHost());
        await tester.tap(find.text('Open Checkout'));
        await tester.pumpAndSettle();

        // Tap Place Order without entering address
        await tester.tap(find.byKey(const Key('checkout_place_order_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Delivery address is required for delivery orders'),
          findsOneWidget,
        );
        expect(mockOrderRepository.createOrderCallCount, equals(0));
      },
    );

    testWidgets(
      'allows placing order without delivery address when Pickup is selected',
      (tester) async {
        setupViewport(tester);
        OrderModel? placedOrder;
        await tester.pumpWidget(
          buildCheckoutHost(onOrderSuccess: (order) => placedOrder = order),
        );
        await tester.tap(find.text('Open Checkout'));
        await tester.pumpAndSettle();

        // Switch to Pickup
        await tester.tap(find.byKey(const Key('fulfillment_pickup_option')));
        await tester.pumpAndSettle();

        // Delivery address field should no longer be visible
        expect(
          find.byKey(const Key('checkout_delivery_address_input')),
          findsNothing,
        );

        // Tap Place Order
        await tester.tap(find.byKey(const Key('checkout_place_order_button')));
        await tester.pumpAndSettle();

        expect(mockOrderRepository.createOrderCallCount, equals(1));
        expect(
          mockOrderRepository.lastFulfillmentParam,
          equals(FulfillmentType.pickup),
        );
        expect(mockOrderRepository.lastDeliveryAddressParam, isNull);
        expect(mockOrderRepository.lastItemsParam?.length, equals(2));
        expect(placedOrder, isNotNull);
      },
    );

    testWidgets('places delivery order with address, notes, and coupon code', (
      tester,
    ) async {
      setupViewport(tester);
      OrderModel? placedOrder;
      await tester.pumpWidget(
        buildCheckoutHost(onOrderSuccess: (order) => placedOrder = order),
      );
      await tester.tap(find.text('Open Checkout'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('checkout_delivery_address_input')),
        'Building 10, King Fahd Rd',
      );
      await tester.enterText(
        find.byKey(const Key('checkout_notes_input')),
        'Please call on arrival',
      );
      await tester.enterText(
        find.byKey(const Key('checkout_coupon_input')),
        'SAVE10',
      );

      await tester.tap(find.byKey(const Key('checkout_place_order_button')));
      await tester.pumpAndSettle();

      expect(mockOrderRepository.createOrderCallCount, equals(1));
      expect(mockOrderRepository.lastStoreIdParam, equals('store-1'));
      expect(
        mockOrderRepository.lastFulfillmentParam,
        equals(FulfillmentType.delivery),
      );
      expect(
        mockOrderRepository.lastDeliveryAddressParam,
        equals('Building 10, King Fahd Rd'),
      );
      expect(
        mockOrderRepository.lastNotesParam,
        equals('Please call on arrival'),
      );
      expect(mockOrderRepository.lastCouponCodeParam, equals('SAVE10'));
      expect(mockOrderRepository.lastIdempotencyKeyParam, isNotNull);
      expect(
        mockOrderRepository.lastIdempotencyKeyParam!.length,
        greaterThan(10),
      );
      expect(placedOrder, isNotNull);
    });

    testWidgets('displays error banner when order creation fails', (
      tester,
    ) async {
      setupViewport(tester);
      mockOrderRepository.failureToReturn = const ValidationFailure(
        message: 'Selected store is currently not accepting orders',
      );

      await tester.pumpWidget(buildCheckoutHost());
      await tester.tap(find.text('Open Checkout'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('checkout_delivery_address_input')),
        'Building 10, King Fahd Rd',
      );

      await tester.tap(find.byKey(const Key('checkout_place_order_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('checkout_error_banner')), findsOneWidget);
      expect(
        find.text('Selected store is currently not accepting orders'),
        findsOneWidget,
      );
    });

    testWidgets('prevents duplicate submissions from rapid repeated taps', (
      tester,
    ) async {
      setupViewport(tester);
      // Simulate an async delay in createOrder
      mockOrderRepository.customCreateOrderHandler =
          ({
            required storeId,
            required fulfillment,
            deliveryAddress,
            couponCode,
            notes,
            required items,
            idempotencyKey,
          }) async {
            await Future.delayed(const Duration(milliseconds: 100));
            return Result.success(mockOrderRepository.defaultOrder);
          };

      await tester.pumpWidget(buildCheckoutHost());
      await tester.tap(find.text('Open Checkout'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('checkout_delivery_address_input')),
        'Building 10, King Fahd Rd',
      );

      // Tap Place Order button twice rapidly
      await tester.tap(find.byKey(const Key('checkout_place_order_button')));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byKey(const Key('checkout_place_order_button')));
      await tester.pumpAndSettle();

      // Only one submission should have gone through
      expect(mockOrderRepository.createOrderCallCount, equals(1));
    });
  });
}
