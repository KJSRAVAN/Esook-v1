/// Product entity model directly matching backend Product/Item schema.
class ProductModel {
  final String id;
  final String storeId;
  final String? categoryId;
  final String name;
  final String? description;
  final double price;
  final double? offerPrice;
  final String? category;
  final String? imageUrl;
  final bool isAvailable;
  final int sortOrder;
  final int loyaltyPointsPerUnit;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? defaultVariantId;

  const ProductModel({
    required this.id,
    required this.storeId,
    this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.offerPrice,
    this.category,
    this.imageUrl,
    this.isAvailable = true,
    this.sortOrder = 0,
    this.loyaltyPointsPerUnit = 0,
    this.createdAt,
    this.updatedAt,
    this.defaultVariantId,
  });

  /// Effective variant ID or parent product ID for cart actions.
  String get primaryVariantOrProductId =>
      (defaultVariantId != null && defaultVariantId!.isNotEmpty)
          ? defaultVariantId!
          : id;

  /// True if an active promotional offer price is lower than regular price.
  bool get hasOffer =>
      offerPrice != null && offerPrice! > 0 && offerPrice! < price;

  /// Effective price to charge the customer (offerPrice if active, otherwise price).
  double get effectivePrice => hasOffer ? offerPrice! : price;

  /// Discount percentage (e.g. 20 for 20% off) when offer is active.
  int? get discountPercentage {
    if (!hasOffer || price <= 0) return null;
    final pct = (((price - offerPrice!) / price) * 100).round();
    return pct > 0 ? pct : null;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    double parsePrice(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    double? parseOfferPrice(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int parsePoints(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    int parseSortOrder(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    String? parseCategoryName(dynamic catVal) {
      if (catVal is Map<String, dynamic>) {
        return catVal['name'] as String?;
      }
      if (catVal is String && catVal.isNotEmpty) {
        return catVal;
      }
      return json['category_name'] as String? ??
          json['categoryName'] as String?;
    }

    String? parseCategoryId(dynamic catVal, dynamic explicitCatId) {
      if (explicitCatId is String && explicitCatId.isNotEmpty) {
        return explicitCatId;
      }
      if (catVal is Map<String, dynamic>) {
        return catVal['id'] as String?;
      }
      return null;
    }

    String parseStoreId(dynamic jsonVal) {
      if (jsonVal['storeId'] is String &&
          (jsonVal['storeId'] as String).isNotEmpty) {
        return jsonVal['storeId'] as String;
      }
      if (jsonVal['store_id'] is String &&
          (jsonVal['store_id'] as String).isNotEmpty) {
        return jsonVal['store_id'] as String;
      }
      if (jsonVal['store'] is Map<String, dynamic>) {
        return jsonVal['store']['id'] as String? ?? '';
      }
      return '';
    }

    final catVal = json['category'];
    final explicitCatId = json['categoryId'] ?? json['category_id'];

    double parsedPrice = parsePrice(json['price']);
    double? parsedOfferPrice = parseOfferPrice(json['offerPrice'] ?? json['offer_price']);
    int parsedPoints = parsePoints(
      json['pointsValue'] ??
          json['points_value'] ??
          json['loyalty_points_per_unit'] ??
          json['loyaltyPointsPerUnit'],
    );

    // If top-level price is 0 or variants array is present, check variants
    String? parsedVariantId;
    if (json['variants'] is List && (json['variants'] as List).isNotEmpty) {
      final variants = (json['variants'] as List).whereType<Map<String, dynamic>>().toList();
      if (variants.isNotEmpty) {
        final primary = variants.firstWhere(
          (v) =>
              v['isDefault'] == true ||
              (v['name']?.toString().toLowerCase() == 'default'),
          orElse: () => variants.firstWhere(
            (v) => v['isAvailable'] != false,
            orElse: () => variants.first,
          ),
        );
        parsedVariantId = primary['id'] as String?;
        if (parsedPrice == 0.0) {
          parsedPrice = parsePrice(primary['price']);
        }
        parsedOfferPrice ??= parseOfferPrice(primary['offerPrice'] ?? primary['offer_price']);
        if (parsedPoints == 0) {
          parsedPoints = parsePoints(primary['pointsValue'] ?? primary['points_value']);
        }
      }
    }

    return ProductModel(
      id: json['id'] as String? ?? '',
      storeId: parseStoreId(json),
      categoryId: parseCategoryId(catVal, explicitCatId),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: parsedPrice,
      offerPrice: parsedOfferPrice,
      category: parseCategoryName(catVal),
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      isAvailable:
          json['isAvailable'] as bool? ?? json['is_available'] as bool? ?? true,
      sortOrder: parseSortOrder(json['sortOrder'] ?? json['sort_order']),
      loyaltyPointsPerUnit: parsedPoints,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
      defaultVariantId: parsedVariantId ??
          json['defaultVariantId'] as String? ??
          json['default_variant_id'] as String? ??
          json['variantId'] as String? ??
          json['variant_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': storeId,
      'store_id': storeId,
      if (categoryId != null) 'categoryId': categoryId,
      if (categoryId != null) 'category_id': categoryId,
      'name': name,
      if (description != null) 'description': description,
      'price': price.toStringAsFixed(2),
      if (offerPrice != null) 'offerPrice': offerPrice?.toStringAsFixed(2),
      if (offerPrice != null) 'offer_price': offerPrice?.toStringAsFixed(2),
      if (category != null) 'category': category,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imageUrl != null) 'image_url': imageUrl,
      'isAvailable': isAvailable,
      'is_available': isAvailable,
      'sortOrder': sortOrder,
      'loyalty_points_per_unit': loyaltyPointsPerUnit,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
      if (defaultVariantId != null) 'defaultVariantId': defaultVariantId,
      if (defaultVariantId != null) 'default_variant_id': defaultVariantId,
    };
  }

  ProductModel copyWith({
    String? id,
    String? storeId,
    String? categoryId,
    String? name,
    String? description,
    double? price,
    double? offerPrice,
    String? category,
    String? imageUrl,
    bool? isAvailable,
    int? sortOrder,
    int? loyaltyPointsPerUnit,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? defaultVariantId,
  }) {
    return ProductModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      offerPrice: offerPrice ?? this.offerPrice,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      sortOrder: sortOrder ?? this.sortOrder,
      loyaltyPointsPerUnit: loyaltyPointsPerUnit ?? this.loyaltyPointsPerUnit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      defaultVariantId: defaultVariantId ?? this.defaultVariantId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          storeId == other.storeId &&
          categoryId == other.categoryId &&
          name == other.name &&
          description == other.description &&
          price == other.price &&
          offerPrice == other.offerPrice &&
          category == other.category &&
          imageUrl == other.imageUrl &&
          isAvailable == other.isAvailable &&
          sortOrder == other.sortOrder &&
          loyaltyPointsPerUnit == other.loyaltyPointsPerUnit;

  @override
  int get hashCode =>
      id.hashCode ^
      storeId.hashCode ^
      categoryId.hashCode ^
      name.hashCode ^
      description.hashCode ^
      price.hashCode ^
      offerPrice.hashCode ^
      category.hashCode ^
      imageUrl.hashCode ^
      isAvailable.hashCode ^
      sortOrder.hashCode ^
      loyaltyPointsPerUnit.hashCode;

  @override
  String toString() =>
      'ProductModel(id: $id, storeId: $storeId, name: $name, price: $price, offerPrice: $offerPrice, isAvailable: $isAvailable)';
}
