import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/domain/models/order_item_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/domain/repositories/order_repository.dart';

class MockOrderRepository implements OrderRepository {
  OrderModel? orderToReturn;
  List<OrderModel>? ordersToReturn;
  AppFailure? failureToReturn;

  Future<Result<OrderModel>> Function({
    required String storeId,
    required FulfillmentType fulfillment,
    String? deliveryAddress,
    String? couponCode,
    String? notes,
    required List<OrderItemInput> items,
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

  int createOrderCallCount = 0;
  int getMyOrdersCallCount = 0;
  int getOrderByIdCallCount = 0;

  String? lastStoreIdParam;
  FulfillmentType? lastFulfillmentParam;
  String? lastDeliveryAddressParam;
  String? lastCouponCodeParam;
  String? lastNotesParam;
  List<OrderItemInput>? lastItemsParam;
  String? lastIdempotencyKeyParam;

  int? lastPageParam;
  int? lastLimitParam;
  OrderStatus? lastStatusParam;
  String? lastOrderIdParam;

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
    String? deliveryAddress,
    String? couponCode,
    String? notes,
    required List<OrderItemInput> items,
    String? idempotencyKey,
  }) async {
    createOrderCallCount++;
    lastStoreIdParam = storeId;
    lastFulfillmentParam = fulfillment;
    lastDeliveryAddressParam = deliveryAddress;
    lastCouponCodeParam = couponCode;
    lastNotesParam = notes;
    lastItemsParam = items;
    lastIdempotencyKeyParam = idempotencyKey;

    if (customCreateOrderHandler != null) {
      return customCreateOrderHandler!(
        storeId: storeId,
        fulfillment: fulfillment,
        deliveryAddress: deliveryAddress,
        couponCode: couponCode,
        notes: notes,
        items: items,
        idempotencyKey: idempotencyKey,
      );
    }

    if (failureToReturn != null) {
      return Result.failure(failureToReturn!);
    }
    return Result.success(orderToReturn ?? defaultOrder);
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
}
