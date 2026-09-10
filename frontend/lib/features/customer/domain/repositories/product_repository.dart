import '../../../../core/utils/result.dart';
import '../models/product_model.dart';

/// Contract for customer product catalog browsing and retrieval.
abstract interface class ProductRepository {
  /// Fetches the complete active product catalog for a specific [storeId].
  Future<Result<List<ProductModel>>> getProductsByStore(String storeId);

  /// Fetches a specific available product by its unique [id].
  Future<Result<ProductModel>> getProductById(String id);
}
