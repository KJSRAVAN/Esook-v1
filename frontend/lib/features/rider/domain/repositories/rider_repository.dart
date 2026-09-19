import '../../../../core/utils/result.dart';
import '../models/rider_order_model.dart';

/// Domain contract for rider delivery operations.
///
/// Communicates with Railway backend driver endpoints:
/// - GET   /drivers/orders/available
/// - GET   /drivers/orders/active
/// - POST  /drivers/orders/:orderId/accept
/// - PATCH /drivers/orders/:orderId/status
abstract interface class RiderRepository {
  /// Fetch all available DELIVERY orders ready for pickup (GET /drivers/orders/available).
  Future<Result<List<RiderOrderModel>>> getAvailableOrders();

  /// Fetch the driver's active in-progress delivery order (GET /drivers/orders/active).
  /// Returns null data when no active delivery exists.
  Future<Result<RiderOrderModel?>> getActiveOrder();

  /// Accept (self-assign) an available order (POST /drivers/orders/:orderId/accept).
  /// Automatically transitions order status to OUT_FOR_DELIVERY.
  Future<Result<RiderOrderModel>> acceptOrder(String orderId);

  /// Mark an active delivery as delivered (PATCH /drivers/orders/:orderId/status with { "status": "DELIVERED" }).
  Future<Result<RiderOrderModel>> markDelivered(String orderId);
}
