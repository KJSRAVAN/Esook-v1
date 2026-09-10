/// Standardized wrapper for API responses.
class ApiResponse<T> {
  final int statusCode;
  final T data;
  final Map<String, String> headers;

  const ApiResponse({
    required this.statusCode,
    required this.data,
    this.headers = const {},
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
