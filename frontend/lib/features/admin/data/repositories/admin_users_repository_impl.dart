import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/admin_user_model.dart';
import '../../domain/repositories/admin_users_repository.dart';

/// Concrete [AdminUsersRepository] communicating with `GET /users`.
class AdminUsersRepositoryImpl implements AdminUsersRepository {
  final ApiClient _apiClient;

  const AdminUsersRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<AdminUsersPage>> getUsers({
    int page = 1,
    int limit = 50,
    String? role,
  }) async {
    try {
      String? backendRole;
      if (role != null && role.isNotEmpty && role.toUpperCase() != 'ALL') {
        final normalized = role.trim().toLowerCase();
        switch (normalized) {
          case 'customer':
            backendRole = 'customer';
            break;
          case 'staff':
          case 'store_staff':
            backendRole = 'store_staff';
            break;
          case 'manager':
          case 'store_manager':
            backendRole = 'store_manager';
            break;
          case 'driver':
          case 'delivery_rider':
            backendRole = 'delivery_rider';
            break;
          case 'super_admin':
          case 'admin':
            backendRole = 'super_admin';
            break;
          default:
            backendRole = normalized;
        }
      }

      final queryParams = <String, dynamic>{
        if (backendRole != null) 'role': backendRole,
      };

      final response = await _apiClient.get<dynamic>(
        '/users',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final dynamic rawData = response.data;
      final List<dynamic> rawList;

      if (rawData is Map<String, dynamic>) {
        if (rawData['users'] is List) {
          rawList = rawData['users'] as List;
        } else if (rawData['data'] is List) {
          rawList = rawData['data'] as List;
        } else {
          rawList = const [];
        }
      } else if (rawData is List) {
        rawList = rawData;
      } else {
        rawList = const [];
      }

      final allUsers = rawList
          .whereType<Map<String, dynamic>>()
          .map(AdminUserModel.fromJson)
          .toList();

      final total = allUsers.length;
      final startIndex = (page - 1) * limit;
      final paginatedUsers = (startIndex < total)
          ? allUsers.skip(startIndex).take(limit).toList()
          : <AdminUserModel>[];

      return Result.success(AdminUsersPage(
        users: paginatedUsers.isNotEmpty ? paginatedUsers : allUsers,
        total: total,
        page: page,
        limit: limit,
      ));
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to fetch users: $e'));
    }
  }
}
