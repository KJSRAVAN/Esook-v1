import '../../../../core/utils/result.dart';
import '../models/admin_user_model.dart';

/// Contract for Admin User Management repository.
abstract interface class AdminUsersRepository {
  /// List users with pagination and optional role filter.
  /// Backend endpoint: `GET /users?page=...&limit=...&role=...`
  Future<Result<AdminUsersPage>> getUsers({
    int page = 1,
    int limit = 50,
    String? role,
  });

  /// Provision a STAFF or MANAGER account associated with a specific store.
  /// Backend endpoint: `POST /users/staff`
  Future<Result<AdminUserModel>> createStaffAccount({
    required String storeId,
    required String name,
    required String email,
    String? phone,
    required String role,
    required String password,
  });

  /// Edit permitted staff fields: name, email, password, role, storeId, and isActive.
  /// Backend endpoint: `PATCH /users/staff/:userId`
  Future<Result<AdminUserModel>> updateStaffAccount({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? password,
    String? role,
    String? storeId,
    bool? isActive,
  });

  /// Permanently delete a STAFF or MANAGER account.
  /// Backend endpoint: `DELETE /users/staff/:userId`
  Future<Result<void>> deleteStaffAccount(String userId);
}

