import '../../../../core/utils/result.dart';
import '../models/store_category_model.dart';

/// Repository interface for Store Categories.
abstract interface class StoreCategoriesRepository {
  /// List categories for a given store (`GET /stores/:storeId/categories`).
  Future<Result<List<StoreCategoryModel>>> getCategories(String storeId);

  /// Create a new category for a store (`POST /stores/:storeId/categories`).
  /// Permitted for Store Manager and Super Admin.
  Future<Result<StoreCategoryModel>> createCategory({
    required String storeId,
    required String name,
    int? sortOrder,
  });
}
