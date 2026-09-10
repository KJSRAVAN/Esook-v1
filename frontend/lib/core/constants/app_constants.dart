/// Application-wide general constants.
abstract final class AppConstants {
  static const String appName = 'eSOuQ';
  static const int defaultTimeoutSeconds = 15;
  static const int defaultPageSize = 20;

  /// Default currency code driven by compile-time environment variable (--dart-define=APP_CURRENCY=...)
  /// with 'SAR' as the standard regional store fallback.
  static const String defaultCurrency = String.fromEnvironment(
    'APP_CURRENCY',
    defaultValue: 'SAR',
  );
}
