import 'package:esouq/core/config/app_config.dart';
import 'package:esouq/core/config/environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('defaults to development environment when created from default environment', () {
      final config = AppConfig.fromEnvironment();

      expect(config.environment, equals(Environment.dev));
      expect(config.isDevelopment, isTrue);
      expect(config.isProduction, isFalse);
      expect(config.isStaging, isFalse);
      expect(config.apiBaseUrl, isNotEmpty);
    });

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
  });
}
