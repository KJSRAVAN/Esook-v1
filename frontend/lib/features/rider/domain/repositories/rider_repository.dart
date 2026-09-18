import '../../../../core/utils/result.dart';
import '../models/rider_order_model.dart';

/// Domain contract for rider delivery operations.
///
/// Communicates with production backend order endpoints:
/// - GET   /orders (scoped to authenticated rider's store)
/// - PATCH /orders/:id/status
abstract interface class RiderRepository {
  /// Fetch all DELIVERY orders in `preparing` status ready for delivery
  /// for the authenticated rider's store.
  Future<Result<List<RiderOrderModel>>> getAvailableOrders();

  /// Fetch the driver's active in-progress delivery order (`out_for_delivery`).
  /// Returns null data when no active delivery exists.
  Future<Result<RiderOrderModel?>> getActiveOrder();

  /// Start delivery for an order (transitions from `preparing` -> `out_for_delivery`).
  ///
  /// Sends PATCH /orders/:id/status with `{ "status": "out_for_delivery" }`.
  Future<Result<RiderOrderModel>> acceptOrder(String orderId);

  /// Mark an active delivery as completed (transitions from `out_for_delivery` -> `completed`).
  ///
  /// Sends PATCH /orders/:id/status with `{ "status": "completed" }`.
  Future<Result<RiderOrderModel>> markDelivered(String orderId);
}
