import '../../../../core/utils/result.dart';
import '../../../customer/domain/models/product_model.dart';

/// Repository interface for Store Item/Product catalog operations.
abstract interface class StoreProductsRepository {
  /// List items for a given store (`GET /stores/:storeId/items`).
  Future<Result<List<ProductModel>>> getStoreProducts(String storeId);

  /// Create a new item for a store (`POST /stores/:storeId/items`).
  /// Permitted for Store Manager and Super Admin.
  Future<Result<ProductModel>> createProduct({
    required String storeId,
    required String name,
    String? description,
    required double price,
    String? categoryId,
    String? imageUrl,
    int? sortOrder,
  });

  /// Update an existing item (`PATCH /stores/:storeId/items/:itemId`).
  /// Permitted for Store Manager and Super Admin.
  Future<Result<ProductModel>> updateProduct({
    required String storeId,
    required String productId,
    String? name,
    String? description,
    double? price,
    String? categoryId,
    String? imageUrl,
    int? sortOrder,
    bool? isAvailable,
  });

  /// Quick toggle of item availability (`PATCH /stores/:storeId/items/:itemId`).
  Future<Result<ProductModel>> toggleAvailability({
    required String storeId,
    required String productId,
    required bool isAvailable,
  });

  /// Delete an item from store (`DELETE /stores/:storeId/items/:itemId`).
  /// Super Admin only; not permitted for standard store staff or manager.
  Future<Result<void>> deleteProduct({
    required String storeId,
    required String productId,
  });
}
