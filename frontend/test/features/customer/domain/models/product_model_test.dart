import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductModel', () {
    test(
      'parses backend Prisma Item response with nested category object correctly',
      () {
        final json = {
          'id': 'item-101',
          'storeId': 'store-1',
          'categoryId': 'cat-1',
          'name': 'Mango Juice 1L',
          'description': 'Fresh mango juice, chilled',
          'price': 12.5,
          'imageUrl': 'https://cdn.example.com/mango.jpg',
          'isAvailable': true,
          'sortOrder': 3,
          'category': {
            'id': 'cat-1',
            'storeId': 'store-1',
            'name': 'Beverages',
            'sortOrder': 0,
            'createdAt': '2026-09-07T19:06:18.000Z',
            'updatedAt': '2026-09-07T19:06:18.000Z',
          },
          'createdAt': '2026-09-07T19:06:18.000Z',
          'updatedAt': '2026-09-07T19:06:18.000Z',
        };

        final product = ProductModel.fromJson(json);

        expect(product.id, equals('item-101'));
        expect(product.storeId, equals('store-1'));
        expect(product.categoryId, equals('cat-1'));
        expect(product.name, equals('Mango Juice 1L'));
        expect(product.description, equals('Fresh mango juice, chilled'));
        expect(product.price, equals(12.5));
        expect(product.category, equals('Beverages'));
        expect(product.imageUrl, equals('https://cdn.example.com/mango.jpg'));
        expect(product.isAvailable, isTrue);
        expect(product.sortOrder, equals(3));
        expect(product.loyaltyPointsPerUnit, equals(0));
        expect(product.createdAt, isNotNull);
        expect(product.updatedAt, isNotNull);
      },
    );

    test(
      'parses full legacy JSON response with string numeric price correctly',
      () {
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
      },
    );

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
        categoryId: 'cat-5',
        name: 'Eggs 30pk',
        price: 3.50,
        category: 'Dairy & Eggs',
        sortOrder: 2,
        loyaltyPointsPerUnit: 10,
      );

      final json = product.toJson();

      expect(json['id'], equals('p-5'));
      expect(json['storeId'], equals('s-1'));
      expect(json['categoryId'], equals('cat-5'));
      expect(json['name'], equals('Eggs 30pk'));
      expect(json['price'], equals('3.50'));
      expect(json['category'], equals('Dairy & Eggs'));
      expect(json['sortOrder'], equals(2));
      expect(json['loyalty_points_per_unit'], equals(10));
    });

    test('parses backend pointsValue and points_value correctly', () {
      // 1. camelCase pointsValue (backend formatProductResponse)
      final json1 = {
        'id': 'p-pv1',
        'storeId': 's-1',
        'name': 'Premium Coffee',
        'price': 25.0,
        'pointsValue': 15,
      };
      final p1 = ProductModel.fromJson(json1);
      expect(p1.loyaltyPointsPerUnit, equals(15));

      // 2. snake_case points_value
      final json2 = {
        'id': 'p-pv2',
        'storeId': 's-1',
        'name': 'Green Tea',
        'price': 10.0,
        'points_value': 8,
      };
      final p2 = ProductModel.fromJson(json2);
      expect(p2.loyaltyPointsPerUnit, equals(8));

      // 3. String numeric pointsValue
      final json3 = {
        'id': 'p-pv3',
        'storeId': 's-1',
        'name': 'Herbal Tea',
        'price': 12.0,
        'pointsValue': '20',
      };
      final p3 = ProductModel.fromJson(json3);
      expect(p3.loyaltyPointsPerUnit, equals(20));

      // 4. Legacy alias loyaltyPointsPerUnit still works
      final json4 = {
        'id': 'p-legacy',
        'storeId': 's-1',
        'name': 'Chai',
        'price': 5.0,
        'loyaltyPointsPerUnit': 3,
      };
      final p4 = ProductModel.fromJson(json4);
      expect(p4.loyaltyPointsPerUnit, equals(3));
    });

    test('correctly handles offerPrice, hasOffer, effectivePrice, and discountPercentage', () {
      // 1. Product with valid offer price
      final jsonWithOffer = {
        'id': 'p-offer-1',
        'storeId': 's-1',
        'name': 'Special Blend',
        'price': 100.0,
        'offerPrice': 75.0,
      };
      final p1 = ProductModel.fromJson(jsonWithOffer);
      expect(p1.offerPrice, equals(75.0));
      expect(p1.hasOffer, isTrue);
      expect(p1.effectivePrice, equals(75.0));
      expect(p1.discountPercentage, equals(25)); // (100 - 75) / 100 * 100 = 25%

      // 2. Product with offer_price in snake_case
      final jsonSnake = {
        'id': 'p-offer-2',
        'storeId': 's-1',
        'name': 'Olive Oil',
        'price': '50.00',
        'offer_price': '40.00',
      };
      final p2 = ProductModel.fromJson(jsonSnake);
      expect(p2.offerPrice, equals(40.0));
      expect(p2.hasOffer, isTrue);
      expect(p2.effectivePrice, equals(40.0));
      expect(p2.discountPercentage, equals(20)); // (50 - 40) / 50 * 100 = 20%

      // 3. Product with no offer price
      final jsonNoOffer = {
        'id': 'p-no-offer',
        'storeId': 's-1',
        'name': 'Bread',
        'price': 10.0,
      };
      final p3 = ProductModel.fromJson(jsonNoOffer);
      expect(p3.offerPrice, isNull);
      expect(p3.hasOffer, isFalse);
      expect(p3.effectivePrice, equals(10.0));
      expect(p3.discountPercentage, isNull);

      // 4. Inactive offer if offerPrice >= price or offerPrice <= 0
      final jsonInvalidOffer = {
        'id': 'p-inv',
        'storeId': 's-1',
        'name': 'Flour',
        'price': 20.0,
        'offerPrice': 25.0,
      };
      final p4 = ProductModel.fromJson(jsonInvalidOffer);
      expect(p4.offerPrice, equals(25.0));
      expect(p4.hasOffer, isFalse);
      expect(p4.effectivePrice, equals(20.0));
      expect(p4.discountPercentage, isNull);

      // 5. copyWith preserves or updates offerPrice
      final p1Updated = p1.copyWith(offerPrice: 60.0);
      expect(p1Updated.offerPrice, equals(60.0));
      expect(p1Updated.effectivePrice, equals(60.0));
      expect(p1Updated.discountPercentage, equals(40));

      final p1Cleared = p1.copyWith(offerPrice: null);
      // Note: standard copyWith without sentinel retains existing value if null passed
      expect(p1Cleared.offerPrice, equals(75.0));
    });
  });
}
