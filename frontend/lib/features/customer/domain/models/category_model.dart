/// Category entity model matching backend Category schema.
class CategoryModel {
  final String id;
  final String storeId;
  final String name;
  final int sortOrder;
  final int itemCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CategoryModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.sortOrder = 0,
    this.itemCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    int parseCount(dynamic value) {
      if (value is Map<String, dynamic>) {
        final items = value['items'];
        if (items is num) return items.toInt();
        if (items is String) return int.tryParse(items) ?? 0;
      }
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    int parseSortOrder(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return CategoryModel(
      id: json['id'] as String? ?? '',
      storeId: json['storeId'] as String? ?? json['store_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sortOrder: parseSortOrder(json['sortOrder'] ?? json['sort_order']),
      itemCount: parseCount(
        json['_count'] ?? json['itemCount'] ?? json['item_count'],
      ),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'sortOrder': sortOrder,
      'itemCount': itemCount,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          storeId == other.storeId &&
          name == other.name &&
          sortOrder == other.sortOrder &&
          itemCount == other.itemCount;

  @override
  int get hashCode =>
      id.hashCode ^
      storeId.hashCode ^
      name.hashCode ^
      sortOrder.hashCode ^
      itemCount.hashCode;

  @override
  String toString() =>
      'CategoryModel(id: $id, storeId: $storeId, name: $name, sortOrder: $sortOrder, itemCount: $itemCount)';
}
