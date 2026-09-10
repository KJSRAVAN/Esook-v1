/// Store entity model directly matching backend Store schema.
class StoreModel {
  final String id;
  final String name;
  final String area;
  final String? address;
  final String? phoneNumber;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StoreModel({
    required this.id,
    required this.name,
    required this.area,
    this.address,
    this.phoneNumber,
    this.isActive = true,
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

    return StoreModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      area: json['area'] as String? ?? '',
      address: json['address'] as String?,
      phoneNumber: json['phone_number'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'area': area,
      if (address != null) 'address': address,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
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
          address == other.address &&
          phoneNumber == other.phoneNumber &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      area.hashCode ^
      address.hashCode ^
      phoneNumber.hashCode ^
      isActive.hashCode;

  @override
  String toString() =>
      'StoreModel(id: $id, name: $name, area: $area, isActive: $isActive)';
}
