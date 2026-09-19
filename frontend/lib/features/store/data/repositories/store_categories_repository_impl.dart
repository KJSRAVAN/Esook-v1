import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/store_category_model.dart';
import '../../domain/repositories/store_categories_repository.dart';

/// Concrete implementation of [StoreCategoriesRepository] interacting with `/stores/:storeId/categories`.
class StoreCategoriesRepositoryImpl implements StoreCategoriesRepository {
  final ApiClient? _apiClient;

  const StoreCategoriesRepositoryImpl({ApiClient? apiClient})
    : _apiClient = apiClient;

  @override
  Future<Result<List<StoreCategoryModel>>> getCategories(String storeId) async {
    final client = _apiClient;
    if (client == null) {
      return Result.success(const <StoreCategoryModel>[]);
    }

    try {
      final response = await client.get<dynamic>('/stores/$storeId/categories');
      final dynamic rawData = response.data;
      final List<dynamic> rawList;

      if (rawData is List) {
        rawList = rawData;
      } else if (rawData is Map<String, dynamic>) {
        rawList =
            (rawData['categories'] ?? rawData['data']) as List<dynamic>? ??
            const [];
      } else {
        rawList = const [];
      }

      final categories = rawList
          .whereType<Map<String, dynamic>>()
          .map(StoreCategoryModel.fromJson)
          .toList();

      return Result.success(categories);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to fetch categories: $e'),
      );
    }
  }

  @override
  Future<Result<StoreCategoryModel>> createCategory({
    required String storeId,
    required String name,
    int? sortOrder,
  }) async {
    final client = _apiClient;
    if (client == null) {
      return Result.failure(
        const ValidationFailure(message: 'ApiClient is required'),
      );
    }

    try {
      final body = <String, dynamic>{
        'name': name.trim(),
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final response = await client.post<dynamic>(
        '/stores/$storeId/categories',
        body: body,
      );

      final dynamic rawData = response.data;
      final Map<String, dynamic> rawCategory;
      if (rawData is Map<String, dynamic>) {
        rawCategory =
            (rawData['category'] ?? rawData['data'] ?? rawData)
                as Map<String, dynamic>;
      } else {
        rawCategory = const {};
      }

      return Result.success(StoreCategoryModel.fromJson(rawCategory));
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to create category: $e'),
      );
    }
  }
}
