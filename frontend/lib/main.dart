import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/storage_keys.dart';
import 'core/network/api_client.dart';
import 'core/routing/app_router.dart';
import 'core/routing/app_routes.dart';
import 'core/storage/flutter_secure_storage_impl.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/widgets/auth_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize configuration from build environment
  final config = AppConfig.fromEnvironment();

  // Initialize core infrastructure
  final secureStorage = const FlutterSecureStorageImpl();
  final apiClient = DefaultApiClient(
    baseUrl: config.apiBaseUrl,
    tokenProvider: () => secureStorage.read(key: StorageKeys.authToken),
    timeout: config.connectTimeout,
  );

  final authRepository = AuthRepositoryImpl(
    apiClient: apiClient,
    secureStorage: secureStorage,
  );

  runApp(
    EsouqApp(
      config: config,
      secureStorage: secureStorage,
      apiClient: apiClient,
      authRepository: authRepository,
    ),
  );
}

/// Root widget for eSOuQ application.
class EsouqApp extends StatelessWidget {
  final AppConfig config;
  final SecureStorage secureStorage;
  final ApiClient apiClient;
  final AuthRepository? authRepository;

  const EsouqApp({
    super.key,
    required this.config,
    required this.secureStorage,
    required this.apiClient,
    this.authRepository,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAuthRepository =
        authRepository ??
        AuthRepositoryImpl(apiClient: apiClient, secureStorage: secureStorage);

    return AuthScope(
      repository: effectiveAuthRepository,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: !config.isProduction,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.initial,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
