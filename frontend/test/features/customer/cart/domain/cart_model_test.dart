import 'package:esouq/features/customer/cart/domain/cart_item_model.dart';
import 'package:esouq/features/customer/cart/domain/cart_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CartItemModel', () {
    test('parses backend JSON format correctly', () {
      final json = {
        'itemId': 'item-101',
        'name': 'Fresh Milk 1L',
        'price': 1.25,
        'quantity': 3,
        'imageUrl': 'https://example.com/milk.jpg',
      };

      final item = CartItemModel.fromJson(json);

      expect(item.itemId, equals('item-101'));
      expect(item.productId, equals('item-101'));
      expect(item.name, equals('Fresh Milk 1L'));
      expect(item.productName, equals('Fresh Milk 1L'));
      expect(item.price, equals(1.25));
      expect(item.unitPrice, equals(1.25));
      expect(item.imageUrl, equals('https://example.com/milk.jpg'));
      expect(item.isAvailable, isTrue);
      expect(item.quantity, equals(3));
      expect(item.itemSubtotal, equals(3.75));
    });

    test('parses legacy snake_case JSON correctly', () {
      final json = {
        'item_id': 'item-101',
        'product_id': 'prod-202',
        'product_name': 'Fresh Milk 1L',
        'unit_price': '1.25',
        'image_url': 'https://example.com/milk.jpg',
        'is_available': true,
        'loyalty_points_per_unit': 5,
        'quantity': 3,
        'item_subtotal': '3.75',
      };

      final item = CartItemModel.fromJson(json);

      expect(item.itemId, equals('item-101'));
      expect(item.productId, equals('item-101'));
      expect(item.productName, equals('Fresh Milk 1L'));
      expect(item.unitPrice, equals(1.25));
      expect(item.imageUrl, equals('https://example.com/milk.jpg'));
      expect(item.isAvailable, isTrue);
      expect(item.loyaltyPointsPerUnit, equals(5));
      expect(item.quantity, equals(3));
      expect(item.itemSubtotal, equals(3.75));
      expect(item.subtotalPoints, equals(15));
    });

    test('handles null and missing fields gracefully', () {
      final json = {
        'itemId': 'item-102',
        'name': 'Bakery Bread',
        'price': 0.80,
      };

      final item = CartItemModel.fromJson(json);

      expect(item.imageUrl, isNull);
      expect(item.isAvailable, isTrue);
      expect(item.loyaltyPointsPerUnit, equals(0));
      expect(item.subtotalPoints, equals(0));
      expect(item.quantity, equals(1));
    });
  });

  group('CartModel', () {
    test('parses backend Cart JSON correctly', () {
      final json = {
        'userId': 'usr-1',
        'storeId': 'store-100',
        'items': [
          {
            'itemId': 'item-1',
            'name': 'Milk 1L',
            'price': 1.25,
            'quantity': 2,
            'imageUrl': 'https://example.com/milk.jpg',
          },
        ],
        'subtotal': 2.50,
        'updatedAt': '2026-09-10T12:00:00.000Z',
      };

      final cart = CartModel.fromJson(json);

      expect(cart.userId, equals('usr-1'));
      expect(cart.storeId, equals('store-100'));
      expect(cart.items.length, equals(1));
      expect(cart.subtotal, equals(2.50));
      expect(cart.itemCount, equals(2));
      expect(cart.hasUnavailableItems, isFalse);
      expect(cart.isNotEmpty, isTrue);
    });

    test('creates empty cart correctly', () {
      final emptyCart = CartModel.empty(storeId: 'store-1');

      expect(emptyCart.storeId, equals('store-1'));
      expect(emptyCart.items, isEmpty);
      expect(emptyCart.subtotal, equals(0.0));
      expect(emptyCart.itemCount, equals(0));
      expect(emptyCart.isEmpty, isTrue);
    });
  });
}
