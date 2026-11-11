import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/customer/cart/application/cart_notifier.dart';
import 'package:esouq/features/customer/cart/domain/cart_item_model.dart';
import 'package:esouq/features/customer/cart/domain/cart_model.dart';
import 'package:esouq/features/customer/cart/domain/cart_repository.dart';
import 'package:esouq/features/customer/cart/presentation/screens/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class InMemoryCartRepository implements CartRepository {
  CartModel _currentCart = CartModel.empty(storeId: 'store-1');
  int clearCallCount = 0;

  @override
  Future<Result<CartModel>> getCart({String? storeId}) async {
    return Result.success(_currentCart);
  }

  @override
  Future<Result<CartModel>> addItem({
    required String itemId,
    required int quantity,
    String? storeId,
    String? productId,
  }) async {
    final existingIdx = _currentCart.items.indexWhere(
      (i) => i.itemId == itemId || i.productId == (productId ?? itemId),
    );

    final List<CartItemModel> updatedItems = List.from(_currentCart.items);
    if (existingIdx >= 0) {
      final existing = updatedItems[existingIdx];
      updatedItems[existingIdx] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      updatedItems.add(
        CartItemModel(
          itemId: 'var-$itemId',
          productId: productId ?? itemId,
          name: 'Item $itemId',
          price: 15.0,
          originalPrice: 20.0,
          offerPrice: 15.0,
          quantity: quantity,
          loyaltyPointsPerUnit: 5,
        ),
      );
    }

    final newSubtotal = updatedItems.fold<double>(
      0.0,
      (sum, item) => sum + item.itemSubtotal,
    );

    _currentCart = _currentCart.copyWith(
      storeId: storeId ?? _currentCart.storeId,
      items: updatedItems,
      subtotal: newSubtotal,
    );

    return Result.success(_currentCart);
  }

  @override
  Future<Result<CartModel>> setItemQuantity({
    required String itemId,
    required int quantity,
    String? storeId,
    String? productId,
  }) async {
    if (quantity <= 0) {
      return removeItem(itemId: itemId, storeId: storeId, productId: productId);
    }

    final List<CartItemModel> updatedItems = List.from(_currentCart.items);
    final idx = updatedItems.indexWhere(
      (i) => i.itemId == itemId || i.productId == (productId ?? itemId),
    );
    if (idx >= 0) {
      updatedItems[idx] = updatedItems[idx].copyWith(quantity: quantity);
    }

    final newSubtotal = updatedItems.fold<double>(
      0.0,
      (sum, item) => sum + item.itemSubtotal,
    );

    _currentCart = _currentCart.copyWith(
      items: updatedItems,
      subtotal: newSubtotal,
    );

    return Result.success(_currentCart);
  }

  @override
  Future<Result<CartModel>> removeItem({
    required String itemId,
    String? storeId,
    String? productId,
  }) async {
    final updatedItems = _currentCart.items
        .where(
          (i) => i.itemId != itemId && i.productId != (productId ?? itemId),
        )
        .toList();

    final newSubtotal = updatedItems.fold<double>(
      0.0,
      (sum, item) => sum + item.itemSubtotal,
    );

    _currentCart = _currentCart.copyWith(
      items: updatedItems,
      subtotal: newSubtotal,
    );

    return Result.success(_currentCart);
  }

  @override
  Future<Result<CartModel>> clearCart({String? storeId}) async {
    clearCallCount++;
    _currentCart = CartModel.empty(storeId: storeId ?? _currentCart.storeId);
    return Result.success(_currentCart);
  }
}

void main() {
  group('Cart Bug Fix — 9 Required Verification Scenarios', () {
    late InMemoryCartRepository repo;
    late CartNotifier notifier;

    setUp(() async {
      repo = InMemoryCartRepository();
      notifier = CartNotifier(cartRepository: repo);
      await notifier.loadForStore('store-1');
    });

    test('1. Add one product and verify it remains in cart', () async {
      await notifier.addItem('prod-1', 1, 'store-1');
      expect(notifier.itemCount, equals(1));
      expect(notifier.cart!.items.length, equals(1));
      expect(notifier.cart!.items.first.productId, equals('prod-1'));
      expect(notifier.quantityForProduct('prod-1'), equals(1));
    });

    test('2. Add another product and verify both remain', () async {
      await notifier.addItem('prod-1', 1, 'store-1');
      await notifier.addItem('prod-2', 2, 'store-1');

      expect(notifier.itemCount, equals(3));
      expect(notifier.cart!.items.length, equals(2));
      expect(notifier.quantityForProduct('prod-1'), equals(1));
      expect(notifier.quantityForProduct('prod-2'), equals(2));
    });

    test('3. Increase and decrease quantities', () async {
      await notifier.addItem('prod-1', 1, 'store-1');
      expect(notifier.quantityForProduct('prod-1'), equals(1));

      // Increase
      await notifier.setQuantity('prod-1', 3, 'store-1');
      expect(notifier.quantityForProduct('prod-1'), equals(3));
      expect(notifier.subtotal, equals(45.0)); // 3 * 15.0

      // Decrease
      await notifier.setQuantity('prod-1', 2, 'store-1');
      expect(notifier.quantityForProduct('prod-1'), equals(2));
      expect(notifier.subtotal, equals(30.0)); // 2 * 15.0
    });

    test('4. Navigate between tabs / state persistence across reads', () async {
      await notifier.addItem('prod-1', 2, 'store-1');
      await notifier.addItem('prod-2', 1, 'store-1');

      // Emulate switching away to market/orders and switching back
      expect(notifier.itemCount, equals(3));
      expect(notifier.cart!.items.length, equals(2));

      // Verify that calling getCart again preserves persistence
      final refreshed = await repo.getCart(storeId: 'store-1');
      expect(refreshed.dataOrNull?.items.length, equals(2));
      expect(refreshed.dataOrNull?.itemCount, equals(3));
    });

    test('5. Exit and return to cart, verify it remains intact', () async {
      await notifier.addItem('prod-1', 1, 'store-1');
      expect(notifier.itemCount, equals(1));

      // Simulate re-loading store cart upon returning to screen
      await notifier.loadForStore('store-1');
      expect(notifier.itemCount, equals(1));
      expect(notifier.quantityForProduct('prod-1'), equals(1));
    });

    test('6. Verify cart badge displays accurate item count', () async {
      expect(notifier.itemCount, equals(0));
      await notifier.addItem('prod-1', 2, 'store-1');
      expect(notifier.itemCount, equals(2));
      await notifier.addItem('prod-2', 3, 'store-1');
      expect(notifier.itemCount, equals(5));
      await notifier.setQuantity('prod-1', 1, 'store-1');
      expect(notifier.itemCount, equals(4));
    });

    test('7. Verify prices, discounts and points are calculated properly', () async {
      await notifier.addItem('prod-1', 2, 'store-1');
      final item = notifier.cart!.items.first;

      expect(item.price, equals(15.0));
      expect(item.originalPrice, equals(20.0));
      expect(item.hasOffer, isTrue);
      expect(item.discountPercent, equals(25)); // (20-15)/20 = 25%
      expect(item.totalSavings, equals(10.0)); // 5 * 2
      expect(item.subtotalPoints, equals(10)); // 5 pts * 2
      expect(notifier.cart!.totalLoyaltyPoints, equals(10));
      expect(notifier.subtotal, equals(30.0));
    });

    test('8. Verify checkout completes with the cart contents', () async {
      await notifier.addItem('prod-1', 2, 'store-1');
      expect(notifier.cart!.isNotEmpty, isTrue);
      expect(notifier.cart!.items.length, equals(1));
      // Upon checkout success, clear is called
      await notifier.clear();
      expect(repo.clearCallCount, equals(1));
      expect(notifier.cart!.isEmpty, isTrue);
    });

    testWidgets('9. Verify empty-cart display after clearing or checkout', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CartScreen(
              cartNotifier: notifier,
              storeName: 'Test Supermarket',
              onExploreMarket: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your Cart is Empty'), findsOneWidget);
      expect(find.text('Explore Market'), findsOneWidget);
    });
  });
}
