import '../../../auth/domain/models/user_role.dart';

/// Admin user representation representing system users retrieved via `/users`.
class AdminUserModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final UserRole role;
  final String? rawRole;
  final String? storeId;
  final bool isPhoneVerified;
  final bool isActive;
  final DateTime? createdAt;

  const AdminUserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    this.rawRole,
    this.storeId,
    this.isPhoneVerified = false,
    this.isActive = true,
    this.createdAt,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    final rawRoleString = json['role'] as String?;
    final role = UserRole.fromString(rawRoleString);

    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    DateTime? parsedCreatedAt;
    if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    }

    final rawIsActive = json['is_active'] ?? json['isActive'];
    final bool isActive = rawIsActive is bool ? rawIsActive : true;

    return AdminUserModel(
      id: json['id'] as String? ?? '',
      name: json['full_name'] as String? ?? json['name'] as String? ?? 'User',
      email: json['email'] as String?,
      phone: json['phone_number'] as String? ?? json['phone'] as String?,
      role: role,
      rawRole: rawRoleString,
      storeId: json['store_id'] as String? ?? json['storeId'] as String?,
      isPhoneVerified: json['is_phone_verified'] as bool? ?? json['isPhoneVerified'] as bool? ?? false,
      isActive: isActive,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone_number': phone,
      'role': rawRole ?? role.value,
      if (storeId != null) 'store_id': storeId,
      'is_phone_verified': isPhoneVerified,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

/// Paginated list of users response.
class AdminUsersPage {
  final List<AdminUserModel> users;
  final int total;
  final int page;
  final int limit;

  const AdminUsersPage({
    required this.users,
    required this.total,
    required this.page,
    required this.limit,
  });

  bool get hasNextPage => page * limit < total;
}
