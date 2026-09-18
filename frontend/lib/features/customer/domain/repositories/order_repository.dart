import '../../../../core/utils/result.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';

/// Abstract contract for customer order operations.
abstract class OrderRepository {
  /// Places a new order matching the backend POST /orders contract.
  Future<Result<OrderModel>> createOrder({
    required String storeId,
    required FulfillmentType fulfillment,
    String? deliveryAddress,
    String? couponCode,
    String? notes,
    required List<OrderItemInput> items,
    String? idempotencyKey,
  });

  /// Retrieves the authenticated customer's orders matching GET /orders.
  Future<Result<List<OrderModel>>> getMyOrders({
    int? page,
    int? limit,
    OrderStatus? status,
  });

  /// Retrieves detailed information for a single order matching GET /orders/:orderId.
  Future<Result<OrderModel>> getOrderById(String orderId);
}
