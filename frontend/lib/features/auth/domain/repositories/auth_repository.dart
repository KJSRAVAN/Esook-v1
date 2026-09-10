import '../../../../core/utils/result.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Contract for Authentication repository.
abstract interface class AuthRepository {
  /// Customer self-registration.
  Future<Result<AuthResponseModel>> signupCustomer({
    required String phoneNumber,
    required String fullName,
    required String password,
    String? address,
  });

  /// Password login for Customer, Store Staff, Store Manager, Delivery Rider.
  Future<Result<AuthResponseModel>> login({
    required String phoneNumber,
    required String password,
  });

  /// Request super admin single-use magic link via email (Step 1).
  Future<Result<String>> requestAdminMagicLink({
    required String email,
  });

  /// Redeem super admin single-use magic link token (Step 2).
  Future<Result<AuthResponseModel>> verifyAdminMagicLink({
    required String token,
  });

  /// Fetch authenticated user profile using stored bearer JWT.
  Future<Result<UserModel>> getCurrentUser();

  /// Bootstrap session: checks secure storage for token and validates against `/auth/me`.
  /// Returns `Result.success(user)` if valid session, `Result.success(null)` if unauthenticated/expired.
  Future<Result<UserModel?>> checkSession();

  /// Clear stored credentials and session state.
  Future<void> logout();
}
