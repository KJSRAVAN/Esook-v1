/// Store entity model directly matching backend Store schema.
class StoreModel {
  final String id;
  final String name;
  final String area;
  final String? areaId;
  final String? address;
  final String? phoneNumber;
  final bool isActive;
  final int? itemCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StoreModel({
    required this.id,
    required this.name,
    required this.area,
    this.areaId,
    this.address,
    this.phoneNumber,
    this.isActive = true,
    this.itemCount,
    this.createdAt,
    this.updatedAt,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    String parseArea(dynamic areaVal) {
      if (areaVal is Map<String, dynamic>) {
        return areaVal['name'] as String? ?? '';
      }
      if (areaVal is String) {
        return areaVal;
      }
      return json['areaName'] as String? ?? json['area_name'] as String? ?? '';
    }

    String? parseAreaId(dynamic areaVal, dynamic explicitAreaId) {
      if (explicitAreaId is String && explicitAreaId.isNotEmpty) {
        return explicitAreaId;
      }
      if (areaVal is Map<String, dynamic>) {
        return areaVal['id'] as String?;
      }
      return null;
    }

    int? parseItemCount(dynamic countVal, dynamic explicitCount) {
      if (countVal is Map<String, dynamic>) {
        final items = countVal['items'];
        if (items is num) return items.toInt();
        if (items is String) return int.tryParse(items);
      }
      if (explicitCount is num) return explicitCount.toInt();
      if (explicitCount is String) return int.tryParse(explicitCount);
      return null;
    }

    final areaVal = json['area'];
    final explicitAreaId = json['areaId'] ?? json['area_id'];

    return StoreModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      area: parseArea(areaVal),
      areaId: parseAreaId(areaVal, explicitAreaId),
      address: json['address'] as String?,
      phoneNumber:
          json['phone'] as String? ??
          json['phone_number'] as String? ??
          json['phoneNumber'] as String?,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      itemCount: parseItemCount(
        json['_count'],
        json['item_count'] ?? json['itemCount'],
      ),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'area': area,
      if (areaId != null) 'areaId': areaId,
      if (address != null) 'address': address,
      if (phoneNumber != null) 'phone': phoneNumber,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      'isActive': isActive,
      'is_active': isActive,
      if (itemCount != null) 'item_count': itemCount,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          area == other.area &&
          areaId == other.areaId &&
          address == other.address &&
          phoneNumber == other.phoneNumber &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      area.hashCode ^
      areaId.hashCode ^
      address.hashCode ^
      phoneNumber.hashCode ^
      isActive.hashCode;

  @override
  String toString() =>
      'StoreModel(id: $id, name: $name, area: $area, isActive: $isActive)';
}
