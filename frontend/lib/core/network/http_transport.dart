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
