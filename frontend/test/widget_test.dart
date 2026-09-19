import 'package:esouq/core/config/app_config.dart';
import 'package:esouq/core/config/environment.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/storage/in_memory_secure_storage.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/auth/mocks/mock_auth_repository.dart';

void main() {
  testWidgets(
    'EsouqApp bootstrap renders session bootstrap and transitions to login when unauthenticated',
    (WidgetTester tester) async {
      const config = AppConfig(
        apiBaseUrl: 'https://test.esouq.com/api/v1',
        environment: Environment.dev,
      );
      final storage = InMemorySecureStorage();
      final apiClient = DefaultApiClient(baseUrl: config.apiBaseUrl);
      final mockAuthRepo = MockAuthRepository();
      mockAuthRepo.checkSessionResult = Result.success(null);

      await tester.pumpWidget(
        EsouqApp(
          config: config,
          secureStorage: storage,
          apiClient: apiClient,
          authRepository: mockAuthRepo,
        ),
      );

      expect(find.text('eSOuQ'), findsOneWidget);
      expect(find.text('Fresh Groceries Delivered'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(
        find.text('Sign in to continue ordering fresh groceries'),
        findsOneWidget,
      );
    },
  );
}
