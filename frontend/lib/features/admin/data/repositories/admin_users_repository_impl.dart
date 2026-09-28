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

  @override
  Future<Result<AdminUserModel>> createStaffAccount({
    required String storeId,
    required String name,
    required String email,
    String? phone,
    required String role,
    required String password,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name.trim(),
        'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'role': role.trim().toUpperCase(),
        'password': password,
        'storeId': storeId,
      };

      final response = await _apiClient.post<dynamic>(
        '/users/staff',
        body: body,
      );

      final dynamic rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        final userData = rawData['user'] is Map<String, dynamic>
            ? rawData['user'] as Map<String, dynamic>
            : (rawData['data'] is Map<String, dynamic>
                ? rawData['data'] as Map<String, dynamic>
                : rawData);
        return Result.success(AdminUserModel.fromJson(userData));
      }
      return Result.failure(
        const ServerFailure(
          message: 'Invalid staff creation response received from server.',
        ),
      );
    } on ConflictException catch (e) {
      return Result.failure(
        ConflictFailure(
          message: e.message.isNotEmpty
              ? e.message
              : 'An account with this email or phone number already exists.',
          statusCode: 409,
        ),
      );
    } on ValidationException catch (e) {
      return Result.failure(
        ValidationFailure(
          message: e.message,
          statusCode: e.statusCode ?? 400,
          fieldErrors: e.validationErrors,
        ),
      );
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to create staff account: $e'),
      );
    }
  }

  @override
  Future<Result<AdminUserModel>> updateStaffAccount({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? password,
    String? role,
    String? storeId,
    bool? isActive,
  }) async {
    try {
      final body = <String, dynamic>{
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (password != null && password.isNotEmpty) 'password': password,
        if (role != null && role.trim().isNotEmpty)
          'role': role.trim().toUpperCase(),
        if (storeId != null && storeId.trim().isNotEmpty)
          'storeId': storeId.trim(),
        if (isActive != null) 'isActive': isActive,
      };

      final response = await _apiClient.patch<dynamic>(
        '/users/staff/$userId',
        body: body,
      );

      final dynamic rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        final userData = rawData['user'] is Map<String, dynamic>
            ? rawData['user'] as Map<String, dynamic>
            : (rawData['data'] is Map<String, dynamic>
                ? rawData['data'] as Map<String, dynamic>
                : rawData);
        return Result.success(AdminUserModel.fromJson(userData));
      }
      return Result.failure(
        const ServerFailure(
          message: 'Invalid staff update response received from server.',
        ),
      );
    } on ConflictException catch (e) {
      return Result.failure(
        ConflictFailure(
          message: e.message.isNotEmpty
              ? e.message
              : 'An account with this email or phone number already exists.',
          statusCode: 409,
        ),
      );
    } on ValidationException catch (e) {
      return Result.failure(
        ValidationFailure(
          message: e.message,
          statusCode: e.statusCode ?? 400,
          fieldErrors: e.validationErrors,
        ),
      );
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to update staff account: $e'),
      );
    }
  }

  @override
  Future<Result<void>> deleteStaffAccount(String userId) async {
    try {
      await _apiClient.delete<dynamic>('/users/staff/$userId');
      return Result.success(null);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to delete staff account: $e'),
      );
    }
  }
}

