import 'dart:async';
import 'package:esouq/core/constants/app_constants.dart';
import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/customer/cart/application/cart_notifier.dart';
import 'package:esouq/features/customer/cart/domain/cart_item_model.dart';
import 'package:esouq/features/customer/cart/domain/cart_model.dart';
import 'package:esouq/features/customer/cart/presentation/screens/cart_screen.dart';
import 'package:esouq/features/customer/cart/presentation/widgets/cart_empty_state.dart';
import 'package:esouq/features/customer/cart/presentation/widgets/cart_item_tile.dart';
import 'package:esouq/features/customer/cart/presentation/widgets/cart_summary_bar.dart';
import 'package:esouq/features/customer/cart/presentation/widgets/cart_unavailable_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mocks/mock_cart_repository.dart';

void main() {
  group('CartScreen', () {
    late MockCartRepository mockRepo;
    late CartNotifier notifier;

    setUp(() {
      mockRepo = MockCartRepository();
      notifier = CartNotifier(cartRepository: mockRepo);
    });

    tearDown(() {
      notifier.dispose();
    });

    Widget buildWidget({VoidCallback? onExploreMarket}) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: CartScreen(
          cartNotifier: notifier,
          storeName: 'eSOuQ Olaya Flagship',
          storeArea: 'Olaya',
          onExploreMarket: onExploreMarket,
        ),
      );
    }

    testWidgets('renders loading spinner when cart is loading', (tester) async {
      final completer = Completer<Result<CartModel>>();
      mockRepo.customGetCartHandler = (storeId) => completer.future;

      notifier.loadForStore('store-1');

      await tester.pumpWidget(buildWidget());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(Result.success(mockRepo.defaultCart));
      await tester.pumpAndSettle();
    });

    testWidgets('renders empty cart state when store cart has 0 items', (tester) async {
      mockRepo.cartToReturn = const CartModel(
        cartId: null,
        store: CartStoreRef(id: 's-1', name: 'eSOuQ Olaya Flagship', area: 'Olaya', isActive: true),
        items: [],
        subtotal: 0.0,
        itemCount: 0,
        hasUnavailableItems: false,
      );

      await notifier.loadForStore('s-1');
      await tester.pumpWidget(buildWidget(onExploreMarket: () {}));
      await tester.pumpAndSettle();

      expect(find.byType(CartEmptyState), findsOneWidget);
      expect(find.text('Your Cart is Empty'), findsOneWidget);
      expect(find.byKey(const Key('cart_explore_market_button')), findsOneWidget);
    });

    testWidgets('renders error view on failure and allows retry', (tester) async {
      mockRepo.failureToReturn = const ServerFailure(message: 'Database unavailable');

      await notifier.loadForStore('s-1');
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load cart'), findsOneWidget);
      expect(find.text('Database unavailable'), findsOneWidget);
      expect(find.byKey(const Key('cart_error_retry_button')), findsOneWidget);

      // Clear error on retry
      mockRepo.failureToReturn = null;
      await tester.tap(find.byKey(const Key('cart_error_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CartItemTile), findsNWidgets(2));
    });

    testWidgets('renders populated cart with items, subtotal, and summary bar', (tester) async {
      await notifier.loadForStore('s-1');
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(CartItemTile), findsNWidgets(2));
      expect(find.text('Fresh Whole Milk 1L'), findsOneWidget);
      expect(find.text('Organic Bananas 1kg'), findsOneWidget);
      expect(find.text('3.35 ${AppConstants.defaultCurrency}'), findsOneWidget);
      expect(find.byType(CartSummaryBar), findsOneWidget);
      expect(find.byKey(const Key('cart_checkout_button')), findsOneWidget);
    });

    testWidgets('renders unavailable items banner and disables checkout', (tester) async {
      mockRepo.cartToReturn = const CartModel(
        cartId: 'cart-1',
        store: CartStoreRef(id: 's-1', name: 'eSOuQ Olaya Flagship', area: 'Olaya', isActive: true),
        items: [
          CartItemModel(
            itemId: 'item-1',
            productId: 'p-unavail',
            productName: 'Out of Stock Bread',
            unitPrice: 1.00,
            isAvailable: false,
            loyaltyPointsPerUnit: 0,
            quantity: 1,
            itemSubtotal: 1.00,
          )
        ],
        subtotal: 1.00,
        itemCount: 1,
        hasUnavailableItems: true,
      );

      await notifier.loadForStore('s-1');
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(CartUnavailableBanner), findsOneWidget);
      expect(find.text('Currently Unavailable'), findsOneWidget);
      expect(find.text('Remove Unavailable Items'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(find.byKey(const Key('cart_checkout_button')));
      expect(button.onPressed, isNull);
    });

    testWidgets('shows confirmation dialog and clears cart on confirm', (tester) async {
      await notifier.loadForStore('s-1');
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cart_clear_action_button')));
      await tester.pumpAndSettle();

      expect(find.text('Clear Cart?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_clear_cart_button')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(mockRepo.clearCartCallCount, equals(1));
    });
  });
}
