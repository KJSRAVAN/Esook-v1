/// Supported HTTP request methods.
enum HttpMethod {
  get('GET'),
  post('POST'),
  patch('PATCH'),
  delete('DELETE');

  final String value;
  const HttpMethod(this.value);
}
