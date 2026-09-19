import 'package:esouq/core/config/app_config.dart';
import 'package:esouq/core/config/environment.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test(
      'defaults to development environment when created from default environment',
      () {
        final config = AppConfig.fromEnvironment();

        expect(config.environment, equals(Environment.dev));
        expect(config.isDevelopment, isTrue);
        expect(config.isProduction, isFalse);
        expect(config.isStaging, isFalse);
        expect(
          config.apiBaseUrl,
          equals('https://esook-production-production.up.railway.app'),
        );
      },
    );

    test('custom values are retained correctly', () {
      const config = AppConfig(
        apiBaseUrl: 'https://api.staging.esouq.com',
        environment: Environment.staging,
        connectTimeout: Duration(seconds: 30),
      );

      expect(config.apiBaseUrl, equals('https://api.staging.esouq.com'));
      expect(config.environment, equals(Environment.staging));
      expect(config.isStaging, isTrue);
      expect(config.connectTimeout, equals(const Duration(seconds: 30)));
    });

    test('Environment.fromString parses correctly', () {
      expect(Environment.fromString('prod'), equals(Environment.prod));
      expect(Environment.fromString('production'), equals(Environment.prod));
      expect(Environment.fromString('staging'), equals(Environment.staging));
      expect(Environment.fromString('dev'), equals(Environment.dev));
      expect(Environment.fromString('unknown'), equals(Environment.dev));
    });

    test(
      'DefaultApiClient using AppConfig defaults produces Railway URL without /api',
      () async {
        final config = AppConfig.fromEnvironment();
        expect(config.apiBaseUrl.endsWith('/api'), isFalse);
        expect(config.apiBaseUrl.endsWith('/'), isFalse);

        final mockTransport = _MockTransport();
        final client = DefaultApiClient(
          baseUrl: config.apiBaseUrl,
          transport: mockTransport,
        );

        await client.get<dynamic>('/cart');
        expect(
          mockTransport.lastUri.toString(),
          equals('https://esook-production-production.up.railway.app/cart'),
        );

        await client.get<dynamic>('/stores/store-123/items');
        expect(
          mockTransport.lastUri.toString(),
          equals(
            'https://esook-production-production.up.railway.app/stores/store-123/items',
          ),
        );
      },
    );
  });
}

class _MockTransport implements HttpTransport {
  Uri? lastUri;

  @override
  Future<HttpResponseData> send({
    required Uri uri,
    required HttpMethod method,
    required Map<String, String> headers,
    String? body,
    Duration? timeout,
  }) async {
    lastUri = uri;
    return const HttpResponseData(statusCode: 200, body: '{}', headers: {});
  }
}
