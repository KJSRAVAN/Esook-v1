import 'package:esouq/core/error/exceptions.dart';
import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/features/customer/cart/domain/cart_model.dart';
import 'package:esouq/features/customer/cart/domain/cart_repository.dart';

/// Concrete [CartRepository] implementation communicating with backend /cart endpoints.
class CartRepositoryImpl implements CartRepository {
  final ApiClient _apiClient;

  const CartRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<Result<CartModel>> getCart({String? storeId}) async {
    try {
      final response = await _apiClient.get<dynamic>('/cart');
      final dynamic rawData = response.data;
      final Map<String, dynamic> rawCart;
      if (rawData is Map<String, dynamic>) {
        if (rawData['cart'] is Map<String, dynamic>) {
          rawCart = rawData['cart'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawCart = rawData['data'] as Map<String, dynamic>;
        } else {
          rawCart = rawData;
        }
      } else {
        rawCart = {};
      }

      final cart = CartModel.fromJson(rawCart);
      return Result.success(cart);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to fetch cart: $e'),
      );
    }
  }

  @override
  Future<Result<CartModel>> addItem({
    required String itemId,
    required int quantity,
    String? storeId,
    String? productId,
  }) async {
    try {
      final resolvedItemId = (itemId.isNotEmpty) ? itemId : (productId ?? '');
      final body = <String, dynamic>{
        'itemId': resolvedItemId,
        'quantity': quantity,
      };
      final response = await _apiClient.post<dynamic>(
        '/cart/items',
        body: body,
      );
      final dynamic rawData = response.data;
      final Map<String, dynamic> rawCart;
      if (rawData is Map<String, dynamic>) {
        if (rawData['cart'] is Map<String, dynamic>) {
          rawCart = rawData['cart'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawCart = rawData['data'] as Map<String, dynamic>;
        } else {
          rawCart = rawData;
        }
      } else {
        rawCart = {};
      }

      final cart = CartModel.fromJson(rawCart);
      return Result.success(cart);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to add item to cart: $e'),
      );
    }
  }

  @override
  Future<Result<CartModel>> setItemQuantity({
    required String itemId,
    required int quantity,
    String? storeId,
    String? productId,
  }) async {
    try {
      final resolvedItemId = (itemId.isNotEmpty) ? itemId : (productId ?? '');
      if (quantity <= 0) {
        return removeItem(
          itemId: resolvedItemId,
          storeId: storeId,
          productId: resolvedItemId,
        );
      }
      final body = <String, dynamic>{'quantity': quantity};
      final response = await _apiClient.patch<dynamic>(
        '/cart/items/$resolvedItemId',
        body: body,
      );
      final dynamic rawData = response.data;
      final Map<String, dynamic> rawCart;
      if (rawData is Map<String, dynamic>) {
        if (rawData['cart'] is Map<String, dynamic>) {
          rawCart = rawData['cart'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawCart = rawData['data'] as Map<String, dynamic>;
        } else {
          rawCart = rawData;
        }
      } else {
        rawCart = {};
      }

      final cart = CartModel.fromJson(rawCart);
      return Result.success(cart);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to update item quantity: $e'),
      );
    }
  }

  @override
  Future<Result<CartModel>> removeItem({
    required String itemId,
    String? storeId,
    String? productId,
  }) async {
    try {
      final resolvedItemId = (itemId.isNotEmpty) ? itemId : (productId ?? '');
      final response = await _apiClient.patch<dynamic>(
        '/cart/items/$resolvedItemId',
        body: {'quantity': 0},
      );
      final dynamic rawData = response.data;
      final Map<String, dynamic> rawCart;
      if (rawData is Map<String, dynamic>) {
        if (rawData['cart'] is Map<String, dynamic>) {
          rawCart = rawData['cart'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawCart = rawData['data'] as Map<String, dynamic>;
        } else {
          rawCart = rawData;
        }
      } else {
        rawCart = {};
      }

      final cart = CartModel.fromJson(rawCart);
      return Result.success(cart);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to remove item from cart: $e'),
      );
    }
  }

  @override
  Future<Result<CartModel>> clearCart({String? storeId}) async {
    try {
      await _apiClient.delete<dynamic>('/cart');
      return Result.success(CartModel.empty(storeId: storeId));
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to clear cart: $e'),
      );
    }
  }
}
