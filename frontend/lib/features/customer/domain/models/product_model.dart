/// Product entity model directly matching backend Product schema.
class ProductModel {
  final String id;
  final String storeId;
  final String name;
  final String? description;
  final double price;
  final String? category;
  final String? imageUrl;
  final bool isAvailable;
  final int loyaltyPointsPerUnit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    required this.price,
    this.category,
    this.imageUrl,
    this.isAvailable = true,
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

    return ProductModel(
      id: json['id'] as String? ?? '',
      storeId: json['store_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: parsePrice(json['price']),
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      loyaltyPointsPerUnit: parsePoints(json['loyalty_points_per_unit']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'name': name,
      if (description != null) 'description': description,
      'price': price.toStringAsFixed(2),
      if (category != null) 'category': category,
      if (imageUrl != null) 'image_url': imageUrl,
      'is_available': isAvailable,
      'loyalty_points_per_unit': loyaltyPointsPerUnit,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
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
          name == other.name &&
          description == other.description &&
          price == other.price &&
          category == other.category &&
          imageUrl == other.imageUrl &&
          isAvailable == other.isAvailable &&
          loyaltyPointsPerUnit == other.loyaltyPointsPerUnit;

  @override
  int get hashCode =>
      id.hashCode ^
      storeId.hashCode ^
      name.hashCode ^
      description.hashCode ^
      price.hashCode ^
      category.hashCode ^
      imageUrl.hashCode ^
      isAvailable.hashCode ^
      loyaltyPointsPerUnit.hashCode;

  @override
  String toString() =>
      'ProductModel(id: $id, storeId: $storeId, name: $name, price: $price, isAvailable: $isAvailable)';
}
