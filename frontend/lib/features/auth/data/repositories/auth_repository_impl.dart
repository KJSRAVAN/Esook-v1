import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/auth_response_model.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

/// Concrete [AuthRepository] implementation communicating with backend endpoints and secure storage.
class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;
  final SecureStorage _secureStorage;
  UserModel? _currentUser;

  AuthRepositoryImpl({
    required ApiClient apiClient,
    required SecureStorage secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage;

  UserModel? get currentUser => _currentUser;

  @override
  Future<Result<AuthResponseModel>> signupCustomer({
    required String phoneNumber,
    required String fullName,
    required String password,
    String? address,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/signup',
        body: {
          'phone_number': phoneNumber,
          'full_name': fullName,
          'password': password,
          if (address != null && address.isNotEmpty) 'address': address,
        },
      );

      final authResponse = AuthResponseModel.fromJson(response.data);
      await _secureStorage.write(key: StorageKeys.authToken, value: authResponse.token);
      _currentUser = authResponse.user;

      return Result.success(authResponse);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Signup failed: $e'));
    }
  }

  @override
  Future<Result<AuthResponseModel>> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/login',
        body: {
          'phone_number': phoneNumber,
          'password': password,
        },
      );

      final authResponse = AuthResponseModel.fromJson(response.data);
      await _secureStorage.write(key: StorageKeys.authToken, value: authResponse.token);
      _currentUser = authResponse.user;

      return Result.success(authResponse);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Login failed: $e'));
    }
  }

  @override
  Future<Result<String>> requestAdminMagicLink({
    required String email,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/admin/request-magic-link',
        body: {'email': email},
      );

      final message = response.data['message'] as String? ?? 'Login link requested';
      return Result.success(message);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Magic link request failed: $e'));
    }
  }

  @override
  Future<Result<AuthResponseModel>> verifyAdminMagicLink({
    required String token,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/admin/verify-magic-link',
        body: {'token': token},
      );

      final authResponse = AuthResponseModel.fromJson(response.data);
      await _secureStorage.write(key: StorageKeys.authToken, value: authResponse.token);
      _currentUser = authResponse.user;

      return Result.success(authResponse);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Magic link verification failed: $e'));
    }
  }

  @override
  Future<Result<UserModel>> getCurrentUser() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/auth/me');
      final userJson = response.data['user'] as Map<String, dynamic>? ?? response.data;
      final user = UserModel.fromJson(userJson);
      _currentUser = user;

      return Result.success(user);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to fetch user profile: $e'));
    }
  }

  @override
  Future<Result<UserModel?>> checkSession() async {
    try {
      final token = await _secureStorage.read(key: StorageKeys.authToken);
      if (token == null || token.trim().isEmpty) {
        _currentUser = null;
        return Result.success(null);
      }

      final userResult = await getCurrentUser();
      if (userResult.isSuccess) {
        return Result.success(userResult.dataOrNull);
      }

      final failure = userResult.failureOrNull;
      if (failure is UnauthorizedFailure || failure is ForbiddenFailure) {
        await logout();
        return Result.success(null);
      }

      return Result.failure(failure ?? const UnknownFailure(message: 'Session verification failed'));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Session check failed: $e'));
    }
  }

  @override
  Future<void> logout() async {
    await _secureStorage.delete(key: StorageKeys.authToken);
    _currentUser = null;
  }
}
