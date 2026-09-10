/// Supported execution environments for eSOuQ frontend.
enum Environment {
  dev,
  staging,
  prod;

  static Environment fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'prod':
      case 'production':
        return Environment.prod;
      case 'staging':
      case 'stage':
        return Environment.staging;
      case 'dev':
      case 'development':
      default:
        return Environment.dev;
    }
  }

  String get name {
    switch (this) {
      case Environment.prod:
        return 'production';
      case Environment.staging:
        return 'staging';
      case Environment.dev:
        return 'development';
    }
  }
}
