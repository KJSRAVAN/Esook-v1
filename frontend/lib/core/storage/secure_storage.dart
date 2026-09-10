/// Contract for secure local key-value storage.
abstract interface class SecureStorage {
  Future<void> write({required String key, required String value});

  Future<String?> read({required String key});

  Future<void> delete({required String key});

  Future<void> deleteAll();

  Future<bool> containsKey({required String key});
}
