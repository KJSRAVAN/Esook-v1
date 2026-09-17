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
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (role != null && role.isNotEmpty && role != 'ALL') 'role': role.toUpperCase(),
      };

      final response = await _apiClient.get<dynamic>(
        '/users',
        queryParameters: queryParams,
      );

      final dynamic rawData = response.data;
      final List<dynamic> rawList;
      int total = 0;
      int resPage = page;
      int resLimit = limit;

      if (rawData is Map<String, dynamic>) {
        if (rawData['data'] is List) {
          rawList = rawData['data'] as List;
        } else if (rawData['users'] is List) {
          rawList = rawData['users'] as List;
        } else {
          rawList = const [];
        }
        total = (rawData['total'] as num?)?.toInt() ?? rawList.length;
        resPage = (rawData['page'] as num?)?.toInt() ?? page;
        resLimit = (rawData['limit'] as num?)?.toInt() ?? limit;
      } else if (rawData is List) {
        rawList = rawData;
        total = rawList.length;
      } else {
        rawList = const [];
      }

      final users = rawList
          .whereType<Map<String, dynamic>>()
          .map(AdminUserModel.fromJson)
          .toList();

      return Result.success(AdminUsersPage(
        users: users,
        total: total,
        page: resPage,
        limit: resLimit,
      ));
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to fetch users: $e'));
    }
  }
}
