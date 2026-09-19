import '../../../../core/utils/result.dart';
export '../../../../core/utils/result.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Contract for Authentication repository.
abstract interface class AuthRepository {
  /// Request 6-digit OTP code to phone number (Customer flow: POST /auth/otp/send).
  Future<Result<String>> sendOtp({
    required String phone,
    String? email,
    String? name,
  });

  /// Verify 6-digit OTP code and retrieve access token (Customer flow: POST /auth/otp/verify).
  Future<Result<AuthResponseModel>> verifyOtp({
    required String phone,
    required String code,
  });

  /// Customer self-registration.
  Future<Result<AuthResponseModel>> signupCustomer({
    required String phoneNumber,
    required String fullName,
    required String password,
    String? address,
  });

  /// Password login for Customer, Store Staff, Store Manager, Delivery Rider, and Super Admin (POST /auth/staff/login).
  Future<Result<AuthResponseModel>> login({
    String? phoneNumber,
    String? email,
    required String password,
  });

  /// Request super admin single-use magic link via email (Step 1).
  Future<Result<String>> requestAdminMagicLink({required String email});

  /// Redeem super admin single-use magic link token (Step 2).
  Future<Result<AuthResponseModel>> verifyAdminMagicLink({
    required String token,
  });

  /// Fetch authenticated user profile using stored bearer JWT.
  Future<Result<UserModel>> getCurrentUser();

  /// Bootstrap session: checks secure storage for token and validates against `/auth/me`.
  /// Returns `Result.success(user)` if valid session, `Result.success(null)` if unauthenticated/expired.
  Future<Result<UserModel?>> checkSession();

  /// Rotate and refresh JWT access token using stored refresh token (POST /auth/refresh).
  Future<Result<AuthResponseModel>> refreshToken();

  /// Update authenticated user's profile details (PATCH /users/me).
  ///
  /// Only [name] and [email] are accepted by the backend.
  Future<Result<UserModel>> updateProfile({String? name, String? email});

  /// Clear stored credentials and session state.
  Future<void> logout();
}
