import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:esouq/features/customer/domain/repositories/product_repository.dart';

class MockProductRepository implements ProductRepository {
  Result<List<ProductModel>>? getProductsByStoreResult;
  Result<ProductModel>? getProductByIdResult;

  int getProductsByStoreCallCount = 0;
  int getProductByIdCallCount = 0;

  String? lastStoreIdParam;
  String? lastProductIdParam;

  List<ProductModel> defaultProducts = [
    const ProductModel(
      id: 'prod-1',
      storeId: 'store-1',
      name: 'Fresh Whole Milk 1L',
      description: 'Pure local cow milk',
      price: 1.25,
      category: 'Dairy & Eggs',
      imageUrl: 'https://example.com/milk.png',
      isAvailable: true,
      loyaltyPointsPerUnit: 5,
    ),
    const ProductModel(
      id: 'prod-2',
      storeId: 'store-1',
      name: 'Organic Bananas 1kg',
      description: 'Fresh yellow Cavendish bananas',
      price: 0.85,
      category: 'Fresh Produce',
      imageUrl: null,
      isAvailable: true,
      loyaltyPointsPerUnit: 2,
    ),
    const ProductModel(
      id: 'prod-3',
      storeId: 'store-1',
      name: 'Greek Yogurt 500g',
      description: 'Thick plain Greek yogurt',
      price: 2.10,
      category: 'Dairy & Eggs',
      imageUrl: null,
      isAvailable: false,
      loyaltyPointsPerUnit: 4,
    ),
  ];

  @override
  Future<Result<List<ProductModel>>> getProductsByStore(String storeId) async {
    getProductsByStoreCallCount++;
    lastStoreIdParam = storeId;
    if (getProductsByStoreResult != null) return getProductsByStoreResult!;
    return Result.success(defaultProducts);
  }

  @override
  Future<Result<ProductModel>> getProductById(String id) async {
    getProductByIdCallCount++;
    lastProductIdParam = id;
    if (getProductByIdResult != null) return getProductByIdResult!;
    final match = defaultProducts.firstWhere(
      (p) => p.id == id,
      orElse: () => defaultProducts.first,
    );
    return Result.success(match);
  }
}
