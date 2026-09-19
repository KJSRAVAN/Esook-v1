/// Immutable model representing a single item in the customer cart matching backend CartItem schema.
class CartItemModel {
  final String itemId;
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;
  final bool isAvailable;
  final int loyaltyPointsPerUnit;

  const CartItemModel({
    String? itemId,
    String? productId,
    String? name,
    String? productName,
    double? price,
    double? unitPrice,
    required this.quantity,
    this.imageUrl,
    this.isAvailable = true,
    this.loyaltyPointsPerUnit = 0,
    double? itemSubtotal,
  }) : itemId = itemId ?? productId ?? '',
       productId = productId ?? itemId ?? '',
       name = name ?? productName ?? '',
       price = price ?? unitPrice ?? 0.0;

  /// Alias for name for backwards compatibility with UI components.
  String get productName => name;

  /// Alias for price for backwards compatibility with UI components.
  double get unitPrice => price;

  /// Total price subtotal for this item line.
  double get itemSubtotal => price * quantity;

  /// Total loyalty points earned for this line item.
  int get subtotalPoints => loyaltyPointsPerUnit * quantity;

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    double parsePrice(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    int parseQuantity(dynamic value) {
      if (value == null) return 1;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 1;
    }

    final rawItemId = json['item_id'] as String? ?? json['itemId'] as String?;
    final rawProdId =
        json['product_id'] as String? ?? json['productId'] as String?;
    final resolvedProdId = rawProdId ?? rawItemId ?? '';
    final resolvedItemId = rawItemId ?? rawProdId ?? '';

    return CartItemModel(
      itemId: resolvedItemId,
      productId: resolvedProdId,
      name:
          json['name'] as String? ??
          json['productName'] as String? ??
          json['product_name'] as String? ??
          '',
      price: parsePrice(
        json['price'] ?? json['unitPrice'] ?? json['unit_price'],
      ),
      quantity: parseQuantity(json['quantity']),
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      isAvailable:
          json['isAvailable'] as bool? ?? json['is_available'] as bool? ?? true,
      loyaltyPointsPerUnit:
          (json['loyaltyPointsPerUnit'] as num?)?.toInt() ??
          (json['loyalty_points_per_unit'] as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'item_id': itemId,
      'productId': productId,
      'product_id': productId,
      'name': name,
      'product_name': name,
      'price': price,
      'unit_price': price.toStringAsFixed(2),
      'quantity': quantity,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imageUrl != null) 'image_url': imageUrl,
      'isAvailable': isAvailable,
      'is_available': isAvailable,
      'loyalty_points_per_unit': loyaltyPointsPerUnit,
      'item_subtotal': itemSubtotal.toStringAsFixed(2),
    };
  }

  CartItemModel copyWith({
    String? itemId,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    bool? isAvailable,
    int? loyaltyPointsPerUnit,
    String? productId,
    String? productName,
    double? unitPrice,
    double? itemSubtotal,
  }) {
    return CartItemModel(
      itemId: itemId ?? this.itemId,
      productId: productId ?? this.productId,
      name: name ?? productName ?? this.name,
      price: price ?? unitPrice ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      loyaltyPointsPerUnit: loyaltyPointsPerUnit ?? this.loyaltyPointsPerUnit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItemModel &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId &&
          productId == other.productId &&
          name == other.name &&
          price == other.price &&
          quantity == other.quantity &&
          imageUrl == other.imageUrl &&
          isAvailable == other.isAvailable &&
          loyaltyPointsPerUnit == other.loyaltyPointsPerUnit;

  @override
  int get hashCode =>
      itemId.hashCode ^
      productId.hashCode ^
      name.hashCode ^
      price.hashCode ^
      quantity.hashCode ^
      imageUrl.hashCode ^
      isAvailable.hashCode ^
      loyaltyPointsPerUnit.hashCode;

  @override
  String toString() =>
      'CartItemModel(itemId: $itemId, productId: $productId, name: $name, price: $price, quantity: $quantity)';
}
