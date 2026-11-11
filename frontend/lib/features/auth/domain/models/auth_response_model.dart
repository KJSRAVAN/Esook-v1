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
    Map<String, dynamic> userJson;
    if (json['user'] is Map<String, dynamic>) {
      userJson = json['user'] as Map<String, dynamic>;
    } else if (json['data'] is Map<String, dynamic> &&
        (json['data'] as Map<String, dynamic>)['user'] is Map<String, dynamic>) {
      userJson = (json['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>;
    } else if (json['data'] is Map<String, dynamic> &&
        (json['data'] as Map<String, dynamic>)['role'] != null) {
      userJson = json['data'] as Map<String, dynamic>;
    } else if (json['role'] != null || json['id'] != null) {
      userJson = json;
    } else {
      userJson = {};
    }

    final token =
        json['token'] as String? ??
        json['accessToken'] as String? ??
        json['access_token'] as String? ??
        (json['data'] is Map<String, dynamic>
            ? (json['data'] as Map<String, dynamic>)['token'] as String? ??
                (json['data'] as Map<String, dynamic>)['accessToken'] as String?
            : null) ??
        '';
    final refreshToken =
        json['refreshToken'] as String? ??
        json['refresh_token'] as String? ??
        (json['data'] is Map<String, dynamic>
            ? (json['data'] as Map<String, dynamic>)['refreshToken'] as String? ??
                (json['data'] as Map<String, dynamic>)['refresh_token'] as String?
            : null);
    final isNew = json['isNew'] as bool? ??
        json['is_new'] as bool? ??
        (json['data'] is Map<String, dynamic>
            ? (json['data'] as Map<String, dynamic>)['isNew'] as bool? ??
                (json['data'] as Map<String, dynamic>)['is_new'] as bool?
            : null) ??
        false;

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
