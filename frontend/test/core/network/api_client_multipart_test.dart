import 'dart:convert';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:flutter_test/flutter_test.dart';

class MockMultipartTransport implements HttpTransport, MultipartHttpTransport {
  int statusCode = 200;
  String responseBody = '{"status":"ok"}';
  Uri? lastUri;
  HttpMethod? lastMethod;
  Map<String, String>? lastHeaders;
  List<int>? lastFileBytes;
  String? lastFilename;
  String? lastFileField;
  Map<String, String>? lastFields;

  @override
  Future<HttpResponseData> send({
    required Uri uri,
    required HttpMethod method,
    required Map<String, String> headers,
    String? body,
    Duration? timeout,
  }) async {
    return HttpResponseData(
      statusCode: statusCode,
      body: responseBody,
      headers: {},
    );
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
    lastUri = uri;
    lastMethod = method;
    lastHeaders = headers;
    lastFileBytes = fileBytes;
    lastFilename = filename;
    lastFileField = fileField;
    lastFields = fields;

    return HttpResponseData(
      statusCode: statusCode,
      body: responseBody,
      headers: {},
    );
  }
}

class StandardNonMultipartTransport implements HttpTransport {
  @override
  Future<HttpResponseData> send({
    required Uri uri,
    required HttpMethod method,
    required Map<String, String> headers,
    String? body,
    Duration? timeout,
  }) async {
    return const HttpResponseData(statusCode: 200, body: '{}', headers: {});
  }
}

void main() {
  group('DefaultApiClient.postMultipart', () {
    late MockMultipartTransport transport;
    late DefaultApiClient apiClient;

    setUp(() {
      transport = MockMultipartTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: transport,
        tokenProvider: () async => 'jwt_token_123',
      );
    });

    test('sends multipart POST with authorization header and without application/json Content-Type', () async {
      transport.statusCode = 200;
      transport.responseBody = jsonEncode({'success': true, 'count': 42});

      final bytes = utf8.encode('test,csv,data');
      final res = await apiClient.postMultipart<Map<String, dynamic>>(
        '/stores/store-1/items/import-csv',
        fileBytes: bytes,
        filename: 'data.csv',
        fileField: 'file',
        fields: {'category': 'Produce'},
        fromJson: (json) => json as Map<String, dynamic>,
      );

      expect(res.statusCode, 200);
      expect(res.data['success'], isTrue);
      expect(res.data['count'], 42);

      expect(transport.lastUri?.path, '/stores/store-1/items/import-csv');
      expect(transport.lastMethod, HttpMethod.post);
      expect(transport.lastFileField, 'file');
      expect(transport.lastFilename, 'data.csv');
      expect(transport.lastFileBytes, equals(bytes));
      expect(transport.lastFields?['category'], 'Produce');

      // Authorization header is set
      expect(transport.lastHeaders?['Authorization'], 'Bearer jwt_token_123');
      // Content-Type should not be application/json on multipart
      expect(transport.lastHeaders?['Content-Type'], isNot('application/json'));
    });

    test('throws UnsupportedError if transport does not implement MultipartHttpTransport', () async {
      final clientWithNonMultipart = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: StandardNonMultipartTransport(),
      );

      expect(
        () => clientWithNonMultipart.postMultipart(
          '/upload',
          fileBytes: [1, 2, 3],
          filename: 'file.csv',
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
