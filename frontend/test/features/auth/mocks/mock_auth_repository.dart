import 'package:esouq/core/error/failures.dart';
import 'package:esouq/features/auth/domain/models/auth_response_model.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/auth/domain/repositories/auth_repository.dart';

/// Test mock/fake repository providing controllable responses for UI testing.
class MockAuthRepository implements AuthRepository {
  Result<String>? sendOtpResult;
  Result<AuthResponseModel>? verifyOtpResult;
  Result<AuthResponseModel>? signupResult;
  Result<AuthResponseModel>? loginResult;
  Result<String>? requestMagicLinkResult;
  Result<AuthResponseModel>? verifyMagicLinkResult;
  Result<UserModel>? getCurrentUserResult;
  Result<UserModel?>? checkSessionResult;

  int sendOtpCallCount = 0;
  int verifyOtpCallCount = 0;
  int signupCallCount = 0;
  int loginCallCount = 0;
  int requestMagicLinkCallCount = 0;
  int verifyMagicLinkCallCount = 0;
  int checkSessionCallCount = 0;
  int logoutCallCount = 0;

  String? lastSendOtpPhone;
  String? lastSendOtpEmail;
  String? lastSendOtpName;
  String? lastVerifyOtpPhone;
  String? lastVerifyOtpCode;
  String? lastLoginPhone;
  String? lastLoginPassword;
  String? lastSignupPhone;
  String? lastSignupName;
  String? lastSignupPassword;
  String? lastSignupAddress;
  String? lastMagicLinkEmail;
  String? lastVerifyToken;

  UserModel? currentUser;

  @override
  Future<Result<String>> sendOtp({
    required String phone,
    String? email,
    String? name,
  }) async {
    sendOtpCallCount++;
    lastSendOtpPhone = phone;
    lastSendOtpEmail = email;
    lastSendOtpName = name;

    if (sendOtpResult != null) return sendOtpResult!;
    return Result.success('Verification code sent');
  }

  @override
  Future<Result<AuthResponseModel>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    verifyOtpCallCount++;
    lastVerifyOtpPhone = phone;
    lastVerifyOtpCode = code;

    if (verifyOtpResult != null) return verifyOtpResult!;

    final user = UserModel(
      id: 'cust_otp_1',
      phoneNumber: phone,
      fullName: 'Customer',
      role: UserRole.customer,
    );
    currentUser = user;
    return Result.success(AuthResponseModel(
      user: user,
      token: 'mock_otp_jwt_token',
      refreshToken: 'mock_otp_refresh_token',
    ));
  }

  @override
  Future<Result<AuthResponseModel>> signupCustomer({
    required String phoneNumber,
    required String fullName,
    required String password,
    String? address,
  }) async {
    signupCallCount++;
    lastSignupPhone = phoneNumber;
    lastSignupName = fullName;
    lastSignupPassword = password;
    lastSignupAddress = address;

    if (signupResult != null) return signupResult!;

    final user = UserModel(
      id: 'cust_1',
      phoneNumber: phoneNumber,
      fullName: fullName,
      role: UserRole.customer,
      address: address,
    );
    currentUser = user;
    return Result.success(AuthResponseModel(user: user, token: 'mock_jwt_token'));
  }

  @override
  Future<Result<AuthResponseModel>> login({
    required String phoneNumber,
    required String password,
  }) async {
    loginCallCount++;
    lastLoginPhone = phoneNumber;
    lastLoginPassword = password;

    if (loginResult != null) return loginResult!;

    final user = UserModel(
      id: 'usr_1',
      phoneNumber: phoneNumber,
      fullName: 'Test User',
      role: UserRole.customer,
    );
    currentUser = user;
    return Result.success(AuthResponseModel(user: user, token: 'mock_jwt_token'));
  }

  @override
  Future<Result<String>> requestAdminMagicLink({
    required String email,
  }) async {
    requestMagicLinkCallCount++;
    lastMagicLinkEmail = email;

    if (requestMagicLinkResult != null) return requestMagicLinkResult!;
    return Result.success('Login link requested successfully');
  }

  @override
  Future<Result<AuthResponseModel>> verifyAdminMagicLink({
    required String token,
  }) async {
    verifyMagicLinkCallCount++;
    lastVerifyToken = token;

    if (verifyMagicLinkResult != null) return verifyMagicLinkResult!;

    final user = UserModel(
      id: 'admin_1',
      phoneNumber: '+96890000000',
      email: 'admin@esouq.com',
      fullName: 'Super Admin',
      role: UserRole.superAdmin,
    );
    currentUser = user;
    return Result.success(AuthResponseModel(user: user, token: 'mock_admin_jwt'));
  }

  @override
  Future<Result<UserModel>> getCurrentUser() async {
    if (getCurrentUserResult != null) return getCurrentUserResult!;
    if (currentUser != null) return Result.success(currentUser!);
    return Result.failure(const UnauthorizedFailure(message: 'Not authenticated'));
  }

  @override
  Future<Result<UserModel?>> checkSession() async {
    checkSessionCallCount++;
    if (checkSessionResult != null) return checkSessionResult!;
    return Result.success(currentUser);
  }

  Result<AuthResponseModel>? refreshTokenResult;
  int refreshTokenCallCount = 0;

  @override
  Future<Result<AuthResponseModel>> refreshToken() async {
    refreshTokenCallCount++;
    if (refreshTokenResult != null) return refreshTokenResult!;
    final user = currentUser ?? const UserModel(
      id: 'cust_refresh_1',
      phoneNumber: '+966501234567',
      fullName: 'Customer',
      role: UserRole.customer,
    );
    return Result.success(AuthResponseModel(
      user: user,
      token: 'mock_refreshed_jwt_token',
      refreshToken: 'mock_new_refresh_token',
    ));
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
    currentUser = null;
  }
}
