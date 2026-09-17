import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../domain/models/admin_user_model.dart';
import '../../domain/repositories/admin_drivers_repository.dart';

/// Concrete [AdminDriversRepository] communicating with `POST /auth/register/driver` and `GET /users`.
class AdminDriversRepositoryImpl implements AdminDriversRepository {
  final ApiClient _apiClient;

  const AdminDriversRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<AdminUserModel>> registerDriver({
    required String name,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/auth/register/driver',
        body: {
          'name': name.trim(),
          'phone': phone.trim(),
          'password': password,
        },
      );

      final dynamic rawData = response.data;
      final Map<String, dynamic> rawUser;
      if (rawData is Map<String, dynamic>) {
        if (rawData['user'] is Map<String, dynamic>) {
          rawUser = rawData['user'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawUser = rawData['data'] as Map<String, dynamic>;
        } else {
          rawUser = rawData;
        }
      } else {
        rawUser = const {};
      }

      final driver = AdminUserModel.fromJson(rawUser);
      return Result.success(driver);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to register driver: $e'));
    }
  }

  @override
  Future<Result<List<AdminUserModel>>> getDrivers({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      // First try querying users with role filter
      final response = await _apiClient.get<dynamic>(
        '/users',
        queryParameters: {
          'page': page,
          'limit': limit,
          'role': 'DRIVER',
        },
      );

      final dynamic rawData = response.data;
      final List<dynamic> rawList;

      if (rawData is Map<String, dynamic>) {
        if (rawData['data'] is List) {
          rawList = rawData['data'] as List;
        } else if (rawData['users'] is List) {
          rawList = rawData['users'] as List;
        } else {
          rawList = const [];
        }
      } else if (rawData is List) {
        rawList = rawData;
      } else {
        rawList = const [];
      }

      var drivers = rawList
          .whereType<Map<String, dynamic>>()
          .map(AdminUserModel.fromJson)
          .where((u) => u.role == UserRole.deliveryRider || u.rawRole?.toUpperCase() == 'DRIVER')
          .toList();

      if (drivers.isEmpty && rawList.isNotEmpty) {
        drivers = rawList
            .whereType<Map<String, dynamic>>()
            .map(AdminUserModel.fromJson)
            .where((u) => u.role == UserRole.deliveryRider || u.rawRole?.toUpperCase() == 'DRIVER')
            .toList();
      }

      return Result.success(drivers);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to fetch drivers: $e'));
    }
  }
}
