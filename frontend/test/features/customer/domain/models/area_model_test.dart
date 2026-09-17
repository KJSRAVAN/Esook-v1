import 'package:esouq/features/customer/domain/models/area_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AreaModel', () {
    test('parses backend JSON response correctly', () {
      final json = {
        'id': 'area-1',
        'name': 'Riyadh - Olaya',
        'createdAt': '2026-09-07T19:06:18.000Z',
      };

      final area = AreaModel.fromJson(json);

      expect(area.id, equals('area-1'));
      expect(area.name, equals('Riyadh - Olaya'));
      expect(area.createdAt, isNotNull);
    });

    test('handles missing fields gracefully', () {
      final json = {
        'id': 'area-2',
        'name': 'Jeddah Corniche',
      };

      final area = AreaModel.fromJson(json);

      expect(area.id, equals('area-2'));
      expect(area.name, equals('Jeddah Corniche'));
      expect(area.createdAt, isNull);
    });

    test('serializes to JSON correctly', () {
      const area = AreaModel(
        id: 'area-3',
        name: 'Dammam Port',
      );

      final json = area.toJson();

      expect(json['id'], equals('area-3'));
      expect(json['name'], equals('Dammam Port'));
    });
  });
}
