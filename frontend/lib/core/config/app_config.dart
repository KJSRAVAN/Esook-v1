import 'environment.dart';

/// Centralized application configuration.
///
/// Values can be injected at build/runtime via `--dart-define`:
///   `--dart-define=API_BASE_URL=https://api.esouq.com/api/v1`
///   `--dart-define=APP_ENV=prod`
class AppConfig {
  final String apiBaseUrl;
  final Environment environment;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  const AppConfig({
    required this.apiBaseUrl,
    required this.environment,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
  });

  /// Factory creating configuration from environment definitions.
  factory AppConfig.fromEnvironment() {
    const defaultBaseUrl = 'http://localhost:3000/api';
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: defaultBaseUrl);
    const envString = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

    return AppConfig(
      apiBaseUrl: baseUrl,
      environment: Environment.fromString(envString),
    );
  }

  bool get isProduction => environment == Environment.prod;
  bool get isStaging => environment == Environment.staging;
  bool get isDevelopment => environment == Environment.dev;
}
