/// Product entity model directly matching backend Product/Item schema.
class ProductModel {
  final String id;
  final String storeId;
  final String? categoryId;
  final String name;
  final String? description;
  final double price;
  final String? category;
  final String? imageUrl;
  final bool isAvailable;
  final int sortOrder;
  final int loyaltyPointsPerUnit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.storeId,
    this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.category,
    this.imageUrl,
    this.isAvailable = true,
    this.sortOrder = 0,
    this.loyaltyPointsPerUnit = 0,
    this.createdAt,
    this.updatedAt,
  });

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

    return ProductModel(
      id: json['id'] as String? ?? '',
      storeId: parseStoreId(json),
      categoryId: parseCategoryId(catVal, explicitCatId),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: parsePrice(json['price']),
      category: parseCategoryName(catVal),
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      isAvailable:
          json['isAvailable'] as bool? ?? json['is_available'] as bool? ?? true,
      sortOrder: parseSortOrder(json['sortOrder'] ?? json['sort_order']),
      loyaltyPointsPerUnit: parsePoints(
        json['loyalty_points_per_unit'] ?? json['loyaltyPointsPerUnit'],
      ),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
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
    };
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
      category.hashCode ^
      imageUrl.hashCode ^
      isAvailable.hashCode ^
      sortOrder.hashCode ^
      loyaltyPointsPerUnit.hashCode;

  @override
  String toString() =>
      'ProductModel(id: $id, storeId: $storeId, name: $name, price: $price, isAvailable: $isAvailable)';
}
