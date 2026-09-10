import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/product_model.dart';
import '../../domain/repositories/product_repository.dart';

/// Concrete [ProductRepository] implementation communicating with eSOuQ backend product endpoints.
class ProductRepositoryImpl implements ProductRepository {
  final ApiClient _apiClient;

  const ProductRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<List<ProductModel>>> getProductsByStore(String storeId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/products/store/$storeId');
      final rawList = response.data['products'] as List<dynamic>? ?? [];
      final products = rawList
          .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return Result.success(products);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to fetch products for store $storeId: $e'));
    }
  }

  @override
  Future<Result<ProductModel>> getProductById(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/products/$id');
      final rawProduct = response.data['product'] as Map<String, dynamic>? ?? {};
      final product = ProductModel.fromJson(rawProduct);
      return Result.success(product);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to fetch product $id: $e'));
    }
  }
}
