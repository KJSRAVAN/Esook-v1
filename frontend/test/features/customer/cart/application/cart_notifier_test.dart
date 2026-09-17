import 'package:esouq/core/error/failures.dart';
import 'package:esouq/features/customer/cart/application/cart_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_cart_repository.dart';

void main() {
  group('CartNotifier', () {
    late MockCartRepository mockRepo;
    late CartNotifier notifier;

    setUp(() {
      mockRepo = MockCartRepository();
      notifier = CartNotifier(cartRepository: mockRepo);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('loadForStore fetches and sets cart for store', () async {
      await notifier.loadForStore('store-1');

      expect(notifier.currentStoreId, equals('store-1'));
      expect(notifier.isLoading, isFalse);
      expect(notifier.cart, isNotNull);
      expect(notifier.itemCount, equals(3));
      expect(notifier.subtotal, equals(3.35));
      expect(mockRepo.getCartCallCount, equals(1));
    });

    test('addItem updates cart state on success', () async {
      await notifier.loadForStore('store-1');

      await notifier.addItem('prod-1', 1);

      expect(mockRepo.addItemCallCount, equals(1));
      expect(mockRepo.lastProductIdParam, equals('prod-1'));
      expect(mockRepo.lastQuantityParam, equals(1));
      expect(notifier.error, isNull);
    });

    test('setQuantity with quantity > 0 calls setItemQuantity', () async {
      await notifier.loadForStore('store-1');

      await notifier.setQuantity('prod-1', 4);

      expect(mockRepo.setItemQuantityCallCount, equals(1));
      expect(mockRepo.lastProductIdParam, equals('prod-1'));
      expect(mockRepo.lastQuantityParam, equals(4));
    });

    test('setQuantity with quantity <= 0 routes directly to removeItem', () async {
      await notifier.loadForStore('store-1');

      await notifier.setQuantity('prod-1', 0);

      expect(mockRepo.setItemQuantityCallCount, equals(0));
      expect(mockRepo.removeItemCallCount, equals(1));
      expect(mockRepo.lastProductIdParam, equals('prod-1'));
    });

    test('removeItem calls repository and updates cart', () async {
      await notifier.loadForStore('store-1');

      await notifier.removeItem('prod-2');

      expect(mockRepo.removeItemCallCount, equals(1));
      expect(mockRepo.lastProductIdParam, equals('prod-2'));
    });

    test('clear calls repository and resets cart', () async {
      await notifier.loadForStore('store-1');

      await notifier.clear();

      expect(mockRepo.clearCartCallCount, equals(1));
      expect(notifier.cart?.isEmpty, isTrue);
    });

    test('failed mutation preserves previous cart and exposes failure', () async {
      await notifier.loadForStore('store-1');
      final originalCart = notifier.cart;

      mockRepo.failureToReturn = const ValidationFailure(message: 'Item unavailable');

      await notifier.addItem('prod-999', 1);

      expect(notifier.error, isA<ValidationFailure>());
      expect(notifier.error?.message, equals('Item unavailable'));
      expect(notifier.cart, equals(originalCart));
    });

    test('stale store response is discarded if store changes', () async {
      // Start loading store-1
      final futureStore1 = notifier.loadForStore('store-1');
      // Immediately switch to store-2
      final futureStore2 = notifier.loadForStore('store-2');

      await Future.wait([futureStore1, futureStore2]);

      expect(notifier.currentStoreId, equals('store-2'));
    });

    test('quantityForProduct returns matching cart item quantity or 0', () async {
      await notifier.loadForStore('store-1');

      expect(notifier.quantityForProduct('prod-1'), equals(2));
      expect(notifier.quantityForProduct('prod-2'), equals(1));
      expect(notifier.quantityForProduct('prod-nonexistent'), equals(0));
    });

    test('sequential queue processes rapid mutations in order', () async {
      await notifier.loadForStore('store-1');

      final f1 = notifier.addItem('prod-1', 1);
      final f2 = notifier.setQuantity('prod-1', 5);
      final f3 = notifier.removeItem('prod-1');

      await Future.wait([f1, f2, f3]);

      expect(mockRepo.addItemCallCount, equals(1));
      expect(mockRepo.setItemQuantityCallCount, equals(1));
      expect(mockRepo.removeItemCallCount, equals(1));
    });
  });
}
