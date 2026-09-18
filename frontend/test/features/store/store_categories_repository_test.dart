import 'package:esouq/core/error/failures.dart';
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
      categoriesRepository = StoreCategoriesRepositoryImpl(apiClient: apiClient);
    });

    test('getCategories makes no network call and returns safe empty list', () async {
      final result = await categoriesRepository.getCategories('store-1');

      expect(result.isSuccess, isTrue);
      final categories = result.dataOrNull!;
      expect(categories, isEmpty);
      // Confirms no network call made to non-existent /stores/:storeId/categories
      expect(mockTransport.lastUri, isNull);
    });

    test('createCategory does not make network request and returns ValidationFailure', () async {
      final result = await categoriesRepository.createCategory(
        storeId: 'store-1',
        name: 'Beverages',
        sortOrder: 3,
      );

      // Does not fake success
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.failureOrNull?.message,
        contains('Category creation is not supported by the backend API'),
      );
      // Confirms no network call made
      expect(mockTransport.lastUri, isNull);
      expect(mockTransport.lastMethod, isNull);
    });
  });
}
