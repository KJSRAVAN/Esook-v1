/// Nested store info returned in driver order responses.
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
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
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

/// Nested customer info returned in driver order responses.
class RiderCustomerInfo {
  final String phone;

  const RiderCustomerInfo({required this.phone});

  factory RiderCustomerInfo.fromJson(Map<String, dynamic> json) {
    return RiderCustomerInfo(
      phone: json['phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'phone': phone};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderCustomerInfo && phone == other.phone;

  @override
  int get hashCode => phone.hashCode;
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
    final normalized = value.trim().toUpperCase();
    switch (normalized) {
      case 'READY':
        return RiderOrderStatus.ready;
      case 'OUT_FOR_DELIVERY':
        return RiderOrderStatus.outForDelivery;
      case 'DELIVERED':
        return RiderOrderStatus.delivered;
      default:
        return RiderOrderStatus.ready;
    }
  }
}

/// Immutable model representing an order as seen by a delivery driver.
///
/// Matches the exact DRIVER_ORDER_SELECT from the production backend:
/// id, status, fulfillment, deliveryAddress, notes, driverId, createdAt,
/// store { id, name, address, phone }, customer { phone }.
class RiderOrderModel {
  final String id;
  final RiderOrderStatus status;
  final String fulfillment;
  final String? deliveryAddress;
  final String? notes;
  final String? driverId;
  final DateTime? createdAt;
  final RiderStoreInfo store;
  final RiderCustomerInfo customer;

  const RiderOrderModel({
    required this.id,
    required this.status,
    this.fulfillment = 'DELIVERY',
    this.deliveryAddress,
    this.notes,
    this.driverId,
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

    final storeJson = json['store'] as Map<String, dynamic>? ?? const {};
    final customerJson = json['customer'] as Map<String, dynamic>? ?? const {};

    return RiderOrderModel(
      id: json['id'] as String? ?? '',
      status: RiderOrderStatus.fromString(json['status'] as String?),
      fulfillment: json['fulfillment'] as String? ?? 'DELIVERY',
      deliveryAddress: json['deliveryAddress'] as String? ??
          json['delivery_address'] as String?,
      notes: json['notes'] as String?,
      driverId: json['driverId'] as String? ?? json['driver_id'] as String?,
      createdAt: parsedCreatedAt,
      store: RiderStoreInfo.fromJson(storeJson),
      customer: RiderCustomerInfo.fromJson(customerJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.toBackendString(),
        'fulfillment': fulfillment,
        if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
        if (notes != null) 'notes': notes,
        if (driverId != null) 'driverId': driverId,
        if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
        'store': store.toJson(),
        'customer': customer.toJson(),
      };

  RiderOrderModel copyWith({
    String? id,
    RiderOrderStatus? status,
    String? fulfillment,
    String? deliveryAddress,
    String? notes,
    String? driverId,
    DateTime? createdAt,
    RiderStoreInfo? store,
    RiderCustomerInfo? customer,
  }) {
    return RiderOrderModel(
      id: id ?? this.id,
      status: status ?? this.status,
      fulfillment: fulfillment ?? this.fulfillment,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      notes: notes ?? this.notes,
      driverId: driverId ?? this.driverId,
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
