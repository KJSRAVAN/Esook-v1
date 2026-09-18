import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../../customer/domain/models/product_model.dart';
import '../../domain/repositories/store_products_repository.dart';

/// Concrete implementation of [StoreProductsRepository] interacting with `/products/store/:storeId` and `/products/:id`.
class StoreProductsRepositoryImpl implements StoreProductsRepository {
  final ApiClient _apiClient;

  const StoreProductsRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<List<ProductModel>>> getStoreProducts(String storeId) async {
    try {
      final response = await _apiClient.get<dynamic>('/products/store/$storeId');

      final dynamic rawData = response.data;
      final List<dynamic> rawList;

      if (rawData is Map<String, dynamic>) {
        if (rawData['products'] is List) {
          rawList = rawData['products'] as List;
        } else if (rawData['items'] is List) {
          rawList = rawData['items'] as List;
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

      final products = rawList
          .whereType<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList();

      return Result.success(products);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to fetch store items: $e'));
    }
  }

  @override
  Future<Result<ProductModel>> createProduct({
    required String storeId,
    required String name,
    String? description,
    required double price,
    String? categoryId,
    String? category,
    String? imageUrl,
    int? sortOrder,
  }) async {
    try {
      final catString = category ?? categoryId;
      final body = <String, dynamic>{
        'store_id': storeId,
        'name': name.trim(),
        'price': price,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (catString != null && catString.trim().isNotEmpty)
          'category': catString.trim(),
        if (imageUrl != null && imageUrl.trim().isNotEmpty)
          'image_url': imageUrl.trim(),
        'is_available': true,
      };

      final response = await _apiClient.post<dynamic>(
        '/products',
        body: body,
      );

      final dynamic rawData = response.data;
      final Map<String, dynamic> rawItem;

      if (rawData is Map<String, dynamic>) {
        if (rawData['product'] is Map<String, dynamic>) {
          rawItem = rawData['product'] as Map<String, dynamic>;
        } else if (rawData['item'] is Map<String, dynamic>) {
          rawItem = rawData['item'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawItem = rawData['data'] as Map<String, dynamic>;
        } else {
          rawItem = rawData;
        }
      } else {
        rawItem = const {};
      }

      final product = ProductModel.fromJson(rawItem);
      return Result.success(product);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to create item: $e'));
    }
  }

  @override
  Future<Result<ProductModel>> updateProduct({
    required String storeId,
    required String productId,
    String? name,
    String? description,
    double? price,
    String? categoryId,
    String? category,
    String? imageUrl,
    int? sortOrder,
    bool? isAvailable,
  }) async {
    try {
      final catString = category ?? categoryId;
      final body = <String, dynamic>{
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (description != null) 'description': description.trim(),
        if (price != null) 'price': price,
        if (catString != null && catString.trim().isNotEmpty)
          'category': catString.trim(),
        if (imageUrl != null)
          'image_url': imageUrl.trim(),
        if (isAvailable != null)
          'is_available': isAvailable,
      };

      final response = await _apiClient.patch<dynamic>(
        '/products/$productId',
        body: body,
      );

      final dynamic rawData = response.data;
      final Map<String, dynamic> rawItem;

      if (rawData is Map<String, dynamic>) {
        if (rawData['product'] is Map<String, dynamic>) {
          rawItem = rawData['product'] as Map<String, dynamic>;
        } else if (rawData['item'] is Map<String, dynamic>) {
          rawItem = rawData['item'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawItem = rawData['data'] as Map<String, dynamic>;
        } else {
          rawItem = rawData;
        }
      } else {
        rawItem = const {};
      }

      final product = ProductModel.fromJson(rawItem);
      return Result.success(product);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to update item: $e'));
    }
  }

  @override
  Future<Result<ProductModel>> toggleAvailability({
    required String storeId,
    required String productId,
    required bool isAvailable,
  }) async {
    return updateProduct(
      storeId: storeId,
      productId: productId,
      isAvailable: isAvailable,
    );
  }

  @override
  Future<Result<void>> deleteProduct({
    required String storeId,
    required String productId,
  }) async {
    try {
      await _apiClient.delete<dynamic>('/products/$productId');
      return Result.success(null);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to delete item: $e'));
    }
  }
}
