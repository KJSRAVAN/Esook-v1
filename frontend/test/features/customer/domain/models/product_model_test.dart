import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductModel', () {
    test('parses full JSON response with string numeric price correctly', () {
      final json = {
        'id': 'p-1',
        'store_id': 's-1',
        'name': 'Fresh Milk 1L',
        'description': 'Pure cow milk',
        'price': '6.50',
        'category': 'Dairy & Eggs',
        'image_url': 'https://example.com/milk.jpg',
        'is_available': true,
        'loyalty_points_per_unit': 5,
        'created_at': '2026-09-10T12:00:00.000Z',
        'updated_at': '2026-09-10T13:00:00.000Z',
      };

      final product = ProductModel.fromJson(json);

      expect(product.id, equals('p-1'));
      expect(product.storeId, equals('s-1'));
      expect(product.name, equals('Fresh Milk 1L'));
      expect(product.description, equals('Pure cow milk'));
      expect(product.price, equals(6.50));
      expect(product.category, equals('Dairy & Eggs'));
      expect(product.imageUrl, equals('https://example.com/milk.jpg'));
      expect(product.isAvailable, isTrue);
      expect(product.loyaltyPointsPerUnit, equals(5));
      expect(product.createdAt, isNotNull);
      expect(product.updatedAt, isNotNull);
    });

    test('parses double and int price types safely', () {
      final json1 = {
        'id': 'p-2',
        'store_id': 's-1',
        'name': 'Apple',
        'price': 1.75,
      };
      final product1 = ProductModel.fromJson(json1);
      expect(product1.price, equals(1.75));

      final json2 = {
        'id': 'p-3',
        'store_id': 's-1',
        'name': 'Banana',
        'price': 2,
      };
      final product2 = ProductModel.fromJson(json2);
      expect(product2.price, equals(2.0));
    });

    test('handles nullable fields and missing loyalty points gracefully', () {
      final json = {
        'id': 'p-4',
        'store_id': 's-1',
        'name': 'Water 500ml',
        'price': '0.20',
        'description': null,
        'category': null,
        'image_url': null,
        'is_available': false,
        'loyalty_points_per_unit': null,
      };

      final product = ProductModel.fromJson(json);

      expect(product.id, equals('p-4'));
      expect(product.name, equals('Water 500ml'));
      expect(product.price, equals(0.20));
      expect(product.description, isNull);
      expect(product.category, isNull);
      expect(product.imageUrl, isNull);
      expect(product.isAvailable, isFalse);
      expect(product.loyaltyPointsPerUnit, equals(0));
    });

    test('serializes to JSON correctly', () {
      const product = ProductModel(
        id: 'p-5',
        storeId: 's-1',
        name: 'Eggs 30pk',
        price: 3.50,
        category: 'Dairy & Eggs',
        loyaltyPointsPerUnit: 10,
      );

      final json = product.toJson();

      expect(json['id'], equals('p-5'));
      expect(json['name'], equals('Eggs 30pk'));
      expect(json['price'], equals('3.50'));
      expect(json['category'], equals('Dairy & Eggs'));
      expect(json['loyalty_points_per_unit'], equals(10));
    });
  });
}
