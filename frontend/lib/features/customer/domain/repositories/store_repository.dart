import '../../../../core/utils/result.dart';
import '../models/store_model.dart';

/// Contract for customer store discovery and retrieval.
abstract interface class StoreRepository {
  /// Fetches all active stores available for customer browsing.
  Future<Result<List<StoreModel>>> getStores();

  /// Fetches a specific store by its unique [id].
  Future<Result<StoreModel>> getStoreById(String id);

  /// Fetches the active store serving a specific geographical [area].
  Future<Result<StoreModel>> getStoreByArea(String area);
}
