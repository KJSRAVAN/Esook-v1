/// Admin store model representing stores from `GET /stores`, `POST /stores`, `PATCH /stores/:id`.
class AdminStoreModel {
  final String id;
  final String name;
  final String areaId;
  final String? areaName;
  final String? address;
  final String? phone;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminStoreModel({
    required this.id,
    required this.name,
    required this.areaId,
    this.areaName,
    this.address,
    this.phone,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminStoreModel.fromJson(Map<String, dynamic> json) {
    String? resolvedAreaName;
    if (json['area'] is Map<String, dynamic>) {
      resolvedAreaName = (json['area'] as Map<String, dynamic>)['name'] as String?;
    } else if (json['area'] is String) {
      resolvedAreaName = json['area'] as String;
    }

    return AdminStoreModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      areaId: json['areaId'] as String? ?? json['area_id'] as String? ?? '',
      areaName: resolvedAreaName,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      createdAt: json['createdAt'] is String ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] is String ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'areaId': areaId,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      'isActive': isActive,
    };
  }
}
