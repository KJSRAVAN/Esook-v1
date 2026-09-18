import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/product_model.dart';
import '../../domain/repositories/product_repository.dart';

/// Concrete [ProductRepository] implementation communicating with backend catalog endpoints.
class ProductRepositoryImpl implements ProductRepository {
  final ApiClient _apiClient;

  const ProductRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

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
        if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
        if (search != null && search.isNotEmpty) 'search': search,
        if (isAvailable != null) 'available': isAvailable ? 'true' : 'false',
        if (page != null) 'page': page,
        if (limit != null) 'limit': limit,
      };

      final response = await _apiClient.get<dynamic>(
        '/products/store/$storeId',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final dynamic rawData = response.data;
      final List<dynamic> rawList;
      if (rawData is List) {
        rawList = rawData;
      } else if (rawData is Map<String, dynamic>) {
        rawList = (rawData['data'] ??
                rawData['items'] ??
                rawData['products']) as List<dynamic>? ??
            [];
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
      return Result.failure(UnknownFailure(message: 'Failed to fetch items for store $storeId: $e'));
    }
  }

  @override
  Future<Result<ProductModel>> getProductById(
    String id, {
    String? storeId,
  }) async {
    try {
      final response = await _apiClient.get<dynamic>('/products/$id');
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
      return Result.failure(UnknownFailure(message: 'Failed to fetch item $id: $e'));
    }
  }

  @override
  Future<Result<List<CategoryModel>>> getCategories(String storeId) async {
    try {
      final productsResult = await getProductsByStore(storeId);
      if (productsResult.isFailure) {
        return Result.failure(productsResult.failureOrNull!);
      }

      final products = productsResult.dataOrNull ?? [];
      final categoryCounts = <String, int>{};

      for (final product in products) {
        if (product.category != null && product.category!.trim().isNotEmpty) {
          final catName = product.category!.trim();
          categoryCounts[catName] = (categoryCounts[catName] ?? 0) + 1;
        }
      }

      final categories = categoryCounts.entries.map((entry) {
        return CategoryModel(
          id: entry.key,
          storeId: storeId,
          name: entry.key,
          itemCount: entry.value,
        );
      }).toList();

      return Result.success(categories);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to fetch categories for store $storeId: $e'));
    }
  }
}
