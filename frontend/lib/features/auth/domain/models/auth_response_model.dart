import 'user_model.dart';

/// Authentication response containing the authenticated user and bearer JWT token.
class AuthResponseModel {
  final UserModel user;
  final String token;
  final String? refreshToken;
  final bool isNew;

  const AuthResponseModel({
    required this.user,
    required this.token,
    this.refreshToken,
    this.isNew = false,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>? ?? {};
    final token =
        json['token'] as String? ?? json['accessToken'] as String? ?? '';
    final refreshToken =
        json['refreshToken'] as String? ?? json['refresh_token'] as String?;
    final isNew = json['isNew'] as bool? ?? json['is_new'] as bool? ?? false;

    return AuthResponseModel(
      user: UserModel.fromJson(userJson),
      token: token,
      refreshToken: refreshToken,
      isNew: isNew,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'token': token,
      if (refreshToken != null) 'refreshToken': refreshToken,
      'isNew': isNew,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthResponseModel &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          token == other.token &&
          refreshToken == other.refreshToken &&
          isNew == other.isNew;

  @override
  int get hashCode =>
      user.hashCode ^ token.hashCode ^ refreshToken.hashCode ^ isNew.hashCode;

  @override
  String toString() =>
      'AuthResponseModel(user: ${user.fullName}, token: [REDACTED])';
}
