/// Category entity model matching `/stores/:storeId/categories`.
class StoreCategoryModel {
  final String id;
  final String storeId;
  final String name;
  final int sortOrder;
  final DateTime? createdAt;
  final int? productCount;

  const StoreCategoryModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.sortOrder = 0,
    this.createdAt,
    this.productCount,
  });

  factory StoreCategoryModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    int parseInt(dynamic value, [int defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    return StoreCategoryModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      storeId: json['storeId'] as String? ?? json['store_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sortOrder: parseInt(json['sortOrder'] ?? json['sort_order']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      productCount: json['productCount'] != null || json['product_count'] != null
          ? parseInt(json['productCount'] ?? json['product_count'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': storeId,
      'store_id': storeId,
      'name': name,
      'sortOrder': sortOrder,
      'sort_order': sortOrder,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (productCount != null) 'productCount': productCount,
      if (productCount != null) 'product_count': productCount,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreCategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'StoreCategoryModel(id: $id, storeId: $storeId, name: $name)';
}
