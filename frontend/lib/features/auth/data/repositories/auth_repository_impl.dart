import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/models/auth_response_model.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/user_role.dart';
import '../../domain/repositories/auth_repository.dart';

/// Concrete [AuthRepository] implementation communicating with backend endpoints and secure storage.
class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;
  final SecureStorage _secureStorage;
  UserModel? _currentUser;

  AuthRepositoryImpl({
    required ApiClient apiClient,
    required SecureStorage secureStorage,
  }) : _apiClient = apiClient,
       _secureStorage = secureStorage;

  UserModel? get currentUser => _currentUser;

  @override
  Future<Result<String>> sendOtp({
    required String phone,
    String? email,
    String? name,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/otp/send',
        body: {
          'phone': phone,
          if (email != null && email.isNotEmpty) 'email': email,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );

      final message =
          response.data['message'] as String? ?? 'Verification code sent';
      return Result.success(message);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to send OTP: $e'));
    }
  }

  @override
  Future<Result<AuthResponseModel>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        body: {'phone': phone, 'code': code},
      );

      final authResponse = AuthResponseModel.fromJson(response.data);
      if (authResponse.token.isNotEmpty) {
        await _secureStorage.write(
          key: StorageKeys.authToken,
          value: authResponse.token,
        );
      }
      if (authResponse.refreshToken != null &&
          authResponse.refreshToken!.isNotEmpty) {
        await _secureStorage.write(
          key: StorageKeys.refreshToken,
          value: authResponse.refreshToken!,
        );
      }
      if (authResponse.user.id.isNotEmpty) {
        await _secureStorage.write(
          key: StorageKeys.userId,
          value: authResponse.user.id,
        );
      }
      await _secureStorage.write(
        key: StorageKeys.userRole,
        value: authResponse.user.role.value,
      );

      _currentUser = authResponse.user;
      return Result.success(authResponse);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to verify OTP: $e'),
      );
    }
  }

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
      await _secureStorage.write(
        key: StorageKeys.authToken,
        value: authResponse.token,
      );
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
    String? phoneNumber,
    String? email,
    required String password,
  }) async {
    try {
      final body = <String, dynamic>{
        'password': password,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phone': phoneNumber.trim(),
      };

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/staff/login',
        body: body,
      );

      final authResponse = AuthResponseModel.fromJson(response.data);
      if (authResponse.token.isNotEmpty) {
        await _secureStorage.write(
          key: StorageKeys.authToken,
          value: authResponse.token,
        );
      }
      if (authResponse.refreshToken != null &&
          authResponse.refreshToken!.isNotEmpty) {
        await _secureStorage.write(
          key: StorageKeys.refreshToken,
          value: authResponse.refreshToken!,
        );
      }
      if (authResponse.user.id.isNotEmpty) {
        await _secureStorage.write(
          key: StorageKeys.userId,
          value: authResponse.user.id,
        );
      }
      await _secureStorage.write(
        key: StorageKeys.userRole,
        value: authResponse.user.role.value,
      );

      _currentUser = authResponse.user;
      return Result.success(authResponse);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Login failed: $e'));
    }
  }

  @override
  Future<Result<AuthResponseModel>> refreshToken() async {
    try {
      final storedRefreshToken = await _secureStorage.read(
        key: StorageKeys.refreshToken,
      );
      if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
        return Result.failure(
          const UnauthorizedFailure(message: 'No refresh token stored'),
        );
      }

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/refresh',
        body: {'refreshToken': storedRefreshToken},
      );

      final newAccessToken =
          response.data['accessToken'] as String? ??
          response.data['token'] as String? ??
          '';
      final newRefreshToken =
          response.data['refreshToken'] as String? ?? storedRefreshToken;

      if (newAccessToken.isNotEmpty) {
        await _secureStorage.write(
          key: StorageKeys.authToken,
          value: newAccessToken,
        );
      }
      if (newRefreshToken.isNotEmpty) {
        await _secureStorage.write(
          key: StorageKeys.refreshToken,
          value: newRefreshToken,
        );
      }

      final user =
          _currentUser ??
          const UserModel(
            id: '',
            phoneNumber: '',
            fullName: '',
            role: UserRole.customer,
          );

      final authResponse = AuthResponseModel(
        user: user,
        token: newAccessToken,
        refreshToken: newRefreshToken,
      );
      return Result.success(authResponse);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to refresh token: $e'),
      );
    }
  }

  @override
  Future<Result<String>> requestAdminMagicLink({required String email}) async {
    return Result.failure(
      const ValidationFailure(
        message:
            'Magic link authentication is no longer supported. Please use staff/admin login.',
      ),
    );
  }

  @override
  Future<Result<AuthResponseModel>> verifyAdminMagicLink({
    required String token,
  }) async {
    return Result.failure(
      const ValidationFailure(
        message:
            'Magic link authentication is no longer supported. Please use staff/admin login.',
      ),
    );
  }

  @override
  Future<Result<UserModel>> getCurrentUser() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/auth/me');
      final userJson =
          response.data['user'] as Map<String, dynamic>? ?? response.data;
      final user = UserModel.fromJson(userJson);
      _currentUser = user;

      return Result.success(user);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to fetch user profile: $e'),
      );
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

      return Result.failure(
        failure ?? const UnknownFailure(message: 'Session verification failed'),
      );
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Session check failed: $e'),
      );
    }
  }

  @override
  Future<Result<UserModel>> updateProfile({String? name, String? email}) async {
    try {
      final body = <String, dynamic>{
        if (name != null) 'name': name,
        if (email != null) 'email': email,
      };

      final response = await _apiClient.patch<Map<String, dynamic>>(
        '/users/me',
        body: body,
      );

      final userJson =
          response.data['user'] as Map<String, dynamic>? ?? response.data;
      final updatedUser = UserModel.fromJson(userJson);
      _currentUser = updatedUser;

      return Result.success(updatedUser);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to update profile: $e'),
      );
    }
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await _secureStorage.read(
        key: StorageKeys.refreshToken,
      );
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiClient.post<dynamic>(
          '/auth/logout',
          body: {'refreshToken': refreshToken},
        );
      }
    } catch (_) {
      // Best-effort server notification; local credentials must always be cleared
    } finally {
      await _secureStorage.delete(key: StorageKeys.authToken);
      await _secureStorage.delete(key: StorageKeys.refreshToken);
      await _secureStorage.delete(key: StorageKeys.userId);
      await _secureStorage.delete(key: StorageKeys.userRole);
      _currentUser = null;
    }
  }
}
