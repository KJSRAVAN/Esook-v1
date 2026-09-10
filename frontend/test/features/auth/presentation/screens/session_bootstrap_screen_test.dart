import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/routing/app_routes.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/auth/presentation/screens/session_bootstrap_screen.dart';
import 'package:esouq/features/auth/presentation/widgets/auth_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_auth_repository.dart';

void main() {
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  Widget buildBootstrapWidget() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      routes: {
        AppRoutes.login: (_) => const Scaffold(body: Text('Customer Login Shell')),
        AppRoutes.customerHome: (_) => const Scaffold(body: Text('Customer Home Shell')),
        AppRoutes.storeHome: (_) => const Scaffold(body: Text('Store Home Shell')),
        AppRoutes.riderHome: (_) => const Scaffold(body: Text('Rider Home Shell')),
        AppRoutes.adminHome: (_) => const Scaffold(body: Text('Admin Home Shell')),
      },
      home: AuthScope(
        repository: mockRepo,
        child: SessionBootstrapScreen(authRepository: mockRepo),
      ),
    );
  }

  group('SessionBootstrapScreen', () {
    testWidgets('routes to customer login when no session exists', (tester) async {
      mockRepo.checkSessionResult = Result.success(null);

      await tester.pumpWidget(buildBootstrapWidget());
      await tester.pumpAndSettle();

      expect(mockRepo.checkSessionCallCount, equals(1));
      expect(find.text('Customer Login Shell'), findsOneWidget);
    });

    testWidgets('routes to customerHome when valid customer session exists', (tester) async {
      mockRepo.checkSessionResult = Result.success(
        const UserModel(
          id: 'c1',
          phoneNumber: '+96891111111',
          fullName: 'Customer Salim',
          role: UserRole.customer,
        ),
      );

      await tester.pumpWidget(buildBootstrapWidget());
      await tester.pumpAndSettle();

      expect(mockRepo.checkSessionCallCount, equals(1));
      expect(find.text('Customer Home Shell'), findsOneWidget);
    });

    testWidgets('routes to storeHome when valid storeStaff session exists', (tester) async {
      mockRepo.checkSessionResult = Result.success(
        const UserModel(
          id: 's1',
          phoneNumber: '+96892222222',
          fullName: 'Staff Ahmed',
          role: UserRole.storeStaff,
        ),
      );

      await tester.pumpWidget(buildBootstrapWidget());
      await tester.pumpAndSettle();

      expect(mockRepo.checkSessionCallCount, equals(1));
      expect(find.text('Store Home Shell'), findsOneWidget);
    });

    testWidgets('routes to riderHome when valid deliveryRider session exists', (tester) async {
      mockRepo.checkSessionResult = Result.success(
        const UserModel(
          id: 'r1',
          phoneNumber: '+96893333333',
          fullName: 'Rider Tariq',
          role: UserRole.deliveryRider,
        ),
      );

      await tester.pumpWidget(buildBootstrapWidget());
      await tester.pumpAndSettle();

      expect(mockRepo.checkSessionCallCount, equals(1));
      expect(find.text('Rider Home Shell'), findsOneWidget);
    });

    testWidgets('routes to adminHome when valid superAdmin session exists', (tester) async {
      mockRepo.checkSessionResult = Result.success(
        const UserModel(
          id: 'a1',
          phoneNumber: '+96890000000',
          fullName: 'Admin User',
          role: UserRole.superAdmin,
        ),
      );

      await tester.pumpWidget(buildBootstrapWidget());
      await tester.pumpAndSettle();

      expect(mockRepo.checkSessionCallCount, equals(1));
      expect(find.text('Admin Home Shell'), findsOneWidget);
    });

    testWidgets('displays retry card on transient network failure without logging out', (tester) async {
      mockRepo.checkSessionResult = Result.failure(
        const NetworkFailure(message: 'Connection timed out'),
      );

      await tester.pumpWidget(buildBootstrapWidget());
      await tester.pumpAndSettle();

      expect(mockRepo.checkSessionCallCount, equals(1));
      expect(find.text('Connection Issue'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Go to Login'), findsOneWidget);
      expect(mockRepo.logoutCallCount, equals(0));

      // Test Retry button
      mockRepo.checkSessionResult = Result.success(
        const UserModel(
          id: 'c1',
          phoneNumber: '+96891111111',
          fullName: 'Customer Salim',
          role: UserRole.customer,
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Try Again'));
      await tester.pumpAndSettle();

      expect(mockRepo.checkSessionCallCount, equals(2));
      expect(find.text('Customer Home Shell'), findsOneWidget);
    });
  });
}
