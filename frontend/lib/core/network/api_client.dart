import 'dart:convert';

import '../error/exceptions.dart';
import 'api_response.dart';
import 'http_method.dart';
import 'http_transport.dart';
import 'package_http_transport.dart';

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
}

/// Default implementation of [ApiClient].
class DefaultApiClient implements ApiClient {
  final String baseUrl;
  final HttpTransport _transport;
  final Future<String?> Function()? _tokenProvider;
  final Duration timeout;

  DefaultApiClient({
    required this.baseUrl,
    HttpTransport? transport,
    Future<String?> Function()? tokenProvider,
    this.timeout = const Duration(seconds: 15),
  })  : _transport = transport ?? PackageHttpTransport(),
        _tokenProvider = tokenProvider;

  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
  }) =>
      _request<T>(
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
  }) =>
      _request<T>(
        path: path,
        method: HttpMethod.post,
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
  }) =>
      _request<T>(
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
  }) =>
      _request<T>(
        path: path,
        method: HttpMethod.delete,
        body: body,
        headers: headers,
        queryParameters: queryParameters,
        fromJson: fromJson,
      );

  Future<ApiResponse<T>> _request<T>({
    required String path,
    required HttpMethod method,
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJson,
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

    return _handleResponse<T>(responseData, fromJson);
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase$cleanPath';

    final uri = Uri.parse(fullUrl);
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final stringParams = queryParameters.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );

    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...stringParams,
    });
  }

  Future<Map<String, String>> _buildHeaders(Map<String, String>? customHeaders) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
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

    final errorMessage = _extractErrorMessage(decodedJson) ?? 'Request failed with status $statusCode';

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
