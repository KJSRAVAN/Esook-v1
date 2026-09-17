import '../../../../core/utils/result.dart';
import '../models/admin_user_model.dart';

/// Contract for Admin Driver/Rider repository.
abstract interface class AdminDriversRepository {
  /// Register a new driver account.
  /// Backend endpoint: `POST /auth/register/driver`
  Future<Result<AdminUserModel>> registerDriver({
    required String name,
    required String phone,
    required String password,
  });

  /// List registered drivers using `GET /users?role=DRIVER` (or filtering).
  Future<Result<List<AdminUserModel>>> getDrivers({
    int page = 1,
    int limit = 50,
  });
}
