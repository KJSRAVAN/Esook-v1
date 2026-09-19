import 'package:esouq/core/utils/result.dart';
export 'package:esouq/core/utils/result.dart';
import 'cart_model.dart';

/// Contract for customer cart data operations matching backend endpoints.
abstract interface class CartRepository {
  /// Fetches the authenticated customer's active cart (GET /cart).
  Future<Result<CartModel>> getCart({String? storeId});

  /// Adds an item to the customer's cart (POST /cart/items).
  /// Enforces single-store rule on backend.
  Future<Result<CartModel>> addItem({
    required String itemId,
    required int quantity,
    String? storeId,
    String? productId,
  });

  /// Updates quantity of an existing item in the customer's cart (PATCH /cart/items/:itemId).
  /// Passing quantity = 0 removes the item.
  Future<Result<CartModel>> setItemQuantity({
    required String itemId,
    required int quantity,
    String? storeId,
    String? productId,
  });

  /// Removes an individual product from the customer's cart (PATCH /cart/items/:itemId with quantity 0).
  Future<Result<CartModel>> removeItem({
    required String itemId,
    String? storeId,
    String? productId,
  });

  /// Clears all items from the customer's cart (DELETE /cart).
  Future<Result<CartModel>> clearCart({String? storeId});
}
