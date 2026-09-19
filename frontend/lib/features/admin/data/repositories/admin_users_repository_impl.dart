import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/admin_user_model.dart';
import '../../domain/repositories/admin_users_repository.dart';

/// Concrete [AdminUsersRepository] communicating with `GET /users`.
class AdminUsersRepositoryImpl implements AdminUsersRepository {
  final ApiClient _apiClient;

  const AdminUsersRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<Result<AdminUsersPage>> getUsers({
    int page = 1,
    int limit = 50,
    String? role,
  }) async {
    try {
      String? backendRole;
      if (role != null && role.isNotEmpty && role.toUpperCase() != 'ALL') {
        final normalized = role.trim().toUpperCase();
        switch (normalized) {
          case 'CUSTOMER':
            backendRole = 'CUSTOMER';
            break;
          case 'STAFF':
          case 'STORE_STAFF':
            backendRole = 'STAFF';
            break;
          case 'MANAGER':
          case 'STORE_MANAGER':
            backendRole = 'MANAGER';
            break;
          case 'SUPER_ADMIN':
          case 'ADMIN':
            backendRole = 'SUPER_ADMIN';
            break;
          case 'DRIVER':
          case 'DELIVERY_RIDER':
            // Railway /users role query does not support DRIVER
            backendRole = null;
            break;
          default:
            backendRole = normalized;
        }
      }

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (backendRole != null) 'role': backendRole,
      };

      final response = await _apiClient.get<dynamic>(
        '/users',
        queryParameters: queryParams,
      );

      final dynamic rawData = response.data;
      final List<dynamic> rawList;
      int? serverTotal;

      if (rawData is Map<String, dynamic>) {
        if (rawData['data'] is List) {
          rawList = rawData['data'] as List;
          if (rawData['total'] is int) {
            serverTotal = rawData['total'] as int;
          }
        } else if (rawData['users'] is List) {
          rawList = rawData['users'] as List;
          if (rawData['total'] is int) {
            serverTotal = rawData['total'] as int;
          }
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

      final total = serverTotal ?? allUsers.length;
      final paginatedUsers = serverTotal != null
          ? allUsers
          : ((page - 1) * limit < total
                ? allUsers.skip((page - 1) * limit).take(limit).toList()
                : <AdminUserModel>[]);

      return Result.success(
        AdminUsersPage(
          users: paginatedUsers,
          total: total,
          page: page,
          limit: limit,
        ),
      );
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to fetch users: $e'),
      );
    }
  }
}
