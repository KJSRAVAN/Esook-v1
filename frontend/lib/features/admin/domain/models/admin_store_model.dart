/// Admin store model representing stores from `GET /stores`, `POST /stores`, `PATCH /stores/:id`.
class AdminStoreModel {
  final String id;
  final String name;
  final String area;
  final String? areaName;
  final String? address;
  final String? phone;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Backwards compatibility alias for [area].
  String get areaId => area;

  const AdminStoreModel({
    required this.id,
    required this.name,
    String? area,
    String? areaId,
    this.areaName,
    this.address,
    this.phone,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  }) : area = area ?? areaId ?? '';

  factory AdminStoreModel.fromJson(Map<String, dynamic> json) {
    String? resolvedAreaName;
    if (json['area'] is Map<String, dynamic>) {
      resolvedAreaName = (json['area'] as Map<String, dynamic>)['name'] as String?;
    } else if (json['area'] is String) {
      resolvedAreaName = json['area'] as String;
    }

    final resolvedArea = resolvedAreaName ??
        json['area'] as String? ??
        json['areaId'] as String? ??
        json['area_id'] as String? ??
        '';

    final rawPhone = json['phone_number'] as String? ?? json['phone'] as String?;
    final rawIsActive = json['is_active'] ?? json['isActive'];
    final bool isActive = rawIsActive is bool ? rawIsActive : true;

    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    final rawUpdatedAt = json['updated_at'] ?? json['updatedAt'];

    return AdminStoreModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      area: resolvedArea,
      areaName: resolvedAreaName ?? resolvedArea,
      address: json['address'] as String?,
      phone: rawPhone,
      isActive: isActive,
      createdAt: rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null,
      updatedAt: rawUpdatedAt is String ? DateTime.tryParse(rawUpdatedAt) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'area': area,
      if (address != null) 'address': address,
      if (phone != null) 'phone_number': phone,
      'is_active': isActive,
    };
  }
}
