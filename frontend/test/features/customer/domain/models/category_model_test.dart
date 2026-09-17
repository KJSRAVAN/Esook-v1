import 'package:esouq/features/customer/domain/models/category_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryModel', () {
    test('parses backend JSON response correctly', () {
      final json = {
        'id': 'cat-1',
        'storeId': 'store-1',
        'name': 'Beverages',
        'sortOrder': 2,
        '_count': {
          'items': 14,
        },
        'createdAt': '2026-09-10T12:00:00.000Z',
        'updatedAt': '2026-09-10T13:00:00.000Z',
      };

      final category = CategoryModel.fromJson(json);

      expect(category.id, equals('cat-1'));
      expect(category.storeId, equals('store-1'));
      expect(category.name, equals('Beverages'));
      expect(category.sortOrder, equals(2));
      expect(category.itemCount, equals(14));
      expect(category.createdAt, isNotNull);
      expect(category.updatedAt, isNotNull);
    });

    test('handles fallback and snake_case keys gracefully', () {
      final json = {
        'id': 'cat-2',
        'store_id': 'store-99',
        'name': 'Snacks',
        'sort_order': 5,
        'item_count': 8,
      };

      final category = CategoryModel.fromJson(json);

      expect(category.id, equals('cat-2'));
      expect(category.storeId, equals('store-99'));
      expect(category.name, equals('Snacks'));
      expect(category.sortOrder, equals(5));
      expect(category.itemCount, equals(8));
      expect(category.createdAt, isNull);
    });

    test('serializes to JSON correctly', () {
      const category = CategoryModel(
        id: 'cat-3',
        storeId: 'store-1',
        name: 'Bakery',
        sortOrder: 1,
        itemCount: 10,
      );

      final json = category.toJson();

      expect(json['id'], equals('cat-3'));
      expect(json['storeId'], equals('store-1'));
      expect(json['name'], equals('Bakery'));
      expect(json['sortOrder'], equals(1));
      expect(json['itemCount'], equals(10));
    });
  });
}
