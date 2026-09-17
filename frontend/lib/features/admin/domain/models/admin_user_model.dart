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

    DateTime? parsedCreatedAt;
    if (json['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(json['createdAt'] as String);
    }

    return AdminUserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['full_name'] as String? ?? 'User',
      email: json['email'] as String?,
      phone: json['phone'] as String? ?? json['phone_number'] as String?,
      role: role,
      rawRole: rawRoleString,
      storeId: json['storeId'] as String? ?? json['store_id'] as String?,
      isPhoneVerified: json['isPhoneVerified'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'role': rawRole ?? role.value,
      if (storeId != null) 'storeId': storeId,
      'isPhoneVerified': isPhoneVerified,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
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
