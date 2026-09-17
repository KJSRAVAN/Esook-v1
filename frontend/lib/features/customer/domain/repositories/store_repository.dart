import '../../../../core/utils/result.dart';
export '../../../../core/utils/result.dart';
import '../models/area_model.dart';
import '../models/store_model.dart';

/// Contract for customer store discovery and retrieval.
abstract interface class StoreRepository {
  /// Fetches all active stores available for customer browsing (GET /stores).
  Future<Result<List<StoreModel>>> getStores();

  /// Fetches all delivery areas (GET /stores/areas).
  Future<Result<List<AreaModel>>> getAreas();

  /// Fetches a specific store by its unique [id] (GET /stores/:storeId).
  Future<Result<StoreModel>> getStoreById(String id);
}
