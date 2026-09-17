import 'package:esouq/core/constants/app_constants.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/customer/cart/application/cart_notifier.dart';
import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:esouq/features/customer/presentation/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_cart_repository.dart';

void main() {
  const testProduct = ProductModel(
    id: 'prod-1',
    storeId: 'store-1',
    name: 'Fresh Whole Milk 1L',
    description: 'Fresh local cow milk',
    price: 1.25,
    category: 'Dairy & Eggs',
    isAvailable: true,
    loyaltyPointsPerUnit: 5,
  );

  const unavailableProduct = ProductModel(
    id: 'prod-unavailable',
    storeId: 'store-1',
    name: 'Out of Stock Yogurt',
    price: 2.00,
    isAvailable: false,
    loyaltyPointsPerUnit: 0,
  );

  testWidgets('ProductCard renders default currency from AppConstants', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: ProductCard(product: testProduct),
        ),
      ),
    );

    expect(find.text('Fresh Whole Milk 1L'), findsOneWidget);
    expect(find.text('1.25 ${AppConstants.defaultCurrency}'), findsOneWidget);
    expect(find.text('+5 pts'), findsOneWidget);
  });

  testWidgets('ProductCard renders custom currency when provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: ProductCard(
            product: testProduct,
            currency: 'AED',
          ),
        ),
      ),
    );

    expect(find.text('1.25 AED'), findsOneWidget);
  });

  testWidgets('ProductCard shows Add button and calls CartNotifier.addItem when tapped', (tester) async {
    final mockRepo = MockCartRepository();
    final notifier = CartNotifier(cartRepository: mockRepo);
    await notifier.loadForStore('store-1');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ProductCard(
            product: const ProductModel(
              id: 'prod-new',
              storeId: 'store-1',
              name: 'Fresh Apples 1kg',
              price: 1.50,
              isAvailable: true,
              loyaltyPointsPerUnit: 2,
            ),
            cartNotifier: notifier,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('add_to_cart_prod-new')), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_to_cart_prod-new')));
    await tester.pumpAndSettle();

    expect(mockRepo.addItemCallCount, equals(1));
    expect(mockRepo.lastProductIdParam, equals('prod-new'));
  });

  testWidgets('ProductCard shows stepper when item is already in cart', (tester) async {
    final mockRepo = MockCartRepository();
    final notifier = CartNotifier(cartRepository: mockRepo);
    await notifier.loadForStore('store-1'); // default cart has prod-1 with qty 2

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ProductCard(
            product: testProduct,
            cartNotifier: notifier,
          ),
        ),
      ),
    );

    expect(find.text('2'), findsOneWidget);
    expect(find.byKey(const Key('cart_increment_prod-1')), findsOneWidget);
    expect(find.byKey(const Key('cart_decrement_prod-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cart_increment_prod-1')));
    await tester.pumpAndSettle();

    expect(mockRepo.setItemQuantityCallCount, equals(1));
    expect(mockRepo.lastQuantityParam, equals(3));
  });

  testWidgets('ProductCard disables Add button when product is unavailable', (tester) async {
    final mockRepo = MockCartRepository();
    final notifier = CartNotifier(cartRepository: mockRepo);
    await notifier.loadForStore('store-1');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ProductCard(
            product: unavailableProduct,
            cartNotifier: notifier,
          ),
        ),
      ),
    );

    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
  });
}
