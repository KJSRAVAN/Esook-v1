import '../../../../core/utils/result.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';

/// Information about a customer's loyalty points at a specific store.
class CustomerPointsInfo {
  final bool isEnabled;
  final double pointsPerCurrencyUnit;
  final int balance;
  final int minPointsToRedeem;
  final double maxDiscountPercent;
  final int? maxPointsPerOrder;
  final double pointsEarnedPerCurrency;

  const CustomerPointsInfo({
    this.isEnabled = false,
    this.pointsPerCurrencyUnit = 0.10,
    this.balance = 0,
    this.minPointsToRedeem = 0,
    this.maxDiscountPercent = 100.0,
    this.maxPointsPerOrder,
    this.pointsEarnedPerCurrency = 1.0,
  });

  /// Monetary value of 1 point in currency units.
  /// If pointsPerCurrencyUnit < 1 (e.g. 0.10), 1 point = 0.10 SAR discount.
  /// If pointsPerCurrencyUnit >= 1 (e.g. 100), 100 points = 1 SAR discount, so 1 point = 0.01 SAR.
  double get monetaryValueOfOnePoint =>
      pointsPerCurrencyUnit < 1.0 ? pointsPerCurrencyUnit : (1.0 / pointsPerCurrencyUnit);

  /// Monetary value of all available points.
  double get monetaryValue => balance * monetaryValueOfOnePoint;
}

/// Abstract contract for customer order operations.
abstract class OrderRepository {
  /// Places a new order matching the backend POST /orders contract.
  Future<Result<OrderModel>> createOrder({
    required String storeId,
    required FulfillmentType fulfillment,
    required PaymentMethod paymentMethod,
    String? deliveryAddress,
    String? couponCode,
    int? redeemPoints,
    String? notes,
    required List<OrderItemInput> items,
    String? idempotencyKey,
  });

  /// Retrieves the authenticated customer's points balance and store config.
  Future<Result<CustomerPointsInfo>> getStorePointsInfo(String storeId);

  /// Retrieves the authenticated customer's orders matching GET /orders.
  Future<Result<List<OrderModel>>> getMyOrders({
    int? page,
    int? limit,
    OrderStatus? status,
  });

  /// Retrieves detailed information for a single order matching GET /orders/:orderId.
  Future<Result<OrderModel>> getOrderById(String orderId);

  /// Cancels an order matching the backend POST /orders/:orderId/cancel contract.
  Future<Result<OrderModel>> cancelOrder({
    required String orderId,
    String? cancelReason,
  });
}
