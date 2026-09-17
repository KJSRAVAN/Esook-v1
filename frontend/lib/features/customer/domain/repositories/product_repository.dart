import '../../../../core/utils/result.dart';
export '../../../../core/utils/result.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

/// Contract for customer product catalog browsing and retrieval.
abstract interface class ProductRepository {
  /// Fetches items for a specific [storeId] matching optional query filters (GET /stores/:storeId/items).
  Future<Result<List<ProductModel>>> getProductsByStore(
    String storeId, {
    String? categoryId,
    String? search,
    bool? isAvailable,
    int? page,
    int? limit,
  });

  /// Fetches a specific item by its unique [id] and optional [storeId] (GET /stores/:storeId/items/:itemId).
  Future<Result<ProductModel>> getProductById(
    String id, {
    String? storeId,
  });

  /// Fetches categories for a specific [storeId] (GET /stores/:storeId/categories).
  Future<Result<List<CategoryModel>>> getCategories(String storeId);
}
