import 'dart:convert';
import 'package:esouq/core/error/exceptions.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/store/data/repositories/store_products_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class MockMultipartHttpTransport implements HttpTransport, MultipartHttpTransport {
  int statusCode = 200;
  String responseBody = '{}';
  Uri? lastUri;
  HttpMethod? lastMethod;
  String? lastFileField;
  String? lastFilename;
  List<int>? lastFileBytes;
  Map<String, String>? lastHeaders;

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
    lastFileField = fileField;
    lastFilename = filename;
    lastFileBytes = fileBytes;
    lastHeaders = headers;

    if (statusCode >= 400) {
      if (statusCode == 404) {
        throw NotFoundException(
          message: 'Endpoint not found',
          statusCode: statusCode,
          details: responseBody,
        );
      }
      throw ServerException(
        message: 'Import failed with status $statusCode',
        statusCode: statusCode,
        details: responseBody,
      );
    }

    return HttpResponseData(
      statusCode: statusCode,
      body: responseBody,
      headers: {},
    );
  }
}

void main() {
  group('StoreProductsRepositoryImpl.importCsv', () {
    late MockMultipartHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late StoreProductsRepositoryImpl repository;

    setUp(() {
      mockTransport = MockMultipartHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: mockTransport,
      );
      repository = StoreProductsRepositoryImpl(apiClient: apiClient);
    });

    test('sends multipart POST to /stores/:storeId/items/import-csv with field named file', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'imported': 8,
        'updated': 3,
        'skipped': 1,
        'errors': [
          {'row': 4, 'message': 'Missing price', 'field': 'price'},
        ],
      });

      final bytes = utf8.encode('name,price\nApple,5.0\nBanana,3.0');
      final result = await repository.importCsv(
        storeId: 'store-123',
        fileBytes: bytes,
        fileName: 'products_batch.csv',
      );

      expect(result.isSuccess, isTrue);
      final data = result.dataOrNull!;
      expect(data.imported, 8);
      expect(data.updated, 3);
      expect(data.skipped, 1);
      expect(data.errors.length, 1);
      expect(data.errors.first.row, 4);
      expect(data.errors.first.message, 'Missing price');

      // Verify exact endpoint and multipart contract
      expect(mockTransport.lastUri?.path, '/stores/store-123/items/import-csv');
      expect(mockTransport.lastMethod, HttpMethod.post);
      expect(mockTransport.lastFileField, 'file');
      expect(mockTransport.lastFilename, 'products_batch.csv');
      expect(mockTransport.lastFileBytes, equals(bytes));
      // Content-Type should not be application/json on multipart headers
      expect(mockTransport.lastHeaders?['Content-Type'], isNot('application/json'));
    });

    test('returns failure when server returns 404 not found (e.g. endpoint not reachable)', () async {
      mockTransport.statusCode = 404;
      mockTransport.responseBody = jsonEncode({
        'message': 'Cannot POST /stores/store-123/items/import-csv',
      });

      final bytes = utf8.encode('name,price\nApple,5.0');
      final result = await repository.importCsv(
        storeId: 'store-123',
        fileBytes: bytes,
        fileName: 'products.csv',
      );

      expect(result.isSuccess, isFalse);
      expect(result.failureOrNull?.message, contains('Endpoint not found'));
    });

    test('returns failure on server error 500', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({'message': 'Internal Server Error'});

      final bytes = utf8.encode('name,price\nApple,5.0');
      final result = await repository.importCsv(
        storeId: 'store-123',
        fileBytes: bytes,
        fileName: 'products.csv',
      );

      expect(result.isSuccess, isFalse);
      expect(result.failureOrNull?.message, contains('Import failed with status 500'));
    });
  });
}
