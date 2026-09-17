import '../../../../core/utils/result.dart';
import '../../../customer/domain/models/order_model.dart';

/// Repository interface for Store Order operations.
/// All queries are explicitly scoped to the store using the production contract.
abstract interface class StoreOrdersRepository {
  /// Fetch orders for a specific store (`GET /orders/store/:storeId`).
  Future<Result<List<OrderModel>>> getStoreOrders({
    required String storeId,
    String? status,
    int page = 1,
    int limit = 50,
  });

  /// Retrieve a specific order by ID (`GET /orders/:id`).
  Future<Result<OrderModel>> getOrderById(String orderId);

  /// Update order status (`PATCH /orders/:orderId/status`).
  Future<Result<OrderModel>> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    String? rejectedReason,
  });
}
