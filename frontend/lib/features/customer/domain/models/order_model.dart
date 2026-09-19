import 'order_item_model.dart';

/// Status of an order within the lifecycle.
enum OrderStatus {
  pending,
  accepted,
  rejected,
  preparing,
  ready,
  outForDelivery,
  delivered,
  cancelled;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.rejected:
        return 'Rejected';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String toBackendString() {
    switch (this) {
      case OrderStatus.pending:
        return 'PENDING';
      case OrderStatus.accepted:
        return 'ACCEPTED';
      case OrderStatus.rejected:
        return 'REJECTED';
      case OrderStatus.preparing:
        return 'PREPARING';
      case OrderStatus.ready:
        return 'READY';
      case OrderStatus.outForDelivery:
        return 'OUT_FOR_DELIVERY';
      case OrderStatus.delivered:
        return 'DELIVERED';
      case OrderStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static OrderStatus fromString(String? value) {
    if (value == null) return OrderStatus.pending;
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'pending':
        return OrderStatus.pending;
      case 'accepted':
        return OrderStatus.accepted;
      case 'rejected':
        return OrderStatus.rejected;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'out_for_delivery':
      case 'outfordelivery':
        return OrderStatus.outForDelivery;
      case 'delivered':
      case 'completed':
        return OrderStatus.delivered;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}

/// Fulfillment mode for the order.
enum FulfillmentType {
  pickup,
  delivery;

  String get displayName =>
      this == FulfillmentType.pickup ? 'Pickup' : 'Delivery';

  String toBackendString() =>
      this == FulfillmentType.pickup ? 'PICKUP' : 'DELIVERY';

  static FulfillmentType fromString(String? value) {
    if (value == null) return FulfillmentType.delivery;
    final normalized = value.trim().toLowerCase();
    if (normalized == 'pickup') return FulfillmentType.pickup;
    return FulfillmentType.delivery;
  }
}

/// Immutable model representing an order placed by a customer.
class OrderModel {
  final String id;
  final String? orderNumber;
  final String customerId;
  final String storeId;
  final String? storeName;
  final OrderStatus status;
  final FulfillmentType fulfillment;
  final String? deliveryAddress;
  final String? couponCode;
  final String? notes;
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double total;
  final int pointsEarned;
  final List<OrderItemModel> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? rejectedReason;

  const OrderModel({
    required this.id,
    this.orderNumber,
    required this.customerId,
    required this.storeId,
    this.storeName,
    required this.status,
    required this.fulfillment,
    this.deliveryAddress,
    this.couponCode,
    this.notes,
    required this.subtotal,
    this.discount = 0.0,
    this.deliveryFee = 0.0,
    required this.total,
    this.pointsEarned = 0,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
    this.rejectedReason,
  });

  int get itemCount => items.fold<int>(0, (sum, i) => sum + i.quantity);

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(OrderItemModel.fromJson)
        .toList();

    final statusStr = json['status'] as String?;
    final fulfillmentStr =
        json['fulfillment'] as String? ??
        json['fulfillmentType'] as String? ??
        json['fulfillment_type'] as String?;

    final subtotalVal = parseDouble(json['subtotal']);
    final totalVal = parseDouble(
      json['total'] ??
          json['totalAmount'] ??
          json['total_amount'] ??
          subtotalVal,
    );

    String? storeName;
    if (json['storeName'] != null) {
      storeName = json['storeName'] as String;
    } else if (json['store_name'] != null) {
      storeName = json['store_name'] as String;
    } else if (json['store'] is Map<String, dynamic>) {
      storeName = (json['store'] as Map<String, dynamic>)['name'] as String?;
    }

    return OrderModel(
      id: json['id'] as String? ?? '',
      orderNumber:
          json['orderNumber'] as String? ??
          json['order_number'] as String? ??
          json['orderNo'] as String?,
      customerId:
          json['customerId'] as String? ??
          json['customer_id'] as String? ??
          json['userId'] as String? ??
          json['user_id'] as String? ??
          '',
      storeId: json['storeId'] as String? ?? json['store_id'] as String? ?? '',
      storeName: storeName,
      status: OrderStatus.fromString(statusStr),
      fulfillment: FulfillmentType.fromString(fulfillmentStr),
      deliveryAddress:
          json['deliveryAddress'] as String? ??
          json['delivery_address'] as String?,
      couponCode:
          json['couponCode'] as String? ??
          json['coupon_code'] as String? ??
          json['couponId'] as String? ??
          json['coupon_id'] as String?,
      notes: json['notes'] as String?,
      subtotal: subtotalVal,
      discount: parseDouble(json['discount']),
      deliveryFee: parseDouble(json['deliveryFee'] ?? json['delivery_fee']),
      total: totalVal,
      pointsEarned: parseInt(json['pointsEarned'] ?? json['points_earned']),
      items: items,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
      rejectedReason:
          json['rejectedReason'] as String? ??
          json['rejected_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (orderNumber != null) 'orderNumber': orderNumber,
      'customerId': customerId,
      'storeId': storeId,
      if (storeName != null) 'storeName': storeName,
      'status': status.toBackendString(),
      'fulfillment': fulfillment.toBackendString(),
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      if (couponCode != null) 'couponCode': couponCode,
      if (notes != null) 'notes': notes,
      'subtotal': subtotal,
      'discount': discount,
      'deliveryFee': deliveryFee,
      'total': total,
      'pointsEarned': pointsEarned,
      'items': items.map((i) => i.toJson()).toList(),
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
      if (rejectedReason != null) 'rejectedReason': rejectedReason,
    };
  }

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? customerId,
    String? storeId,
    String? storeName,
    OrderStatus? status,
    FulfillmentType? fulfillment,
    String? deliveryAddress,
    String? couponCode,
    String? notes,
    double? subtotal,
    double? discount,
    double? deliveryFee,
    double? total,
    int? pointsEarned,
    List<OrderItemModel>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rejectedReason,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      status: status ?? this.status,
      fulfillment: fulfillment ?? this.fulfillment,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      couponCode: couponCode ?? this.couponCode,
      notes: notes ?? this.notes,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      total: total ?? this.total,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rejectedReason: rejectedReason ?? this.rejectedReason,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          total == other.total;

  @override
  int get hashCode => id.hashCode ^ status.hashCode ^ total.hashCode;
}
