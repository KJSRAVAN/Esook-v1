import 'package:esouq/core/error/exceptions.dart';
import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/features/customer/cart/domain/cart_model.dart';
import 'package:esouq/features/customer/cart/domain/cart_repository.dart';

/// Concrete [CartRepository] implementation communicating with backend /cart endpoints.
class CartRepositoryImpl implements CartRepository {
  final ApiClient _apiClient;

  const CartRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<CartModel>> getCart({String? storeId}) async {
    try {
      final queryParams = <String, dynamic>{
        if (storeId != null && storeId.isNotEmpty) 'store_id': storeId,
      };
      final response = await _apiClient.get<dynamic>(
        '/cart',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
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
      return Result.failure(UnknownFailure(message: 'Failed to fetch cart: $e'));
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
      final resolvedProductId = (productId != null && productId.isNotEmpty)
          ? productId
          : itemId;
      final body = <String, dynamic>{
        if (storeId != null && storeId.isNotEmpty) 'store_id': storeId,
        'product_id': resolvedProductId,
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
      return Result.failure(UnknownFailure(message: 'Failed to add item to cart: $e'));
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
      final resolvedProductId = (productId != null && productId.isNotEmpty)
          ? productId
          : itemId;
      if (quantity <= 0) {
        return removeItem(
          itemId: resolvedProductId,
          storeId: storeId,
          productId: resolvedProductId,
        );
      }
      final body = <String, dynamic>{
        if (storeId != null && storeId.isNotEmpty) 'store_id': storeId,
        'quantity': quantity,
      };
      final response = await _apiClient.patch<dynamic>(
        '/cart/items/$resolvedProductId',
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
      return Result.failure(UnknownFailure(message: 'Failed to update item quantity: $e'));
    }
  }

  @override
  Future<Result<CartModel>> removeItem({
    required String itemId,
    String? storeId,
    String? productId,
  }) async {
    try {
      final resolvedProductId = (productId != null && productId.isNotEmpty)
          ? productId
          : itemId;
      final queryParams = <String, dynamic>{
        if (storeId != null && storeId.isNotEmpty) 'store_id': storeId,
      };
      final response = await _apiClient.delete<dynamic>(
        '/cart/items/$resolvedProductId',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
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
      return Result.failure(UnknownFailure(message: 'Failed to remove item from cart: $e'));
    }
  }

  @override
  Future<Result<CartModel>> clearCart({String? storeId}) async {
    try {
      final queryParams = <String, dynamic>{
        if (storeId != null && storeId.isNotEmpty) 'store_id': storeId,
      };
      await _apiClient.delete<dynamic>(
        '/cart',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      return Result.success(CartModel.empty(storeId: storeId));
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to clear cart: $e'));
    }
  }
}
