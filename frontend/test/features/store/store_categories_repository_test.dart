import 'dart:convert';

import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/features/store/data/repositories/store_categories_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class MockHttpTransport implements HttpTransport {
  int statusCode = 200;
  String responseBody = '[]';
  Uri? lastUri;
  HttpMethod? lastMethod;
  String? lastBody;

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
    lastBody = body;

    return HttpResponseData(
      statusCode: statusCode,
      body: responseBody,
      headers: {},
    );
  }
}

void main() {
  group('StoreCategoriesRepositoryImpl', () {
    late MockHttpTransport mockTransport;
    late DefaultApiClient apiClient;
    late StoreCategoriesRepositoryImpl categoriesRepository;

    setUp(() {
      mockTransport = MockHttpTransport();
      apiClient = DefaultApiClient(
        baseUrl: 'https://api.esouq.com',
        transport: mockTransport,
      );
      categoriesRepository = StoreCategoriesRepositoryImpl(
        apiClient: apiClient,
      );
    });

    test('getCategories calls GET /stores/:storeId/categories', () async {
      mockTransport.statusCode = 200;
      mockTransport.responseBody = jsonEncode([
        {
          'id': 'cat-1',
          'storeId': 'store-1',
          'name': 'Beverages',
          'sortOrder': 1,
        },
      ]);

      final result = await categoriesRepository.getCategories('store-1');

      expect(result.isSuccess, isTrue);
      final categories = result.dataOrNull!;
      expect(categories.length, equals(1));
      expect(categories.first.name, equals('Beverages'));
      expect(mockTransport.lastUri?.path, equals('/stores/store-1/categories'));
      expect(mockTransport.lastMethod, equals(HttpMethod.get));
    });

    test(
      'createCategory calls POST /stores/:storeId/categories with name and sortOrder',
      () async {
        mockTransport.statusCode = 201;
        mockTransport.responseBody = jsonEncode({
          'id': 'cat-2',
          'storeId': 'store-1',
          'name': 'Snacks',
          'sortOrder': 3,
        });

        final result = await categoriesRepository.createCategory(
          storeId: 'store-1',
          name: 'Snacks',
          sortOrder: 3,
        );

        expect(result.isSuccess, isTrue);
        final category = result.dataOrNull!;
        expect(category.name, equals('Snacks'));
        expect(
          mockTransport.lastUri?.path,
          equals('/stores/store-1/categories'),
        );
        expect(mockTransport.lastMethod, equals(HttpMethod.post));
        expect(mockTransport.lastBody, contains('"name":"Snacks"'));
        expect(mockTransport.lastBody, contains('"sortOrder":3'));
      },
    );
  });
}
