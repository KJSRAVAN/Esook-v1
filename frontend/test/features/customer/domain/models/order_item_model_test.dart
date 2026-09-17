import 'package:esouq/features/customer/domain/models/order_item_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderItemModel & OrderItemInput', () {
    test('OrderItemInput serializes to JSON correctly', () {
      const input = OrderItemInput(itemId: 'item-1', quantity: 3);
      expect(input.toJson(), equals({
        'itemId': 'item-1',
        'quantity': 3,
      }));
    });

    test('OrderItemModel parses camelCase JSON with full fields', () {
      final json = {
        'id': 'line-1',
        'orderId': 'ord-100',
        'itemId': 'prod-1',
        'itemName': 'Fresh Whole Milk 1L',
        'itemPrice': 1.25,
        'quantity': 2,
        'subtotal': 2.50,
        'imageUrl': 'https://img.esouq.com/milk.png',
        'loyaltyPointsPerUnit': 5,
        'subtotalPoints': 10,
      };

      final item = OrderItemModel.fromJson(json);

      expect(item.id, equals('line-1'));
      expect(item.orderId, equals('ord-100'));
      expect(item.itemId, equals('prod-1'));
      expect(item.itemName, equals('Fresh Whole Milk 1L'));
      expect(item.itemPrice, equals(1.25));
      expect(item.quantity, equals(2));
      expect(item.subtotal, equals(2.50));
      expect(item.imageUrl, equals('https://img.esouq.com/milk.png'));
      expect(item.loyaltyPointsPerUnit, equals(5));
      expect(item.subtotalPoints, equals(10));
      expect(item.productId, equals('prod-1'));
      expect(item.name, equals('Fresh Whole Milk 1L'));
    });

    test('OrderItemModel parses snake_case JSON with string prices gracefully', () {
      final json = {
        'id': 'line-2',
        'order_id': 'ord-101',
        'product_id': 'prod-2',
        'product_name': 'Organic Bananas 1kg',
        'unit_price': '0.85',
        'quantity': '3',
        'points_per_unit': '2',
      };

      final item = OrderItemModel.fromJson(json);

      expect(item.id, equals('line-2'));
      expect(item.orderId, equals('ord-101'));
      expect(item.itemId, equals('prod-2'));
      expect(item.itemName, equals('Organic Bananas 1kg'));
      expect(item.itemPrice, equals(0.85));
      expect(item.quantity, equals(3));
      expect(item.subtotal, closeTo(2.55, 0.001));
      expect(item.loyaltyPointsPerUnit, equals(2));
      expect(item.subtotalPoints, equals(6));
    });

    test('OrderItemModel toJson returns serialized map', () {
      const item = OrderItemModel(
        id: 'line-3',
        orderId: 'ord-102',
        itemId: 'prod-3',
        itemName: 'Fresh Bread',
        itemPrice: 1.00,
        quantity: 2,
        imageUrl: 'https://img.esouq.com/bread.png',
        loyaltyPointsPerUnit: 1,
      );

      final json = item.toJson();

      expect(json['id'], equals('line-3'));
      expect(json['orderId'], equals('ord-102'));
      expect(json['itemId'], equals('prod-3'));
      expect(json['itemName'], equals('Fresh Bread'));
      expect(json['itemPrice'], equals(1.00));
      expect(json['quantity'], equals(2));
      expect(json['subtotal'], equals(2.00));
      expect(json['imageUrl'], equals('https://img.esouq.com/bread.png'));
      expect(json['loyaltyPointsPerUnit'], equals(1));
      expect(json['subtotalPoints'], equals(2));
    });

    test('OrderItemModel copyWith updates fields correctly', () {
      const item = OrderItemModel(
        itemId: 'prod-1',
        itemName: 'Milk',
        itemPrice: 1.25,
        quantity: 1,
      );

      final updated = item.copyWith(quantity: 4);

      expect(updated.quantity, equals(4));
      expect(updated.itemId, equals('prod-1'));
      expect(updated.itemName, equals('Milk'));
    });
  });
}
