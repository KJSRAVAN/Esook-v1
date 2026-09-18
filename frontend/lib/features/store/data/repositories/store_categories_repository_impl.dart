import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/store_category_model.dart';
import '../../domain/repositories/store_categories_repository.dart';

/// Concrete implementation of [StoreCategoriesRepository].
///
/// NOTE: The current backend has no categories endpoint or database table.
/// Categories are plain-text strings assigned directly to products.
/// This implementation safely avoids making calls to non-existent endpoints.
class StoreCategoriesRepositoryImpl implements StoreCategoriesRepository {
  const StoreCategoriesRepositoryImpl({ApiClient? apiClient});

  @override
  Future<Result<List<StoreCategoryModel>>> getCategories(String storeId) async {
    // Backend capability gap: There is no /stores/:storeId/categories endpoint.
    // Safe read-only empty list response without failing HTTP calls.
    return Result.success(const <StoreCategoryModel>[]);
  }

  @override
  Future<Result<StoreCategoryModel>> createCategory({
    required String storeId,
    required String name,
    int? sortOrder,
  }) async {
    // Backend capability gap: The backend does not support dedicated category entities.
    return Result.failure(
      const ValidationFailure(
        message: 'Category creation is not supported by the backend API. Categories are assigned directly to products.',
      ),
    );
  }
}
