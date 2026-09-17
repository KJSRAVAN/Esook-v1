import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/store_category_model.dart';
import '../../domain/repositories/store_categories_repository.dart';

/// Concrete implementation of [StoreCategoriesRepository] interacting with `/stores/:storeId/categories`.
class StoreCategoriesRepositoryImpl implements StoreCategoriesRepository {
  final ApiClient _apiClient;

  const StoreCategoriesRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<List<StoreCategoryModel>>> getCategories(String storeId) async {
    try {
      final response = await _apiClient.get<dynamic>('/stores/$storeId/categories');

      final dynamic rawData = response.data;
      final List<dynamic> rawList;

      if (rawData is Map<String, dynamic>) {
        if (rawData['categories'] is List) {
          rawList = rawData['categories'] as List;
        } else if (rawData['data'] is List) {
          rawList = rawData['data'] as List;
        } else {
          rawList = const [];
        }
      } else if (rawData is List) {
        rawList = rawData;
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
      return Result.failure(UnknownFailure(message: 'Failed to fetch store categories: $e'));
    }
  }

  @override
  Future<Result<StoreCategoryModel>> createCategory({
    required String storeId,
    required String name,
    int? sortOrder,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name.trim(),
        if (sortOrder != null) ...{
          'sortOrder': sortOrder,
          'sort_order': sortOrder,
        },
      };

      final response = await _apiClient.post<dynamic>(
        '/stores/$storeId/categories',
        body: body,
      );

      final dynamic rawData = response.data;
      final Map<String, dynamic> rawCat;

      if (rawData is Map<String, dynamic>) {
        if (rawData['category'] is Map<String, dynamic>) {
          rawCat = rawData['category'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawCat = rawData['data'] as Map<String, dynamic>;
        } else {
          rawCat = rawData;
        }
      } else {
        rawCat = const {};
      }

      final category = StoreCategoryModel.fromJson(rawCat);
      return Result.success(category);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to create category: $e'));
    }
  }
}
