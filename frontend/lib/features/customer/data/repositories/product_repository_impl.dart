import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/product_model.dart';
import '../../domain/repositories/product_repository.dart';

/// Concrete [ProductRepository] implementation communicating with backend catalog endpoints.
class ProductRepositoryImpl implements ProductRepository {
  final ApiClient _apiClient;

  const ProductRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<Result<List<ProductModel>>> getProductsByStore(
    String storeId, {
    String? categoryId,
    String? search,
    bool? isAvailable,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
        if (search != null && search.isNotEmpty) 'search': search,
        if (isAvailable != null) 'available': isAvailable ? 'true' : 'false',
        if (page != null) 'page': page,
        if (limit != null) 'limit': limit,
      };

      final response = await _apiClient.get<dynamic>(
        '/stores/$storeId/items',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final dynamic rawData = response.data;
      final List<dynamic> rawList;
      if (rawData is Map<String, dynamic> && rawData['data'] is List) {
        rawList = rawData['data'] as List<dynamic>;
      } else if (rawData is List) {
        rawList = rawData;
      } else if (rawData is Map<String, dynamic>) {
        rawList =
            (rawData['items'] ?? rawData['products']) as List<dynamic>? ?? [];
      } else {
        rawList = [];
      }

      final products = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => ProductModel.fromJson(item))
          .toList();
      return Result.success(products);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to fetch items for store $storeId: $e'),
      );
    }
  }

  @override
  Future<Result<ProductModel>> getProductById(
    String id, {
    String? storeId,
  }) async {
    try {
      if (storeId == null || storeId.isEmpty) {
        return Result.failure(
          const ValidationFailure(
            message: 'storeId is required to fetch store item.',
          ),
        );
      }

      final response = await _apiClient.get<dynamic>(
        '/stores/$storeId/items/$id',
      );
      final dynamic rawData = response.data;
      final Map<String, dynamic> rawProduct;
      if (rawData is Map<String, dynamic>) {
        if (rawData['data'] is Map<String, dynamic>) {
          rawProduct = rawData['data'] as Map<String, dynamic>;
        } else if (rawData['item'] is Map<String, dynamic>) {
          rawProduct = rawData['item'] as Map<String, dynamic>;
        } else if (rawData['product'] is Map<String, dynamic>) {
          rawProduct = rawData['product'] as Map<String, dynamic>;
        } else {
          rawProduct = rawData;
        }
      } else {
        rawProduct = {};
      }

      final product = ProductModel.fromJson(rawProduct);
      return Result.success(product);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to fetch item $id: $e'),
      );
    }
  }

  @override
  Future<Result<List<CategoryModel>>> getCategories(String storeId) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/stores/$storeId/categories',
      );
      final dynamic rawData = response.data;
      final List<dynamic> rawList;
      if (rawData is List) {
        rawList = rawData;
      } else if (rawData is Map<String, dynamic>) {
        rawList =
            (rawData['categories'] ?? rawData['data']) as List<dynamic>? ?? [];
      } else {
        rawList = [];
      }

      final categories = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => CategoryModel.fromJson(item))
          .toList();

      return Result.success(categories);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(
          message: 'Failed to fetch categories for store $storeId: $e',
        ),
      );
    }
  }
}
