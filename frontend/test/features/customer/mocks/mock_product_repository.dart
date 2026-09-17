import 'package:esouq/features/customer/domain/models/category_model.dart';
import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:esouq/features/customer/domain/repositories/product_repository.dart';

class MockProductRepository implements ProductRepository {
  Result<List<ProductModel>>? getProductsByStoreResult;
  Result<ProductModel>? getProductByIdResult;
  Result<List<CategoryModel>>? getCategoriesResult;

  int getProductsByStoreCallCount = 0;
  int getProductByIdCallCount = 0;
  int getCategoriesCallCount = 0;

  String? lastStoreIdParam;
  String? lastProductIdParam;
  String? lastGetCategoriesStoreIdParam;
  String? lastCategoryIdParam;
  String? lastSearchParam;
  bool? lastIsAvailableParam;
  int? lastPageParam;
  int? lastLimitParam;

  List<ProductModel> defaultProducts = [
    const ProductModel(
      id: 'prod-1',
      storeId: 'store-1',
      categoryId: 'cat-1',
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
      categoryId: 'cat-2',
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
      categoryId: 'cat-1',
      name: 'Greek Yogurt 500g',
      description: 'Thick plain Greek yogurt',
      price: 2.10,
      category: 'Dairy & Eggs',
      imageUrl: null,
      isAvailable: false,
      loyaltyPointsPerUnit: 4,
    ),
  ];

  List<CategoryModel> defaultCategories = [
    const CategoryModel(
      id: 'cat-1',
      storeId: 'store-1',
      name: 'Dairy & Eggs',
      sortOrder: 0,
      itemCount: 2,
    ),
    const CategoryModel(
      id: 'cat-2',
      storeId: 'store-1',
      name: 'Fresh Produce',
      sortOrder: 1,
      itemCount: 1,
    ),
  ];

  @override
  Future<Result<List<ProductModel>>> getProductsByStore(
    String storeId, {
    String? categoryId,
    String? search,
    bool? isAvailable,
    int? page,
    int? limit,
  }) async {
    getProductsByStoreCallCount++;
    lastStoreIdParam = storeId;
    lastCategoryIdParam = categoryId;
    lastSearchParam = search;
    lastIsAvailableParam = isAvailable;
    lastPageParam = page;
    lastLimitParam = limit;

    if (getProductsByStoreResult != null) return getProductsByStoreResult!;
    return Result.success(defaultProducts);
  }

  @override
  Future<Result<ProductModel>> getProductById(
    String id, {
    String? storeId,
  }) async {
    getProductByIdCallCount++;
    lastProductIdParam = id;
    lastStoreIdParam = storeId;
    if (getProductByIdResult != null) return getProductByIdResult!;
    final match = defaultProducts.firstWhere(
      (p) => p.id == id,
      orElse: () => defaultProducts.first,
    );
    return Result.success(match);
  }

  @override
  Future<Result<List<CategoryModel>>> getCategories(String storeId) async {
    getCategoriesCallCount++;
    lastGetCategoriesStoreIdParam = storeId;
    if (getCategoriesResult != null) return getCategoriesResult!;
    return Result.success(defaultCategories);
  }
}
