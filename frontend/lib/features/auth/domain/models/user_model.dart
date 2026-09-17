import 'user_role.dart';

/// User entity model aligned directly with backend User schema.
class UserModel {
  final String id;
  final String phoneNumber;
  final String? email;
  final String fullName;
  final UserRole role;
  final String? storeId;
  final String? address;
  final bool isActive;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.phoneNumber,
    this.email,
    required this.fullName,
    required this.role,
    this.storeId,
    this.address,
    this.isActive = true,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    if (rawCreatedAt != null) {
      if (rawCreatedAt is String) {
        parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
      }
    }

    return UserModel(
      id: json['id'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? json['phone'] as String? ?? '',
      email: json['email'] as String?,
      fullName: json['full_name'] as String? ?? json['name'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String?),
      storeId: json['store_id'] as String? ?? json['storeId'] as String?,
      address: json['address'] as String?,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      if (email != null) 'email': email,
      'full_name': fullName,
      'role': role.value,
      if (storeId != null) 'store_id': storeId,
      if (address != null) 'address': address,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          phoneNumber == other.phoneNumber &&
          email == other.email &&
          fullName == other.fullName &&
          role == other.role &&
          storeId == other.storeId &&
          address == other.address &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      id.hashCode ^
      phoneNumber.hashCode ^
      email.hashCode ^
      fullName.hashCode ^
      role.hashCode ^
      storeId.hashCode ^
      address.hashCode ^
      isActive.hashCode;

  @override
  String toString() =>
      'UserModel(id: $id, phoneNumber: $phoneNumber, fullName: $fullName, role: ${role.value}, storeId: $storeId)';
}
