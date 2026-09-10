import 'user_model.dart';

/// Authentication response containing the authenticated user and bearer JWT token.
class AuthResponseModel {
  final UserModel user;
  final String token;

  const AuthResponseModel({
    required this.user,
    required this.token,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>? ?? {};
    final token = json['token'] as String? ?? '';

    return AuthResponseModel(
      user: UserModel.fromJson(userJson),
      token: token,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'token': token,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthResponseModel &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          token == other.token;

  @override
  int get hashCode => user.hashCode ^ token.hashCode;

  @override
  String toString() => 'AuthResponseModel(user: ${user.fullName}, token: [REDACTED])';
}
