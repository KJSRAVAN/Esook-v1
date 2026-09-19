/// Nested store info returned in order responses.
class RiderStoreInfo {
  final String id;
  final String name;
  final String? address;
  final String? phone;

  const RiderStoreInfo({
    required this.id,
    required this.name,
    this.address,
    this.phone,
  });

  factory RiderStoreInfo.fromJson(Map<String, dynamic> json) {
    return RiderStoreInfo(
      id: json['id'] as String? ?? json['store_id'] as String? ?? '',
      name: json['name'] as String? ?? json['store_name'] as String? ?? '',
      address: json['address'] as String? ?? json['store_address'] as String?,
      phone: json['phone'] as String? ?? json['store_phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (address != null) 'address': address,
    if (phone != null) 'phone': phone,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderStoreInfo &&
          id == other.id &&
          name == other.name &&
          address == other.address &&
          phone == other.phone;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

/// Nested customer info returned in order responses.
class RiderCustomerInfo {
  final String phone;
  final String? name;

  const RiderCustomerInfo({required this.phone, this.name});

  factory RiderCustomerInfo.fromJson(Map<String, dynamic> json) {
    return RiderCustomerInfo(
      phone:
          json['phone'] as String? ??
          json['phone_number'] as String? ??
          json['customer_phone'] as String? ??
          '',
      name:
          json['name'] as String? ??
          json['full_name'] as String? ??
          json['customer_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'phone': phone,
    if (name != null) 'name': name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderCustomerInfo && phone == other.phone && name == other.name;

  @override
  int get hashCode => phone.hashCode ^ (name?.hashCode ?? 0);
}

/// Status of a driver order within the delivery lifecycle.
enum RiderOrderStatus {
  ready,
  outForDelivery,
  delivered;

  String get displayName {
    switch (this) {
      case RiderOrderStatus.ready:
        return 'Ready for Pickup';
      case RiderOrderStatus.outForDelivery:
        return 'Out for Delivery';
      case RiderOrderStatus.delivered:
        return 'Delivered';
    }
  }

  String toBackendString() {
    switch (this) {
      case RiderOrderStatus.ready:
        return 'READY';
      case RiderOrderStatus.outForDelivery:
        return 'OUT_FOR_DELIVERY';
      case RiderOrderStatus.delivered:
        return 'DELIVERED';
    }
  }

  static RiderOrderStatus fromString(String? value) {
    if (value == null) return RiderOrderStatus.ready;
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'preparing':
      case 'ready':
        return RiderOrderStatus.ready;
      case 'out_for_delivery':
      case 'outfordelivery':
        return RiderOrderStatus.outForDelivery;
      case 'completed':
      case 'delivered':
        return RiderOrderStatus.delivered;
      default:
        return RiderOrderStatus.ready;
    }
  }
}

/// Immutable model representing an order as seen by a delivery driver.
///
/// Maps directly to the production backend `/api/orders` response structure.
class RiderOrderModel {
  final String id;
  final String? orderNumber;
  final RiderOrderStatus status;
  final String? rawStatus;
  final String fulfillment;
  final String? deliveryAddress;
  final String? notes;
  final String? driverId;
  final double? totalAmount;
  final DateTime? createdAt;
  final RiderStoreInfo store;
  final RiderCustomerInfo customer;

  const RiderOrderModel({
    required this.id,
    this.orderNumber,
    required this.status,
    this.rawStatus,
    this.fulfillment = 'delivery',
    this.deliveryAddress,
    this.notes,
    this.driverId,
    this.totalAmount,
    this.createdAt,
    required this.store,
    required this.customer,
  });

  factory RiderOrderModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    final rawCreatedAt = json['createdAt'] ?? json['created_at'];
    if (rawCreatedAt is String && rawCreatedAt.isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    }

    final rawStatus = json['status'] as String?;

    final Map<String, dynamic> storeJson;
    if (json['store'] is Map<String, dynamic>) {
      storeJson = json['store'] as Map<String, dynamic>;
    } else {
      storeJson = {
        'id': json['store_id'],
        'name': json['store_name'],
        'address': json['store_address'],
        'phone': json['store_phone'],
      };
    }

    final Map<String, dynamic> customerJson;
    if (json['customer'] is Map<String, dynamic>) {
      customerJson = json['customer'] as Map<String, dynamic>;
    } else {
      customerJson = {
        'phone': json['customer_phone'],
        'name': json['customer_name'],
      };
    }

    double? parsedTotal;
    final rawTotal =
        json['total_amount'] ?? json['total'] ?? json['totalAmount'];
    if (rawTotal is num) {
      parsedTotal = rawTotal.toDouble();
    } else if (rawTotal is String) {
      parsedTotal = double.tryParse(rawTotal);
    }

    return RiderOrderModel(
      id: json['id'] as String? ?? '',
      orderNumber:
          json['order_number'] as String? ?? json['orderNumber'] as String?,
      status: RiderOrderStatus.fromString(rawStatus),
      rawStatus: rawStatus,
      fulfillment:
          json['fulfillment_type'] as String? ??
          json['fulfillment'] as String? ??
          'delivery',
      deliveryAddress:
          json['delivery_address'] as String? ??
          json['deliveryAddress'] as String?,
      notes: json['notes'] as String?,
      driverId:
          json['rider_id'] as String? ??
          json['driver_id'] as String? ??
          json['driverId'] as String?,
      totalAmount: parsedTotal,
      createdAt: parsedCreatedAt,
      store: RiderStoreInfo.fromJson(storeJson),
      customer: RiderCustomerInfo.fromJson(customerJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (orderNumber != null) 'order_number': orderNumber,
    'status': status.toBackendString(),
    'fulfillment': fulfillment,
    if (deliveryAddress != null) 'delivery_address': deliveryAddress,
    if (notes != null) 'notes': notes,
    if (driverId != null) 'driver_id': driverId,
    if (totalAmount != null) 'total_amount': totalAmount,
    if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
    'store': store.toJson(),
    'customer': customer.toJson(),
  };

  RiderOrderModel copyWith({
    String? id,
    String? orderNumber,
    RiderOrderStatus? status,
    String? rawStatus,
    String? fulfillment,
    String? deliveryAddress,
    String? notes,
    String? driverId,
    double? totalAmount,
    DateTime? createdAt,
    RiderStoreInfo? store,
    RiderCustomerInfo? customer,
  }) {
    return RiderOrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      rawStatus: rawStatus ?? this.rawStatus,
      fulfillment: fulfillment ?? this.fulfillment,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      notes: notes ?? this.notes,
      driverId: driverId ?? this.driverId,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      store: store ?? this.store,
      customer: customer ?? this.customer,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderOrderModel &&
          id == other.id &&
          status == other.status &&
          driverId == other.driverId;

  @override
  int get hashCode => id.hashCode ^ status.hashCode;

  @override
  String toString() =>
      'RiderOrderModel(id: $id, status: ${status.displayName}, store: ${store.name})';
}
