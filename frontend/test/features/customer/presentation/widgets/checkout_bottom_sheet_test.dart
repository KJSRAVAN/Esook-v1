import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/cart/domain/cart_item_model.dart';
import 'package:esouq/features/customer/cart/domain/cart_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/domain/repositories/order_repository.dart';
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
      expect(find.byKey(const Key('checkout_coupon_input')), findsNothing);
      expect(find.text('Coupon Code (Optional)'), findsNothing);
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

    testWidgets('places delivery order with address and notes without coupon', (
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

      // Verify coupon input is absent from UI
      expect(find.byKey(const Key('checkout_coupon_input')), findsNothing);

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
      expect(mockOrderRepository.lastCouponCodeParam, isNull);
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
            required paymentMethod,
            deliveryAddress,
            couponCode,
            notes,
            required items,
            redeemPoints,
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

    testWidgets('allows selecting Card and passes CARD paymentMethod to repository', (
      tester,
    ) async {
      setupViewport(tester);
      await tester.pumpWidget(buildCheckoutHost());
      await tester.tap(find.text('Open Checkout'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment_method_cash_option')), findsOneWidget);
      expect(find.byKey(const Key('payment_method_card_option')), findsOneWidget);

      // Select Card option
      await tester.tap(find.byKey(const Key('payment_method_card_option')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('checkout_delivery_address_input')),
        'Building 10, King Fahd Rd',
      );

      await tester.tap(find.byKey(const Key('checkout_place_order_button')));
      await tester.pumpAndSettle();

      expect(mockOrderRepository.createOrderCallCount, equals(1));
      expect(mockOrderRepository.lastPaymentMethodParam, equals(PaymentMethod.card));
    });

    testWidgets(
      'displays loyalty points redemption card and applies points discount when toggled',
      (tester) async {
        setupViewport(tester);
        // Configure mock repository with available points
        mockOrderRepository.pointsInfoToReturn = const CustomerPointsInfo(
          isEnabled: true,
          pointsPerCurrencyUnit: 0.10,
          balance: 20, // 20 points * 0.10 = 2.00 currency discount
        );

        await tester.pumpWidget(buildCheckoutHost());
        await tester.tap(find.text('Open Checkout'));
        await tester.pumpAndSettle();

        // Verify points card is displayed
        expect(find.byKey(const Key('checkout_loyalty_points_card')), findsOneWidget);
        expect(find.text('Redeem Loyalty Points'), findsOneWidget);
        expect(find.text('Available: 20 pts (worth 2.00 SAR)'), findsOneWidget);

        // Before toggle: Points Discount row should not be shown
        expect(find.text('Points Discount'), findsNothing);

        // Toggle points ON
        await tester.tap(find.byKey(const Key('checkout_use_points_switch')));
        await tester.pumpAndSettle();

        // After toggle: Points Discount row and redeeming summary appear
        expect(find.text('Redeeming 20 pts (-2.00 SAR)'), findsOneWidget);
        expect(find.text('Points Discount'), findsOneWidget);
        expect(find.text('-2.00 SAR'), findsOneWidget);

        // Fill delivery address and submit
        await tester.enterText(
          find.byKey(const Key('checkout_delivery_address_input')),
          'Building 10, King Fahd Rd',
        );

        await tester.tap(find.byKey(const Key('checkout_place_order_button')));
        await tester.pumpAndSettle();

        expect(mockOrderRepository.createOrderCallCount, equals(1));
        expect(mockOrderRepository.lastRedeemPointsParam, equals(20));
      },
    );

    testWidgets(
      'does not pass redeemPoints when loyalty points switch is OFF',
      (tester) async {
        setupViewport(tester);
        mockOrderRepository.pointsInfoToReturn = const CustomerPointsInfo(
          isEnabled: true,
          pointsPerCurrencyUnit: 0.10,
          balance: 50,
        );

        await tester.pumpWidget(buildCheckoutHost());
        await tester.tap(find.text('Open Checkout'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('checkout_loyalty_points_card')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('checkout_delivery_address_input')),
          'Building 10, King Fahd Rd',
        );

        await tester.tap(find.byKey(const Key('checkout_place_order_button')));
        await tester.pumpAndSettle();

        expect(mockOrderRepository.createOrderCallCount, equals(1));
        expect(mockOrderRepository.lastRedeemPointsParam, isNull);
      },
    );

    testWidgets(
      'displays disabled message when store loyalty is disabled',
      (tester) async {
        setupViewport(tester);
        mockOrderRepository.pointsInfoToReturn = const CustomerPointsInfo(
          isEnabled: false,
          balance: 100,
        );

        await tester.pumpWidget(buildCheckoutHost());
        await tester.tap(find.text('Open Checkout'));
        await tester.pumpAndSettle();

        expect(
          find.text('Loyalty points redemption is disabled for this store.'),
          findsOneWidget,
        );

        final switchFinder = find.byKey(const Key('checkout_use_points_switch'));
        expect(switchFinder, findsOneWidget);
        final switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.onChanged, isNull);
      },
    );

    testWidgets(
      'displays 0 points message when customer has no points balance',
      (tester) async {
        setupViewport(tester);
        mockOrderRepository.pointsInfoToReturn = const CustomerPointsInfo(
          isEnabled: true,
          balance: 0,
        );

        await tester.pumpWidget(buildCheckoutHost());
        await tester.tap(find.text('Open Checkout'));
        await tester.pumpAndSettle();

        expect(
          find.text('0 loyalty points available. Earn points on orders.'),
          findsOneWidget,
        );

        final switchFinder = find.byKey(const Key('checkout_use_points_switch'));
        final switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.onChanged, isNull);
      },
    );

    testWidgets(
      'displays minimum threshold message when points balance is below minPointsToRedeem',
      (tester) async {
        setupViewport(tester);
        mockOrderRepository.pointsInfoToReturn = const CustomerPointsInfo(
          isEnabled: true,
          balance: 30,
          minPointsToRedeem: 50,
        );

        await tester.pumpWidget(buildCheckoutHost());
        await tester.tap(find.text('Open Checkout'));
        await tester.pumpAndSettle();

        expect(
          find.text('30 pts available (Min 50 required to redeem)'),
          findsOneWidget,
        );

        final switchFinder = find.byKey(const Key('checkout_use_points_switch'));
        final switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.onChanged, isNull);
      },
    );

    testWidgets(
      'uses explicit storeId passed to CheckoutBottomSheet',
      (tester) async {
        setupViewport(tester);
        mockOrderRepository.pointsInfoToReturn = const CustomerPointsInfo(
          isEnabled: true,
          balance: 200,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    CheckoutBottomSheet.show(
                      context,
                      cart: testCart,
                      storeId: 'store-esook-local-1',
                      storeName: 'Fresh Mart Riyadh',
                      orderRepository: mockOrderRepository,
                    );
                  },
                  child: const Text('Open Custom Checkout'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open Custom Checkout'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('checkout_delivery_address_input')),
          'King Fahd Rd, Riyadh',
        );
        await tester.tap(find.byKey(const Key('checkout_place_order_button')));
        await tester.pumpAndSettle();

        expect(mockOrderRepository.lastStoreIdParam, equals('store-esook-local-1'));
      },
    );

    testWidgets(
      'displays conversion rate and allows customer to enter custom points to redeem',
      (tester) async {
        setupViewport(tester);
        mockOrderRepository.pointsInfoToReturn = const CustomerPointsInfo(
          isEnabled: true,
          pointsPerCurrencyUnit: 0.10, // 10 pts = 1 SAR
          balance: 30, // 30 pts * 0.10 = 3.00 SAR <= subtotal 3.35
        );

        await tester.pumpWidget(buildCheckoutHost());
        await tester.tap(find.text('Open Checkout'));
        await tester.pumpAndSettle();

        // Verify conversion rate is displayed
        expect(find.text('Rate: 10 pts = 1 SAR (0.10 SAR/pt)'), findsOneWidget);
        expect(find.text('Available: 30 pts (worth 3.00 SAR)'), findsOneWidget);

        // Toggle points ON
        await tester.tap(find.byKey(const Key('checkout_use_points_switch')));
        await tester.pumpAndSettle();

        // Default: redeems eligible points (30 pts = 3.00 SAR)
        expect(find.text('Redeeming 30 pts (-3.00 SAR)'), findsOneWidget);

        // Enter custom points: 15 pts (worth 1.50 SAR)
        final pointsInput = find.byKey(const Key('checkout_points_input'));
        expect(pointsInput, findsOneWidget);
        await tester.enterText(pointsInput, '15');
        await tester.pumpAndSettle();

        // Verify updated discount
        expect(find.text('Redeeming 15 pts (-1.50 SAR)'), findsOneWidget);
        expect(find.text('-1.50 SAR'), findsOneWidget);

        // Place order and verify custom points passed
        await tester.enterText(
          find.byKey(const Key('checkout_delivery_address_input')),
          'Olaya St, Riyadh',
        );
        await tester.tap(find.byKey(const Key('checkout_place_order_button')));
        await tester.pumpAndSettle();

        expect(mockOrderRepository.lastRedeemPointsParam, equals(15));
      },
    );
  });
}
