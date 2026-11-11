import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../error/exceptions.dart';
import 'http_method.dart';
import 'http_transport.dart';

/// Production [HttpTransport] implementation backed by cross-platform [http.Client].
///
/// Fully compatible across Android, iOS, Web, Windows, macOS, and Linux without
/// depending on platform-bound dart:io primitives.
class PackageHttpTransport implements HttpTransport, MultipartHttpTransport {
  final http.Client _client;

  PackageHttpTransport({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<HttpResponseData> send({
    required Uri uri,
    required HttpMethod method,
    required Map<String, String> headers,
    String? body,
    Duration? timeout,
  }) async {
    try {
      final request = http.Request(method.value, uri);
      request.headers.addAll(headers);

      if (body != null && body.isNotEmpty) {
        request.body = body;
      }

      final streamedResponseFuture = _client.send(request);
      final streamedResponse = timeout != null
          ? await streamedResponseFuture.timeout(
              timeout,
              onTimeout: () => throw const NetworkException(
                message:
                    'Connection timed out while waiting for server response',
              ),
            )
          : await streamedResponseFuture;

      final responseFuture = http.Response.fromStream(streamedResponse);
      final response = timeout != null
          ? await responseFuture.timeout(
              timeout,
              onTimeout: () => throw const NetworkException(
                message: 'Connection timed out while reading response stream',
              ),
            )
          : await responseFuture;

      return HttpResponseData(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(message: 'Network connection error: ${e.message}');
    } on TimeoutException catch (e) {
      throw NetworkException(
        message:
            'Request timed out: ${e.message ?? 'Server took too long to respond'}',
      );
    } on FormatException catch (e) {
      throw NetworkException(message: 'Invalid response format: ${e.message}');
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(message: 'Unexpected network error: $e');
    }
  }

  @override
  Future<HttpResponseData> sendMultipart({
    required Uri uri,
    required HttpMethod method,
    required Map<String, String> headers,
    required List<int> fileBytes,
    required String filename,
    required String fileField,
    Map<String, String>? fields,
    Duration? timeout,
  }) async {
    try {
      final request = http.MultipartRequest(method.value, uri);
      request.headers.addAll(headers);

      if (fields != null && fields.isNotEmpty) {
        request.fields.addAll(fields);
      }

      MediaType? contentType;
      final lowerName = filename.toLowerCase();
      if (lowerName.endsWith('.csv')) {
        contentType = MediaType('text', 'csv');
      } else if (lowerName.endsWith('.png')) {
        contentType = MediaType('image', 'png');
      } else if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
        contentType = MediaType('image', 'jpeg');
      } else if (lowerName.endsWith('.webp')) {
        contentType = MediaType('image', 'webp');
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: filename,
          contentType: contentType,
        ),
      );

      final streamedResponseFuture = _client.send(request);
      final streamedResponse = timeout != null
          ? await streamedResponseFuture.timeout(
              timeout,
              onTimeout: () => throw const NetworkException(
                message:
                    'Connection timed out while waiting for server response',
              ),
            )
          : await streamedResponseFuture;

      final responseFuture = http.Response.fromStream(streamedResponse);
      final response = timeout != null
          ? await responseFuture.timeout(
              timeout,
              onTimeout: () => throw const NetworkException(
                message: 'Connection timed out while reading response stream',
              ),
            )
          : await responseFuture;

      return HttpResponseData(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(message: 'Network connection error: ${e.message}');
    } on TimeoutException catch (e) {
      throw NetworkException(
        message:
            'Request timed out: ${e.message ?? 'Server took too long to respond'}',
      );
    } on FormatException catch (e) {
      throw NetworkException(message: 'Invalid response format: ${e.message}');
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(message: 'Unexpected network error: $e');
    }
  }
}
