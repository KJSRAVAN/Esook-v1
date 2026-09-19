import '../../../../core/utils/result.dart';
import '../models/admin_area_model.dart';
import '../models/admin_store_model.dart';

/// Contract for Admin Store Management repository.
abstract interface class AdminStoresRepository {
  /// List all stores.
  /// Backend endpoint: `GET /stores`
  Future<Result<List<AdminStoreModel>>> getStores();

  /// List delivery areas.
  /// Backend endpoint: `GET /stores/areas`
  Future<Result<List<AdminAreaModel>>> getAreas();

  /// Create a new store.
  /// Backend endpoint: `POST /stores`
  /// Payload: `{ name, areaId, address?, phone? }`
  Future<Result<AdminStoreModel>> createStore({
    required String name,
    String? area,
    String? areaId,
    String? address,
    String? phone,
    bool? isActive,
  });

  /// Update existing store details.
  /// Backend endpoint: `PATCH /stores/:storeId`
  /// Payload: `{ name?, areaId?, address?, phone?, isActive? }`
  Future<Result<AdminStoreModel>> updateStore({
    required String storeId,
    String? name,
    String? area,
    String? address,
    String? phone,
    bool? isActive,
  });
}
