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
  final double? originalPrice;
  final double? offerPrice;
  final String? variantName;

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
    this.originalPrice,
    this.offerPrice,
    this.variantName,
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

  /// Whether this item has an active offer/discount.
  bool get hasOffer =>
      (originalPrice != null && originalPrice! > price) ||
      (offerPrice != null && offerPrice! > 0 && offerPrice! < (originalPrice ?? price));

  /// Base price before discount.
  double get regularPrice => originalPrice ?? price;

  /// Calculated discount percentage.
  int get discountPercent =>
      hasOffer && regularPrice > 0
          ? (((regularPrice - price) / regularPrice) * 100).round()
          : 0;

  /// Total amount saved on this line item.
  double get totalSavings => hasOffer ? (regularPrice - price) * quantity : 0.0;

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

    double resolvedPrice = parsePrice(
      json['price'] ?? json['unitPrice'] ?? json['unit_price'] ?? json['effectivePrice'] ?? json['effective_price'],
    );
    double? parsedOriginalPrice = json['originalPrice'] != null || json['original_price'] != null
        ? parsePrice(json['originalPrice'] ?? json['original_price'])
        : null;
    double? parsedOfferPrice = json['offerPrice'] != null || json['offer_price'] != null
        ? parsePrice(json['offerPrice'] ?? json['offer_price'])
        : null;
    String? parsedVariant = json['variantName'] as String? ??
        json['variant_name'] as String? ??
        json['variant'] as String?;

    if (resolvedPrice == 0.0 && json['variants'] is List && (json['variants'] as List).isNotEmpty) {
      final variants = (json['variants'] as List).whereType<Map<String, dynamic>>().toList();
      if (variants.isNotEmpty) {
        final primary = variants.firstWhere(
          (v) => v['isDefault'] == true || v['name'] == 'Default',
          orElse: () => variants.first,
        );
        final offer = parsePrice(primary['offerPrice'] ?? primary['offer_price']);
        final reg = parsePrice(primary['price']);
        parsedOriginalPrice = reg > 0 ? reg : null;
        parsedOfferPrice = offer > 0 ? offer : null;
        parsedVariant ??= primary['name'] as String?;
        resolvedPrice = (offer > 0 && offer < reg) ? offer : reg;
      }
    }

    return CartItemModel(
      itemId: resolvedItemId,
      productId: resolvedProdId,
      name:
          json['name'] as String? ??
          json['productName'] as String? ??
          json['product_name'] as String? ??
          '',
      price: resolvedPrice,
      quantity: parseQuantity(json['quantity']),
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      isAvailable:
          json['isAvailable'] as bool? ?? json['is_available'] as bool? ?? true,
      loyaltyPointsPerUnit:
          (json['pointsValue'] as num?)?.toInt() ??
          (json['points_value'] as num?)?.toInt() ??
          (json['loyaltyPointsPerUnit'] as num?)?.toInt() ??
          (json['loyalty_points_per_unit'] as num?)?.toInt() ??
          0,
      originalPrice: parsedOriginalPrice,
      offerPrice: parsedOfferPrice,
      variantName: parsedVariant,
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
      if (originalPrice != null) 'originalPrice': originalPrice,
      if (offerPrice != null) 'offerPrice': offerPrice,
      if (variantName != null) 'variantName': variantName,
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
    double? originalPrice,
    double? offerPrice,
    String? variantName,
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
      originalPrice: originalPrice ?? this.originalPrice,
      offerPrice: offerPrice ?? this.offerPrice,
      variantName: variantName ?? this.variantName,
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
          loyaltyPointsPerUnit == other.loyaltyPointsPerUnit &&
          originalPrice == other.originalPrice &&
          offerPrice == other.offerPrice &&
          variantName == other.variantName;

  @override
  int get hashCode =>
      itemId.hashCode ^
      productId.hashCode ^
      name.hashCode ^
      price.hashCode ^
      quantity.hashCode ^
      imageUrl.hashCode ^
      isAvailable.hashCode ^
      loyaltyPointsPerUnit.hashCode ^
      (originalPrice?.hashCode ?? 0) ^
      (offerPrice?.hashCode ?? 0) ^
      (variantName?.hashCode ?? 0);

  @override
  String toString() =>
      'CartItemModel(itemId: $itemId, productId: $productId, name: $name, price: $price, quantity: $quantity, isAvailable: $isAvailable, originalPrice: $originalPrice, offerPrice: $offerPrice)';
}
