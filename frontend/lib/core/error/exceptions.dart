/// Base class for all internal application exceptions.
sealed class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const AppException({
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => '$runtimeType(message: $message, statusCode: $statusCode)';
}

/// Thrown when network transport, connectivity, or timeout fails.
final class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.statusCode,
    super.details,
  });
}

/// Thrown when request authentication fails (401).
final class UnauthorizedException extends AppException {
  const UnauthorizedException({
    required super.message,
    super.statusCode = 401,
    super.details,
  });
}

/// Thrown when request authorization / permission fails (403).
final class ForbiddenException extends AppException {
  const ForbiddenException({
    required super.message,
    super.statusCode = 403,
    super.details,
  });
}

/// Thrown when input validation fails (400, 422).
final class ValidationException extends AppException {
  final Map<String, dynamic>? validationErrors;

  const ValidationException({
    required super.message,
    super.statusCode = 400,
    this.validationErrors,
    super.details,
  });
}

/// Thrown when a resource already exists or conflict occurs (409).
final class ConflictException extends AppException {
  const ConflictException({
    required super.message,
    super.statusCode = 409,
    super.details,
  });
}

/// Thrown when rate limit threshold is exceeded (429).
final class RateLimitException extends AppException {
  const RateLimitException({
    required super.message,
    super.statusCode = 429,
    super.details,
  });
}

/// Thrown when a requested resource is not found (404).
final class NotFoundException extends AppException {
  const NotFoundException({
    required super.message,
    super.statusCode = 404,
    super.details,
  });
}

/// Thrown when the backend returns a server error (500, 502, 503).
final class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.statusCode = 500,
    super.details,
  });
}

/// Thrown for unhandled or parsing errors.
final class UnknownException extends AppException {
  const UnknownException({
    required super.message,
    super.statusCode,
    super.details,
  });
}
