import 'dart:convert';

import '../constants/storage_keys.dart';
import '../error/exceptions.dart';
import '../storage/secure_storage.dart';
import 'api_response.dart';
import 'http_method.dart';
import 'http_transport.dart';
import 'package_http_transport.dart';

export 'api_response.dart';

/// Contract for the application's central API client.
abstract interface class ApiClient {
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
  });

  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
  });

  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
  });

  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
  });

  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
  });

  Future<ApiResponse<T>> postMultipart<T>(
    String path, {
    required List<int> fileBytes,
    required String filename,
    String fileField = 'file',
    Map<String, String>? fields,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
    Duration? timeout,
  });
}

/// Default implementation of [ApiClient].
class DefaultApiClient implements ApiClient {
  final String baseUrl;
  final HttpTransport _transport;
  final Future<String?> Function()? _tokenProvider;
  final Future<bool> Function()? tokenRefresher;
  final Future<void> Function()? onSessionExpired;
  final SecureStorage? secureStorage;
  final Duration timeout;

  Future<bool>? _inFlightRefresh;

  DefaultApiClient({
    required this.baseUrl,
    HttpTransport? transport,
    Future<String?> Function()? tokenProvider,
    this.tokenRefresher,
    this.onSessionExpired,
    this.secureStorage,
    this.timeout = const Duration(seconds: 35),
  }) : _transport = transport ?? PackageHttpTransport(),
       _tokenProvider = tokenProvider ??
           (secureStorage != null
               ? () => secureStorage.read(key: StorageKeys.authToken)
               : null);

  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
  }) => _request<T>(
    path: path,
    method: HttpMethod.get,
    headers: headers,
    queryParameters: queryParameters,
    fromJson: fromJson,
  );

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
  }) => _request<T>(
    path: path,
    method: HttpMethod.post,
    body: body,
    headers: headers,
    queryParameters: queryParameters,
    fromJson: fromJson,
  );

  @override
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
  }) => _request<T>(
    path: path,
    method: HttpMethod.put,
    body: body,
    headers: headers,
    queryParameters: queryParameters,
    fromJson: fromJson,
  );

  @override
  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
  }) => _request<T>(
    path: path,
    method: HttpMethod.patch,
    body: body,
    headers: headers,
    queryParameters: queryParameters,
    fromJson: fromJson,
  );

  @override
  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
  }) => _request<T>(
    path: path,
    method: HttpMethod.delete,
    body: body,
    headers: headers,
    queryParameters: queryParameters,
    fromJson: fromJson,
  );

  @override
  Future<ApiResponse<T>> postMultipart<T>(
    String path, {
    required List<int> fileBytes,
    required String filename,
    String fileField = 'file',
    Map<String, String>? fields,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
    Duration? timeout,
    bool isRetry = false,
  }) async {
    final effectiveTimeout = timeout ?? this.timeout;
    final uri = _buildUri(path, queryParameters);
    final requestHeaders = await _buildHeaders(headers, isMultipart: true);

    final HttpResponseData responseData;
    if (_transport is MultipartHttpTransport) {
      responseData = await (_transport as MultipartHttpTransport).sendMultipart(
        uri: uri,
        method: HttpMethod.post,
        headers: requestHeaders,
        fileBytes: fileBytes,
        filename: filename,
        fileField: fileField,
        fields: fields,
        timeout: effectiveTimeout,
      );
    } else {
      throw UnsupportedError(
        'The configured HttpTransport does not support multipart requests',
      );
    }

    if (responseData.statusCode == 401 && !isRetry && !_isAuthEndpoint(path)) {
      final refreshed = await _performTokenRefresh();
      if (refreshed) {
        return postMultipart<T>(
          path,
          fileBytes: fileBytes,
          filename: filename,
          fileField: fileField,
          fields: fields,
          headers: headers,
          queryParameters: queryParameters,
          fromJson: fromJson,
          timeout: timeout,
          isRetry: true,
        );
      }
    }

    return _handleResponse<T>(responseData, fromJson);
  }

  Future<ApiResponse<T>> _request<T>({
    required String path,
    required HttpMethod method,
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
    bool isRetry = false,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final requestHeaders = await _buildHeaders(headers);
    final serializedBody = _serializeBody(body);

    final responseData = await _transport.send(
      uri: uri,
      method: method,
      headers: requestHeaders,
      body: serializedBody,
      timeout: timeout,
    );

    if (responseData.statusCode == 401 && !isRetry && !_isAuthEndpoint(path)) {
      final refreshed = await _performTokenRefresh();
      if (refreshed) {
        return _request<T>(
          path: path,
          method: method,
          body: body,
          headers: headers,
          queryParameters: queryParameters,
          fromJson: fromJson,
          isRetry: true,
        );
      }
    }

    return _handleResponse<T>(responseData, fromJson);
  }

  bool _isAuthEndpoint(String path) {
    final clean = path.toLowerCase();
    return clean.contains('/auth/login') ||
        clean.contains('/auth/staff-login') ||
        clean.contains('/auth/staff/login') ||
        clean.contains('/auth/customer/login') ||
        clean.contains('/auth/customer/signup') ||
        clean.contains('/auth/send-otp') ||
        clean.contains('/auth/otp/send') ||
        clean.contains('/auth/verify-otp') ||
        clean.contains('/auth/otp/verify') ||
        clean.contains('/auth/refresh') ||
        clean.contains('/auth/logout') ||
        clean.contains('/auth/register');
  }

  Future<bool> _performTokenRefresh() async {
    if (_inFlightRefresh != null) {
      return _inFlightRefresh!;
    }

    final future = _executeTokenRefresh();
    _inFlightRefresh = future;
    try {
      return await future;
    } finally {
      _inFlightRefresh = null;
    }
  }

  Future<bool> _executeTokenRefresh() async {
    if (tokenRefresher != null) {
      try {
        final success = await tokenRefresher!();
        if (!success) {
          await _clearSession();
        }
        return success;
      } catch (_) {
        await _clearSession();
        return false;
      }
    }

    if (secureStorage == null) {
      return false;
    }

    try {
      final storedRefreshToken = await secureStorage!.read(
        key: StorageKeys.refreshToken,
      );
      if (storedRefreshToken == null || storedRefreshToken.trim().isEmpty) {
        await _clearSession();
        return false;
      }

      final refreshUri = _buildUri('/auth/refresh', null);
      final refreshHeaders = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final refreshBody = jsonEncode({
        'refreshToken': storedRefreshToken.trim(),
      });

      final responseData = await _transport.send(
        uri: refreshUri,
        method: HttpMethod.post,
        headers: refreshHeaders,
        body: refreshBody,
        timeout: timeout,
      );

      if (responseData.statusCode >= 200 && responseData.statusCode < 300) {
        dynamic decoded;
        try {
          decoded = jsonDecode(responseData.body);
        } catch (_) {
          decoded = null;
        }

        if (decoded is Map<String, dynamic>) {
          final newAccessToken =
              decoded['accessToken'] as String? ??
              decoded['token'] as String?;
          final newRefreshToken =
              decoded['refreshToken'] as String? ?? storedRefreshToken;

          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            await secureStorage!.write(
              key: StorageKeys.authToken,
              value: newAccessToken,
            );
          }
          if (newRefreshToken.isNotEmpty) {
            await secureStorage!.write(
              key: StorageKeys.refreshToken,
              value: newRefreshToken,
            );
          }
          return true;
        }
      }

      await _clearSession();
      return false;
    } catch (_) {
      await _clearSession();
      return false;
    }
  }

  Future<void> _clearSession() async {
    if (onSessionExpired != null) {
      try {
        await onSessionExpired!();
      } catch (_) {}
    }
    if (secureStorage != null) {
      try {
        await secureStorage!.delete(key: StorageKeys.authToken);
        await secureStorage!.delete(key: StorageKeys.refreshToken);
        await secureStorage!.delete(key: StorageKeys.userId);
        await secureStorage!.delete(key: StorageKeys.userRole);
      } catch (_) {}
    }
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase$cleanPath';

    final uri = Uri.parse(fullUrl);
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final stringParams = queryParameters.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );

    return uri.replace(
      queryParameters: {...uri.queryParameters, ...stringParams},
    );
  }

  Future<Map<String, String>> _buildHeaders(
    Map<String, String>? customHeaders, {
    bool isMultipart = false,
  }) async {
    final headers = <String, String>{
      if (!isMultipart) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_tokenProvider != null) {
      final token = await _tokenProvider();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  String? _serializeBody(dynamic body) {
    if (body == null) return null;
    if (body is String) return body;
    return jsonEncode(body);
  }

  ApiResponse<T> _handleResponse<T>(
    HttpResponseData responseData,
    T Function(dynamic json)? fromJson,
  ) {
    final statusCode = responseData.statusCode;
    dynamic decodedJson;

    if (responseData.body.isNotEmpty) {
      try {
        decodedJson = jsonDecode(responseData.body);
      } catch (_) {
        decodedJson = responseData.body;
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      final T data;
      if (fromJson != null) {
        data = fromJson(decodedJson);
      } else {
        data = decodedJson as T;
      }

      return ApiResponse<T>(
        statusCode: statusCode,
        data: data,
        headers: responseData.headers,
      );
    }

    final errorMessage =
        _extractErrorMessage(decodedJson) ??
        'Request failed with status $statusCode';

    if (statusCode == 401) {
      throw UnauthorizedException(
        message: errorMessage,
        statusCode: statusCode,
        details: decodedJson,
      );
    }

    if (statusCode == 403) {
      throw ForbiddenException(
        message: errorMessage,
        statusCode: statusCode,
        details: decodedJson,
      );
    }

    if (statusCode == 409) {
      throw ConflictException(
        message: errorMessage,
        statusCode: statusCode,
        details: decodedJson,
      );
    }

    if (statusCode == 429) {
      throw RateLimitException(
        message: errorMessage,
        statusCode: statusCode,
        details: decodedJson,
      );
    }

    if (statusCode == 400 || statusCode == 422) {
      Map<String, dynamic>? validationErrors;
      if (decodedJson is Map<String, dynamic>) {
        if (decodedJson['errors'] is Map<String, dynamic>) {
          validationErrors = decodedJson['errors'] as Map<String, dynamic>;
        } else if (decodedJson['errors'] is List) {
          final list = decodedJson['errors'] as List;
          validationErrors = {
            for (var i = 0; i < list.length; i++) 'error_$i': list[i],
          };
        }
      }
      throw ValidationException(
        message: errorMessage,
        statusCode: statusCode,
        validationErrors: validationErrors,
        details: decodedJson,
      );
    }

    if (statusCode == 404) {
      throw NotFoundException(
        message: errorMessage,
        statusCode: statusCode,
        details: decodedJson,
      );
    }

    if (statusCode >= 500) {
      throw ServerException(
        message: errorMessage,
        statusCode: statusCode,
        details: decodedJson,
      );
    }

    throw UnknownException(
      message: errorMessage,
      statusCode: statusCode,
      details: decodedJson,
    );
  }

  String? _extractErrorMessage(dynamic json) {
    if (json is Map<String, dynamic>) {
      if (json['message'] is String) return json['message'] as String;
      if (json['error'] is String) return json['error'] as String;
      if (json['error'] is Map<String, dynamic>) {
        final errObj = json['error'] as Map<String, dynamic>;
        if (errObj['message'] is String) return errObj['message'] as String;
      }
      if (json['errors'] is List && (json['errors'] as List).isNotEmpty) {
        return (json['errors'] as List).first.toString();
      }
    }
    return null;
  }
}
