import 'package:esouq/core/error/failures.dart';
import 'package:esouq/features/customer/cart/domain/cart_item_model.dart';
import 'package:esouq/features/customer/cart/domain/cart_model.dart';
import 'package:esouq/features/customer/cart/domain/cart_repository.dart';

class MockCartRepository implements CartRepository {
  CartModel? cartToReturn;
  AppFailure? failureToReturn;
  Future<Result<CartModel>> Function(String? storeId)? customGetCartHandler;
  Future<Result<CartModel>> Function(String? storeId)? customClearCartHandler;

  int getCartCallCount = 0;
  int addItemCallCount = 0;
  int setItemQuantityCallCount = 0;
  int removeItemCallCount = 0;
  int clearCartCallCount = 0;

  String? lastStoreIdParam;
  String? lastItemIdParam;
  String? lastProductIdParam;
  int? lastQuantityParam;

  CartModel get defaultCart => const CartModel(
        userId: 'usr-123',
        storeId: 'store-1',
        store: CartStoreRef(
          id: 'store-1',
          name: 'eSOuQ Olaya Flagship',
          area: 'Olaya',
          isActive: true,
        ),
        items: [
          CartItemModel(
            itemId: 'prod-1',
            productId: 'prod-1',
            name: 'Fresh Whole Milk 1L',
            productName: 'Fresh Whole Milk 1L',
            price: 1.25,
            unitPrice: 1.25,
            imageUrl: null,
            isAvailable: true,
            loyaltyPointsPerUnit: 5,
            quantity: 2,
          ),
          CartItemModel(
            itemId: 'prod-2',
            productId: 'prod-2',
            name: 'Organic Bananas 1kg',
            productName: 'Organic Bananas 1kg',
            price: 0.85,
            unitPrice: 0.85,
            imageUrl: null,
            isAvailable: true,
            loyaltyPointsPerUnit: 2,
            quantity: 1,
          ),
        ],
        subtotal: 3.35,
      );

  @override
  Future<Result<CartModel>> getCart({String? storeId}) async {
    getCartCallCount++;
    lastStoreIdParam = storeId;

    if (customGetCartHandler != null) {
      return customGetCartHandler!(storeId);
    }

    if (failureToReturn != null) {
      return Result.failure(failureToReturn!);
    }
    return Result.success(cartToReturn ?? defaultCart);
  }

  @override
  Future<Result<CartModel>> addItem({
    required String itemId,
    required int quantity,
    String? storeId,
    String? productId,
  }) async {
    addItemCallCount++;
    lastStoreIdParam = storeId;
    lastItemIdParam = itemId;
    lastProductIdParam = productId ?? itemId;
    lastQuantityParam = quantity;

    if (failureToReturn != null) {
      return Result.failure(failureToReturn!);
    }
    return Result.success(cartToReturn ?? defaultCart);
  }

  @override
  Future<Result<CartModel>> setItemQuantity({
    required String itemId,
    required int quantity,
    String? storeId,
    String? productId,
  }) async {
    setItemQuantityCallCount++;
    lastStoreIdParam = storeId;
    lastItemIdParam = itemId;
    lastProductIdParam = productId ?? itemId;
    lastQuantityParam = quantity;

    if (failureToReturn != null) {
      return Result.failure(failureToReturn!);
    }
    return Result.success(cartToReturn ?? defaultCart);
  }

  @override
  Future<Result<CartModel>> removeItem({
    required String itemId,
    String? storeId,
    String? productId,
  }) async {
    removeItemCallCount++;
    lastStoreIdParam = storeId;
    lastItemIdParam = itemId;
    lastProductIdParam = productId ?? itemId;

    if (failureToReturn != null) {
      return Result.failure(failureToReturn!);
    }
    return Result.success(cartToReturn ?? defaultCart);
  }

  @override
  Future<Result<CartModel>> clearCart({String? storeId}) async {
    clearCartCallCount++;
    lastStoreIdParam = storeId;

    if (failureToReturn != null) {
      return Result.failure(failureToReturn!);
    }
    return Result.success(
      cartToReturn ??
          CartModel.empty(
            storeId: storeId ?? 'store-1',
            store: const CartStoreRef(
              id: 'store-1',
              name: 'eSOuQ Olaya Flagship',
              area: 'Olaya',
              isActive: true,
            ),
          ),
    );
  }
}
