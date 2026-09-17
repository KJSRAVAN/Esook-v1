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
}
