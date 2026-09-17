import '../../../../core/utils/result.dart';
import '../models/rider_order_model.dart';

/// Domain contract for rider delivery operations.
///
/// Maps exactly to the 4 driver endpoints on origin/Prod_Backend:
/// - GET  /drivers/orders/available
/// - GET  /drivers/orders/active
/// - POST /drivers/orders/:orderId/accept
/// - PATCH /drivers/orders/:orderId/status
abstract interface class RiderRepository {
  /// Fetch all READY DELIVERY orders with no driver assigned.
  /// Platform-wide, not store-scoped.
  Future<Result<List<RiderOrderModel>>> getAvailableOrders();

  /// Fetch the driver's single active in-progress order (if any).
  /// Returns null data when no active delivery exists.
  Future<Result<RiderOrderModel?>> getActiveOrder();

  /// Self-assign an available READY DELIVERY order.
  /// Atomically claims the order and sets status to OUT_FOR_DELIVERY.
  ///
  /// Backend errors:
  /// - 409 DRIVER_BUSY: driver already has an active delivery
  /// - 409 ORDER_UNAVAILABLE: order was claimed by another driver
  /// - 404: order not found
  /// - 400 NOT_DELIVERY: order is a PICKUP order
  Future<Result<RiderOrderModel>> acceptOrder(String orderId);

  /// Mark an active delivery as DELIVERED.
  /// Only valid transition: OUT_FOR_DELIVERY → DELIVERED.
  ///
  /// Backend errors:
  /// - 403: order is assigned to a different driver
  /// - 404: order not found
  /// - 400 INVALID_TRANSITION: order is not in OUT_FOR_DELIVERY status
  Future<Result<RiderOrderModel>> markDelivered(String orderId);
}
