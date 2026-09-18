import '../../../../core/utils/result.dart';
import '../models/admin_area_model.dart';
import '../models/admin_store_model.dart';

/// Contract for Admin Store Management repository.
abstract interface class AdminStoresRepository {
  /// List all stores.
  /// Backend endpoint: `GET /stores`
  Future<Result<List<AdminStoreModel>>> getStores();

  /// List delivery areas (kept for backward compatibility; backend stores area as string on stores).
  Future<Result<List<AdminAreaModel>>> getAreas();

  /// Create a new store.
  /// Backend endpoint: `POST /stores`
  /// Payload: `{ name, area, address?, phone_number?, is_active? }`
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
  /// Payload: `{ name?, area?, address?, phone_number?, is_active? }`
  Future<Result<AdminStoreModel>> updateStore({
    required String storeId,
    String? name,
    String? area,
    String? address,
    String? phone,
    bool? isActive,
  });
}
