import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/domain/models/order_item_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/domain/repositories/order_repository.dart';

class MockOrderRepository implements OrderRepository {
  OrderModel? orderToReturn;
  List<OrderModel>? ordersToReturn;
  CustomerPointsInfo? pointsInfoToReturn;
  AppFailure? failureToReturn;

  Future<Result<OrderModel>> Function({
    required String storeId,
    required FulfillmentType fulfillment,
    required PaymentMethod paymentMethod,
    String? deliveryAddress,
    String? couponCode,
    String? notes,
    required List<OrderItemInput> items,
    int? redeemPoints,
    String? idempotencyKey,
  })?
  customCreateOrderHandler;

  Future<Result<List<OrderModel>>> Function({
    int? page,
    int? limit,
    OrderStatus? status,
  })?
  customGetMyOrdersHandler;

  Future<Result<OrderModel>> Function(String orderId)?
  customGetOrderByIdHandler;

  Future<Result<OrderModel>> Function({
    required String orderId,
    String? cancelReason,
  })?
  customCancelOrderHandler;

  Future<Result<CustomerPointsInfo>> Function(String storeId)?
  customGetStorePointsInfoHandler;

  int createOrderCallCount = 0;
  int getMyOrdersCallCount = 0;
  int getOrderByIdCallCount = 0;
  int cancelOrderCallCount = 0;
  int getStorePointsInfoCallCount = 0;

  String? lastStoreIdParam;
  FulfillmentType? lastFulfillmentParam;
  PaymentMethod? lastPaymentMethodParam;
  String? lastDeliveryAddressParam;
  String? lastCouponCodeParam;
  String? lastNotesParam;
  List<OrderItemInput>? lastItemsParam;
  int? lastRedeemPointsParam;
  String? lastIdempotencyKeyParam;

  int? lastPageParam;
  int? lastLimitParam;
  OrderStatus? lastStatusParam;
  String? lastOrderIdParam;
  String? lastCancelReasonParam;

  OrderModel get defaultOrder => OrderModel(
    id: 'ord-123',
    orderNumber: 'ESK-2026-001',
    customerId: 'usr-123',
    storeId: 'store-1',
    storeName: 'eSOuQ Olaya Flagship',
    status: OrderStatus.pending,
    fulfillment: FulfillmentType.delivery,
    deliveryAddress: 'Building 4B, King Fahd Rd, Riyadh',
    couponCode: null,
    notes: 'Leave at front door',
    subtotal: 3.35,
    discount: 0.0,
    deliveryFee: 1.50,
    total: 4.85,
    pointsEarned: 7,
    items: const [
      OrderItemModel(
        id: 'item-1',
        orderId: 'ord-123',
        itemId: 'prod-1',
        itemName: 'Fresh Whole Milk 1L',
        itemPrice: 1.25,
        quantity: 2,
        subtotal: 2.50,
        loyaltyPointsPerUnit: 5,
        subtotalPoints: 10,
      ),
      OrderItemModel(
        id: 'item-2',
        orderId: 'ord-123',
        itemId: 'prod-2',
        itemName: 'Organic Bananas 1kg',
        itemPrice: 0.85,
        quantity: 1,
        subtotal: 0.85,
        loyaltyPointsPerUnit: 2,
        subtotalPoints: 2,
      ),
    ],
    createdAt: DateTime.parse('2026-09-15T10:00:00Z'),
    updatedAt: DateTime.parse('2026-09-15T10:00:00Z'),
  );

  @override
  Future<Result<OrderModel>> createOrder({
    required String storeId,
    required FulfillmentType fulfillment,
    required PaymentMethod paymentMethod,
    String? deliveryAddress,
    String? couponCode,
    String? notes,
    required List<OrderItemInput> items,
    int? redeemPoints,
    String? idempotencyKey,
  }) async {
    createOrderCallCount++;
    lastStoreIdParam = storeId;
    lastFulfillmentParam = fulfillment;
    lastPaymentMethodParam = paymentMethod;
    lastDeliveryAddressParam = deliveryAddress;
    lastCouponCodeParam = couponCode;
    lastNotesParam = notes;
    lastItemsParam = items;
    lastRedeemPointsParam = redeemPoints;
    lastIdempotencyKeyParam = idempotencyKey;

    if (customCreateOrderHandler != null) {
      return customCreateOrderHandler!(
        storeId: storeId,
        fulfillment: fulfillment,
        paymentMethod: paymentMethod,
        deliveryAddress: deliveryAddress,
        couponCode: couponCode,
        notes: notes,
        items: items,
        redeemPoints: redeemPoints,
        idempotencyKey: idempotencyKey,
      );
    }

    if (failureToReturn != null) {
      return Result.failure(failureToReturn!);
    }
    return Result.success(orderToReturn ?? defaultOrder);
  }

  @override
  Future<Result<CustomerPointsInfo>> getStorePointsInfo(String storeId) async {
    getStorePointsInfoCallCount++;
    if (customGetStorePointsInfoHandler != null) {
      return customGetStorePointsInfoHandler!(storeId);
    }
    if (failureToReturn != null) {
      return Result.failure(failureToReturn!);
    }
    return Result.success(
      pointsInfoToReturn ??
          const CustomerPointsInfo(
            isEnabled: false,
            pointsPerCurrencyUnit: 0.10,
            balance: 0,
          ),
    );
  }

  @override
  Future<Result<List<OrderModel>>> getMyOrders({
    int? page,
    int? limit,
    OrderStatus? status,
  }) async {
    getMyOrdersCallCount++;
    lastPageParam = page;
    lastLimitParam = limit;
    lastStatusParam = status;

    if (customGetMyOrdersHandler != null) {
      return customGetMyOrdersHandler!(
        page: page,
        limit: limit,
        status: status,
      );
    }

    if (failureToReturn != null) {
      return Result.failure(failureToReturn!);
    }
    return Result.success(ordersToReturn ?? [defaultOrder]);
  }

  @override
  Future<Result<OrderModel>> getOrderById(String orderId) async {
    getOrderByIdCallCount++;
    lastOrderIdParam = orderId;

    if (customGetOrderByIdHandler != null) {
      return customGetOrderByIdHandler!(orderId);
    }

    if (failureToReturn != null) {
      return Result.failure(failureToReturn!);
    }
    return Result.success(orderToReturn ?? defaultOrder);
  }

  @override
  Future<Result<OrderModel>> cancelOrder({
    required String orderId,
    String? cancelReason,
  }) async {
    cancelOrderCallCount++;
    lastOrderIdParam = orderId;
    lastCancelReasonParam = cancelReason;

    if (customCancelOrderHandler != null) {
      return customCancelOrderHandler!(
        orderId: orderId,
        cancelReason: cancelReason,
      );
    }

    if (failureToReturn != null) {
      return Result.failure(failureToReturn!);
    }
    return Result.success(
      (orderToReturn ?? defaultOrder).copyWith(status: OrderStatus.cancelled),
    );
  }
}
