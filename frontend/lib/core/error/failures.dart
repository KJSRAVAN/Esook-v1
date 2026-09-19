import 'exceptions.dart';

/// Base class for domain-level failure representations passed to the UI layer.
sealed class AppFailure {
  final String message;
  final int? statusCode;

  const AppFailure({required this.message, this.statusCode});

  /// Factory to map internal [AppException] to a safe [AppFailure].
  factory AppFailure.fromException(AppException exception) {
    switch (exception) {
      case NetworkException():
        return NetworkFailure(
          message: exception.message,
          statusCode: exception.statusCode,
        );
      case UnauthorizedException():
        return UnauthorizedFailure(
          message: exception.message,
          statusCode: exception.statusCode,
        );
      case ForbiddenException():
        return ForbiddenFailure(
          message: exception.message,
          statusCode: exception.statusCode,
        );
      case ValidationException():
        return ValidationFailure(
          message: exception.message,
          statusCode: exception.statusCode,
          fieldErrors: exception.validationErrors,
        );
      case ConflictException():
        return ConflictFailure(
          message: exception.message,
          statusCode: exception.statusCode,
        );
      case RateLimitException():
        return RateLimitFailure(
          message: exception.message,
          statusCode: exception.statusCode,
        );
      case NotFoundException():
        return NotFoundFailure(
          message: exception.message,
          statusCode: exception.statusCode,
        );
      case ServerException():
        return ServerFailure(
          message: exception.message,
          statusCode: exception.statusCode,
        );
      case UnknownException():
        return UnknownFailure(
          message: exception.message,
          statusCode: exception.statusCode,
        );
    }
  }

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode)';
}

/// Network connectivity / socket / timeout failure.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({required super.message, super.statusCode});
}

/// Authentication failure (401).
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({required super.message, super.statusCode = 401});
}

/// Authorization / permission failure (403).
final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure({required super.message, super.statusCode = 403});
}

/// Validation failure containing optional field error mappings (400, 422).
final class ValidationFailure extends AppFailure {
  final Map<String, dynamic>? fieldErrors;

  const ValidationFailure({
    required super.message,
    super.statusCode = 400,
    this.fieldErrors,
  });
}

/// Resource conflict failure (409).
final class ConflictFailure extends AppFailure {
  const ConflictFailure({required super.message, super.statusCode = 409});
}

/// Rate limit exceeded failure (429).
final class RateLimitFailure extends AppFailure {
  const RateLimitFailure({required super.message, super.statusCode = 429});
}

/// Resource not found failure (404).
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({required super.message, super.statusCode = 404});
}

/// Server error failure (5xx).
final class ServerFailure extends AppFailure {
  const ServerFailure({required super.message, super.statusCode = 500});
}

/// Generic unexpected failure.
final class UnknownFailure extends AppFailure {
  const UnknownFailure({required super.message, super.statusCode});
}
