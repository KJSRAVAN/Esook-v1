import 'package:esouq/core/constants/app_constants.dart';
import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/customer/cart/application/cart_notifier.dart';
import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:esouq/features/customer/presentation/widgets/product_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_cart_repository.dart';

void main() {
  const testProduct = ProductModel(
    id: 'prod-detail-1',
    storeId: 'store-1',
    name: 'Organic Whole Milk 1L',
    description: 'Fresh organic pasture-raised cow milk with rich flavor.',
    price: 3.50,
    category: 'Dairy & Eggs',
    imageUrl: 'https://example.com/milk.png',
    isAvailable: true,
    loyaltyPointsPerUnit: 10,
  );

  const minimalProduct = ProductModel(
    id: 'prod-detail-minimal',
    storeId: 'store-1',
    name: 'Plain Bread',
    price: 1.00,
    isAvailable: true,
  );

  const unavailableProduct = ProductModel(
    id: 'prod-detail-out-of-stock',
    storeId: 'store-1',
    name: 'Seasonal Berries',
    description: 'Out of season wild berries.',
    price: 4.99,
    category: 'Fresh Fruits',
    isAvailable: false,
  );

  Widget buildTestWidget({
    required ProductModel product,
    CartNotifier? cartNotifier,
    String currency = AppConstants.defaultCurrency,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                key: const Key('open_sheet_button'),
                onPressed: () {
                  ProductDetailSheet.show(
                    context,
                    product: product,
                    cartNotifier: cartNotifier,
                    currency: currency,
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
  }

  group('ProductDetailSheet', () {
    testWidgets('renders product name, price, category, description, and points', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(product: testProduct));

      // Open sheet
      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('product_detail_sheet')), findsOneWidget);
      expect(find.text('Organic Whole Milk 1L'), findsOneWidget);
      expect(find.text('3.50 ${AppConstants.defaultCurrency}'), findsOneWidget);
      expect(find.text('Dairy & Eggs'), findsOneWidget);
      expect(find.text('In Stock'), findsOneWidget);
      expect(find.text('+10 pts'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(
        find.text('Fresh organic pasture-raised cow milk with rich flavor.'),
        findsOneWidget,
      );
    });

    testWidgets('renders custom currency correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(product: testProduct, currency: 'SAR'),
      );

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      expect(find.text('3.50 SAR'), findsOneWidget);
    });

    testWidgets('handles minimal product without description or category gracefully', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(product: minimalProduct));

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('product_detail_sheet')), findsOneWidget);
      expect(find.text('Plain Bread'), findsOneWidget);
      expect(find.text('1.00 ${AppConstants.defaultCurrency}'), findsOneWidget);
      expect(find.text('Description'), findsNothing);
      expect(find.byIcon(Icons.shopping_basket_outlined), findsOneWidget);
    });

    testWidgets('displays out-of-stock state and disables adding for unavailable product', (
      tester,
    ) async {
      final mockRepo = MockCartRepository();
      final notifier = CartNotifier(cartRepository: mockRepo);
      await notifier.loadForStore('store-1');

      await tester.pumpWidget(
        buildTestWidget(product: unavailableProduct, cartNotifier: notifier),
      );

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail_out_of_stock_badge')), findsOneWidget);
      expect(find.text('Out of Stock'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);

      final unavailableBtnFinder = find.byKey(
        const Key('detail_unavailable_button'),
      );
      expect(unavailableBtnFinder, findsOneWidget);
      expect(find.text('Currently Unavailable'), findsOneWidget);

      // Verify button cannot be tapped / does not call repository
      final btn = tester.widget<ElevatedButton>(unavailableBtnFinder);
      expect(btn.onPressed, isNull);
      expect(mockRepo.addItemCallCount, equals(0));
    });

    testWidgets('allows adding available product to cart via CartNotifier', (
      tester,
    ) async {
      final mockRepo = MockCartRepository();
      final notifier = CartNotifier(cartRepository: mockRepo);
      await notifier.loadForStore('store-1');

      await tester.pumpWidget(
        buildTestWidget(product: testProduct, cartNotifier: notifier),
      );

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      final addBtnFinder = find.byKey(const Key('detail_add_to_cart_button'));
      expect(addBtnFinder, findsOneWidget);
      expect(
        find.text('Add to Cart — 3.50 ${AppConstants.defaultCurrency}'),
        findsOneWidget,
      );

      await tester.tap(addBtnFinder);
      await tester.pumpAndSettle();

      expect(mockRepo.addItemCallCount, equals(1));
      expect(mockRepo.lastProductIdParam, equals('prod-detail-1'));
      expect(mockRepo.lastQuantityParam, equals(1));

      // SnackBar feedback
      expect(find.text('Added "Organic Whole Milk 1L" to cart'), findsOneWidget);
    });

    testWidgets('shows quantity stepper when product is already in cart', (
      tester,
    ) async {
      final mockRepo = MockCartRepository();
      final notifier = CartNotifier(cartRepository: mockRepo);
      // store-1 default cart includes 'prod-1' with quantity 2
      await notifier.loadForStore('store-1');

      const inCartProduct = ProductModel(
        id: 'prod-1',
        storeId: 'store-1',
        name: 'Fresh Whole Milk 1L',
        price: 1.25,
        isAvailable: true,
      );

      await tester.pumpWidget(
        buildTestWidget(product: inCartProduct, cartNotifier: notifier),
      );

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail_add_to_cart_button')), findsNothing);
      expect(find.text('In Cart'), findsOneWidget);
      expect(find.text('2.50 ${AppConstants.defaultCurrency}'), findsOneWidget);
      expect(find.byKey(const Key('detail_cart_quantity')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Tap increment
      await tester.tap(find.byKey(const Key('detail_cart_increment')));
      await tester.pumpAndSettle();

      expect(mockRepo.setItemQuantityCallCount, equals(1));
      expect(mockRepo.lastProductIdParam, equals('prod-1'));
      expect(mockRepo.lastQuantityParam, equals(3));

      // Tap decrement
      await tester.tap(find.byKey(const Key('detail_cart_decrement')));
      await tester.pumpAndSettle();

      expect(mockRepo.setItemQuantityCallCount, equals(2));
      expect(mockRepo.lastQuantityParam, equals(1));
    });

    testWidgets('closes cleanly when close button is tapped', (tester) async {
      await tester.pumpWidget(buildTestWidget(product: testProduct));

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('product_detail_sheet')), findsOneWidget);

      await tester.tap(find.byKey(const Key('detail_close_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('product_detail_sheet')), findsNothing);
      expect(find.byKey(const Key('open_sheet_button')), findsOneWidget);
    });

    testWidgets(
      'renders discount badge on top-left and points badge on top-right without overlapping',
      (tester) async {
        const offerWithPoints = ProductModel(
          id: 'prod-offer-detail',
          storeId: 'store-1',
          name: 'Special Honey',
          price: 50.0,
          offerPrice: 35.0, // 30% off
          isAvailable: true,
          loyaltyPointsPerUnit: 25,
        );

        await tester.pumpWidget(buildTestWidget(product: offerWithPoints));

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        final discountFinder = find.text('-30%').first;
        final pointsFinder = find.text('+25 pts');

        expect(discountFinder, findsOneWidget);
        expect(pointsFinder, findsOneWidget);

        final discountRect = tester.getRect(discountFinder);
        final pointsRect = tester.getRect(pointsFinder);

        expect(discountRect.right, lessThan(pointsRect.left));
        expect(discountRect.overlaps(pointsRect), isFalse);
      },
    );

    testWidgets(
      'allows selecting quantity > 1 with dynamic price updates and auto-closes on success',
      (tester) async {
        final mockRepo = MockCartRepository();
        final notifier = CartNotifier(cartRepository: mockRepo);
        await notifier.loadForStore('store-1');

        await tester.pumpWidget(
          buildTestWidget(product: testProduct, cartNotifier: notifier),
        );

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('product_detail_sheet')), findsOneWidget);
        expect(find.byKey(const Key('detail_selected_quantity')), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(
          find.text('Add to Cart — 3.50 ${AppConstants.defaultCurrency}'),
          findsOneWidget,
        );

        // Tap increment button twice: 1 -> 2 -> 3
        await tester.tap(find.byKey(const Key('detail_quantity_increment')));
        await tester.pumpAndSettle();
        expect(find.text('2'), findsOneWidget);
        expect(
          find.text('Add to Cart — 7.00 ${AppConstants.defaultCurrency}'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('detail_quantity_increment')));
        await tester.pumpAndSettle();
        expect(find.text('3'), findsOneWidget);
        expect(
          find.text('Add to Cart — 10.50 ${AppConstants.defaultCurrency}'),
          findsOneWidget,
        );

        // Tap decrement button once: 3 -> 2
        await tester.tap(find.byKey(const Key('detail_quantity_decrement')));
        await tester.pumpAndSettle();
        expect(find.text('2'), findsOneWidget);
        expect(
          find.text('Add to Cart — 7.00 ${AppConstants.defaultCurrency}'),
          findsOneWidget,
        );

        // Tap Add to Cart
        await tester.tap(find.byKey(const Key('detail_add_to_cart_button')));
        await tester.pumpAndSettle();

        expect(mockRepo.addItemCallCount, equals(1));
        expect(mockRepo.lastProductIdParam, equals('prod-detail-1'));
        expect(mockRepo.lastQuantityParam, equals(2));

        // SnackBar feedback
        expect(
          find.text('Added 2 x "Organic Whole Milk 1L" to cart'),
          findsOneWidget,
        );

        // Sheet automatically closed
        expect(find.byKey(const Key('product_detail_sheet')), findsNothing);
      },
    );

    testWidgets(
      'quantity decrement is disabled at minimum quantity 1',
      (tester) async {
        final mockRepo = MockCartRepository();
        final notifier = CartNotifier(cartRepository: mockRepo);
        await notifier.loadForStore('store-1');

        await tester.pumpWidget(
          buildTestWidget(product: testProduct, cartNotifier: notifier),
        );

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        final decrBtnFinder = find.byKey(const Key('detail_quantity_decrement'));
        expect(decrBtnFinder, findsOneWidget);

        final decrBtn = tester.widget<IconButton>(decrBtnFinder);
        expect(decrBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'calculates total price respecting promotional offer price',
      (tester) async {
        final mockRepo = MockCartRepository();
        final notifier = CartNotifier(cartRepository: mockRepo);
        await notifier.loadForStore('store-1');

        const offerProduct = ProductModel(
          id: 'prod-offer-calc',
          storeId: 'store-1',
          name: 'Premium Olive Oil',
          price: 50.0,
          offerPrice: 35.0,
          isAvailable: true,
        );

        await tester.pumpWidget(
          buildTestWidget(product: offerProduct, cartNotifier: notifier),
        );

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Add to Cart — 35.00 ${AppConstants.defaultCurrency}'),
          findsOneWidget,
        );

        // Increment to 3 units: 3 x 35.00 = 105.00
        await tester.tap(find.byKey(const Key('detail_quantity_increment')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('detail_quantity_increment')));
        await tester.pumpAndSettle();

        expect(
          find.text('Add to Cart — 105.00 ${AppConstants.defaultCurrency}'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'keeps sheet open and shows error when adding to cart fails',
      (tester) async {
        final mockRepo = MockCartRepository();
        mockRepo.failureToReturn = const ServerFailure(
          message: 'Failed to add item. Inventory unavailable.',
        );
        final notifier = CartNotifier(cartRepository: mockRepo);
        await notifier.loadForStore('store-1');

        await tester.pumpWidget(
          buildTestWidget(product: testProduct, cartNotifier: notifier),
        );

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('product_detail_sheet')), findsOneWidget);

        await tester.tap(find.byKey(const Key('detail_add_to_cart_button')));
        await tester.pumpAndSettle();

        expect(mockRepo.addItemCallCount, equals(1));

        // Error message displayed
        expect(
          find.text('Failed to add item. Inventory unavailable.'),
          findsOneWidget,
        );

        // Sheet MUST REMAIN OPEN on error
        expect(find.byKey(const Key('product_detail_sheet')), findsOneWidget);
      },
    );
  });
}
