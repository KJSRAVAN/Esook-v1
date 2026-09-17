/// Input payload for an item within an order placement request.
class OrderItemInput {
  final String itemId;
  final int quantity;

  const OrderItemInput({
    required this.itemId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'quantity': quantity,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderItemInput &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId &&
          quantity == other.quantity;

  @override
  int get hashCode => itemId.hashCode ^ quantity.hashCode;
}

/// Immutable model representing an item line inside a customer order.
class OrderItemModel {
  final String? id;
  final String? orderId;
  final String itemId;
  final String itemName;
  final double itemPrice;
  final int quantity;
  final double subtotal;
  final String? imageUrl;
  final int loyaltyPointsPerUnit;
  final int subtotalPoints;

  const OrderItemModel({
    this.id,
    this.orderId,
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
    required this.quantity,
    double? subtotal,
    this.imageUrl,
    this.loyaltyPointsPerUnit = 0,
    int? subtotalPoints,
  })  : subtotal = subtotal ?? (itemPrice * quantity),
        subtotalPoints = subtotalPoints ?? (loyaltyPointsPerUnit * quantity);

  String get productId => itemId;
  String get name => itemName;
  double get unitPrice => itemPrice;
  double get price => itemPrice;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
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

    final price = parseDouble(
      json['itemPrice'] ??
          json['item_price'] ??
          json['price'] ??
          json['unitPrice'] ??
          json['unit_price'],
    );
    final quantity = parseInt(json['quantity']);
    final parsedSubtotal = json['subtotal'] != null
        ? parseDouble(json['subtotal'])
        : (price * quantity);

    final pointsPerUnit = parseInt(
      json['loyaltyPointsPerUnit'] ??
          json['loyalty_points_per_unit'] ??
          json['pointsPerUnit'] ??
          json['points_per_unit'],
    );
    final subPoints = json['subtotalPoints'] != null || json['subtotal_points'] != null
        ? parseInt(json['subtotalPoints'] ?? json['subtotal_points'])
        : (pointsPerUnit * quantity);

    return OrderItemModel(
      id: json['id'] as String?,
      orderId: json['orderId'] as String? ?? json['order_id'] as String?,
      itemId: json['itemId'] as String? ??
          json['item_id'] as String? ??
          json['productId'] as String? ??
          json['product_id'] as String? ??
          '',
      itemName: json['itemName'] as String? ??
          json['item_name'] as String? ??
          json['name'] as String? ??
          json['productName'] as String? ??
          json['product_name'] as String? ??
          'Item',
      itemPrice: price,
      quantity: quantity,
      subtotal: parsedSubtotal,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      loyaltyPointsPerUnit: pointsPerUnit,
      subtotalPoints: subPoints,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (orderId != null) 'orderId': orderId,
      'itemId': itemId,
      'itemName': itemName,
      'itemPrice': itemPrice,
      'quantity': quantity,
      'subtotal': subtotal,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'loyaltyPointsPerUnit': loyaltyPointsPerUnit,
      'subtotalPoints': subtotalPoints,
    };
  }

  OrderItemModel copyWith({
    String? id,
    String? orderId,
    String? itemId,
    String? itemName,
    double? itemPrice,
    int? quantity,
    double? subtotal,
    String? imageUrl,
    int? loyaltyPointsPerUnit,
    int? subtotalPoints,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      itemPrice: itemPrice ?? this.itemPrice,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
      imageUrl: imageUrl ?? this.imageUrl,
      loyaltyPointsPerUnit: loyaltyPointsPerUnit ?? this.loyaltyPointsPerUnit,
      subtotalPoints: subtotalPoints ?? this.subtotalPoints,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderItemModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          itemId == other.itemId &&
          quantity == other.quantity &&
          itemPrice == other.itemPrice;

  @override
  int get hashCode => id.hashCode ^ itemId.hashCode ^ quantity.hashCode ^ itemPrice.hashCode;
}
