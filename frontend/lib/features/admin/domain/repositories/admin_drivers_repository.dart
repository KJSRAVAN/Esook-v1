import '../../../../core/utils/result.dart';
import '../models/admin_user_model.dart';

/// Contract for Admin Driver/Rider repository.
abstract interface class AdminDriversRepository {
  /// Provision a new delivery driver account via `POST /auth/register/driver`.
  Future<Result<AdminUserModel>> registerDriver({
    required String name,
    required String phone,
    required String password,
    String? storeId,
  });

  /// List registered delivery drivers using `GET /users`.
  Future<Result<List<AdminUserModel>>> getDrivers({
    int page = 1,
    int limit = 50,
  });

  /// Enable or disable driver login access via `PATCH /users/:id`.
  Future<Result<AdminUserModel>> updateDriverStatus({
    required String driverId,
    required bool isActive,
  });

  /// Delete driver partner account via `DELETE /users/:id`.
  Future<Result<void>> deleteDriver(String driverId);
}
