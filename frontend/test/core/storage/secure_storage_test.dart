import 'package:esouq/core/storage/in_memory_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemorySecureStorage', () {
    late InMemorySecureStorage storage;

    setUp(() {
      storage = InMemorySecureStorage();
    });

    test('writes and reads key-value pair', () async {
      await storage.write(key: 'token', value: 'jwt_123');
      final result = await storage.read(key: 'token');

      expect(result, equals('jwt_123'));
    });

    test('returns null for nonexistent key', () async {
      final result = await storage.read(key: 'nonexistent');
      expect(result, isNull);
    });

    test('containsKey returns true when present', () async {
      await storage.write(key: 'key1', value: 'val1');
      expect(await storage.containsKey(key: 'key1'), isTrue);
      expect(await storage.containsKey(key: 'key2'), isFalse);
    });

    test('delete removes specific key', () async {
      await storage.write(key: 'key1', value: 'val1');
      await storage.delete(key: 'key1');

      expect(await storage.read(key: 'key1'), isNull);
    });

    test('deleteAll clears all stored entries', () async {
      await storage.write(key: 'key1', value: 'val1');
      await storage.write(key: 'key2', value: 'val2');
      await storage.deleteAll();

      expect(await storage.read(key: 'key1'), isNull);
      expect(await storage.read(key: 'key2'), isNull);
    });
  });
}
