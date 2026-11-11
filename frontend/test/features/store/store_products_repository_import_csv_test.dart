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
  String? lastBody;
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
    lastUri = uri;
    lastMethod = method;
    lastHeaders = headers;
    lastBody = body;
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

  group('StoreProductsRepositoryImpl.uploadProductImage', () {
    late MockMultipartHttpTransport mockTransport;
    late ApiClient apiClient;
    late StoreProductsRepositoryImpl repository;

    setUp(() {
      mockTransport = MockMultipartHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: mockTransport,
      );
      repository = StoreProductsRepositoryImpl(apiClient: apiClient);
    });

    test('sends multipart POST to /stores/:storeId/items/upload-image and returns imageUrl', () async {
      mockTransport.statusCode = 201;
      mockTransport.responseBody = jsonEncode({
        'imageUrl': 'https://supabase.co/storage/v1/object/public/item-images/store-123/img-1.jpg',
      });

      final bytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01];
      final result = await repository.uploadProductImage(
        storeId: 'store-123',
        fileBytes: bytes,
        fileName: 'product.jpg',
      );

      expect(result.isSuccess, isTrue);
      expect(
        result.dataOrNull,
        'https://supabase.co/storage/v1/object/public/item-images/store-123/img-1.jpg',
      );
      expect(mockTransport.lastUri?.path, '/stores/store-123/items/upload-image');
      expect(mockTransport.lastMethod, HttpMethod.post);
      expect(mockTransport.lastFileField, 'file');
      expect(mockTransport.lastFilename, 'product.jpg');
      expect(mockTransport.lastFileBytes, equals(bytes));
    });

    test('returns failure when server response lacks imageUrl', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({'status': 'ok'});

      final result = await repository.uploadProductImage(
        storeId: 'store-123',
        fileBytes: [1, 2, 3],
        fileName: 'product.png',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('missing imageUrl'));
    });

    test('returns failure on server error 500', () async {
      mockTransport.statusCode = 500;
      mockTransport.responseBody = jsonEncode({'message': 'Internal Server Error'});

      final result = await repository.uploadProductImage(
        storeId: 'store-123',
        fileBytes: [1, 2, 3],
        fileName: 'product.png',
      );

      expect(result.isFailure, isTrue);
    });
  });

  group('StoreProductsRepositoryImpl.createProduct & updateProduct with offerPrice', () {
    late MockMultipartHttpTransport mockTransport;
    late ApiClient apiClient;
    late StoreProductsRepositoryImpl repository;

    setUp(() {
      mockTransport = MockMultipartHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: mockTransport,
      );
      repository = StoreProductsRepositoryImpl(apiClient: apiClient);
    });

    test('createProduct includes offerPrice in POST body when provided', () async {
      mockTransport.statusCode = 201;
      mockTransport.responseBody = jsonEncode({
        'id': 'p-new-1',
        'storeId': 'store-123',
        'name': 'Premium Dates',
        'price': 40.0,
        'offerPrice': 32.0,
        'isAvailable': true,
      });

      final result = await repository.createProduct(
        storeId: 'store-123',
        name: 'Premium Dates',
        price: 40.0,
        offerPrice: 32.0,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.offerPrice, equals(32.0));
      expect(result.dataOrNull?.effectivePrice, equals(32.0));
      expect(mockTransport.lastUri?.path, '/stores/store-123/items');
      expect(mockTransport.lastMethod, HttpMethod.post);

      final decoded = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
      expect(decoded['name'], 'Premium Dates');
      expect(decoded['price'], 40.0);
      expect(decoded['offerPrice'], 32.0);
    });

    test('updateProduct sends offerPrice in PATCH body when provided', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode({
        'id': 'p-1',
        'storeId': 'store-123',
        'name': 'Premium Dates',
        'price': 40.0,
        'offerPrice': 30.0,
        'isAvailable': true,
      });

      final result = await repository.updateProduct(
        storeId: 'store-123',
        productId: 'p-1',
        offerPrice: 30.0,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.offerPrice, equals(30.0));
      expect(mockTransport.lastUri?.path, '/stores/store-123/items/p-1');
      expect(mockTransport.lastMethod, HttpMethod.patch);

      final decoded = jsonDecode(mockTransport.lastBody!) as Map<String, dynamic>;
      expect(decoded['offerPrice'], 30.0);
    });
  });
}
