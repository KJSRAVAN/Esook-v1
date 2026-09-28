import 'package:esouq/features/store/domain/models/csv_import_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvImportResultModel', () {
    test('parses standard backend response with root fields', () {
      final json = {
        'imported': 12,
        'updated': 4,
        'skipped': 1,
        'errors': [
          {'row': 5, 'message': 'Price must be positive', 'field': 'price'},
          {'row': 9, 'message': 'Category does not exist', 'field': 'category'},
        ],
      };

      final result = CsvImportResultModel.fromJson(json);

      expect(result.imported, 12);
      expect(result.updated, 4);
      expect(result.skipped, 1);
      expect(result.errors.length, 2);
      expect(result.errors[0].row, 5);
      expect(result.errors[0].message, 'Price must be positive');
      expect(result.errors[0].field, 'price');
      expect(result.errors[1].row, 9);
      expect(result.errors[1].message, 'Category does not exist');
      expect(result.errors[1].field, 'category');
      expect(result.totalProcessed, 19);
      expect(result.hasErrors, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('parses nested data response envelope', () {
      final json = {
        'data': {
          'imported': 5,
          'updated': 2,
          'skipped': 0,
          'errors': [],
        },
      };

      final result = CsvImportResultModel.fromJson(json);

      expect(result.imported, 5);
      expect(result.updated, 2);
      expect(result.skipped, 0);
      expect(result.errors, isEmpty);
      expect(result.totalProcessed, 7);
      expect(result.hasErrors, isFalse);
      expect(result.isSuccess, isTrue);
    });

    test('parses alternative error keys and string errors', () {
      final json = {
        'created': '10',
        'modified': '3',
        'ignored': '2',
        'rowErrors': [
          'Row 7: Duplicate product barcode',
          'Malformed row format',
        ],
      };

      final result = CsvImportResultModel.fromJson(json);

      expect(result.imported, 10);
      expect(result.updated, 3);
      expect(result.skipped, 2);
      expect(result.errors.length, 2);
      expect(result.errors[0].row, 7);
      expect(result.errors[0].message, 'Duplicate product barcode');
      expect(result.errors[1].row, isNull);
      expect(result.errors[1].message, 'Malformed row format');
    });

    test('handles empty or malformed input gracefully', () {
      final result = CsvImportResultModel.fromJson('not a map');
      expect(result.imported, 0);
      expect(result.updated, 0);
      expect(result.skipped, 0);
      expect(result.errors, isEmpty);
    });

    test('serializes to JSON correctly', () {
      const model = CsvImportResultModel(
        imported: 8,
        updated: 2,
        skipped: 1,
        errors: [
          CsvRowErrorModel(row: 3, message: 'Invalid name', field: 'name'),
        ],
      );

      final json = model.toJson();

      expect(json['imported'], 8);
      expect(json['updated'], 2);
      expect(json['skipped'], 1);
      final errorsJson = json['errors'] as List;
      expect(errorsJson.length, 1);
      expect(errorsJson[0]['row'], 3);
      expect(errorsJson[0]['message'], 'Invalid name');
      expect(errorsJson[0]['field'], 'name');
    });
  });
}
