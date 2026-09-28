import 'http_method.dart';

/// Low-level HTTP transport representation of a response.
class HttpResponseData {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const HttpResponseData({
    required this.statusCode,
    required this.body,
    required this.headers,
  });
}

/// Abstract contract for low-level HTTP network transport.
abstract interface class HttpTransport {
  Future<HttpResponseData> send({
    required Uri uri,
    required HttpMethod method,
    required Map<String, String> headers,
    String? body,
    Duration? timeout,
  });
}

/// Abstract contract for multipart/form-data HTTP network transport.
abstract interface class MultipartHttpTransport {
  Future<HttpResponseData> sendMultipart({
    required Uri uri,
    required HttpMethod method,
    required Map<String, String> headers,
    required List<int> fileBytes,
    required String filename,
    required String fileField,
    Map<String, String>? fields,
    Duration? timeout,
  });
}
