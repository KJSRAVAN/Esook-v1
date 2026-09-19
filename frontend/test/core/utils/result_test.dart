import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Success stores data and reports isSuccess', () {
      final result = Result.success('test_data');

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, equals('test_data'));
      expect(result.failureOrNull, isNull);

      final folded = result.fold(
        onSuccess: (data) => 'got $data',
        onFailure: (_) => 'error',
      );
      expect(folded, equals('got test_data'));
    });

    test('Failure stores failure and reports isFailure', () {
      const failure = NetworkFailure(
        message: 'Connection failed',
        statusCode: null,
      );
      final result = Result<String>.failure(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, equals(failure));

      final folded = result.fold(
        onSuccess: (data) => 'success',
        onFailure: (f) => 'failed: ${f.message}',
      );
      expect(folded, equals('failed: Connection failed'));
    });
  });
}
