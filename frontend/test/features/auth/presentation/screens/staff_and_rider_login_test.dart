import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/routing/app_routes.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/auth/domain/models/auth_response_model.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/auth/presentation/screens/rider_login_screen.dart';
import 'package:esouq/features/auth/presentation/screens/staff_login_screen.dart';
import 'package:esouq/features/auth/presentation/widgets/auth_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_auth_repository.dart';

void main() {
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  Widget buildStaffWidget() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      routes: {
        AppRoutes.login: (_) =>
            const Scaffold(body: Text('Customer Login Shell')),
        AppRoutes.storeHome: (_) =>
            const Scaffold(body: Text('Store Home Shell')),
      },
      home: AuthScope(
        repository: mockRepo,
        child: StaffLoginScreen(authRepository: mockRepo),
      ),
    );
  }

  Widget buildRiderWidget() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      routes: {
        AppRoutes.login: (_) =>
            const Scaffold(body: Text('Customer Login Shell')),
        AppRoutes.riderHome: (_) =>
            const Scaffold(body: Text('Rider Home Shell')),
      },
      home: AuthScope(
        repository: mockRepo,
        child: RiderLoginScreen(authRepository: mockRepo),
      ),
    );
  }

  group('StaffLoginScreen', () {
    testWidgets('renders staff portal branding and form fields', (
      tester,
    ) async {
      await tester.pumpWidget(buildStaffWidget());

      expect(find.text('Store Operations'), findsOneWidget);
      expect(
        find.text(
          'Staff & Store Manager sign-in for orders, stock & inventory',
        ),
        findsOneWidget,
      );
      expect(find.text('Staff Phone Number'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Staff Login'),
        findsOneWidget,
      );
      expect(find.text('Return to Customer App'), findsOneWidget);
    });

    testWidgets('authenticates store staff and navigates to storeHome', (
      tester,
    ) async {
      mockRepo.loginResult = Result.success(
        AuthResponseModel(
          user: const UserModel(
            id: 'staff_1',
            phoneNumber: '+96892222222',
            fullName: 'Store Associate',
            role: UserRole.storeStaff,
            storeId: 'store_101',
          ),
          token: 'staff_jwt_token',
        ),
      );

      await tester.pumpWidget(buildStaffWidget());

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '+96892222222');
      await tester.enterText(textFields.at(1), 'StaffPass123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Staff Login'));
      await tester.pumpAndSettle();

      expect(mockRepo.loginCallCount, equals(1));
      expect(find.text('Store Home Shell'), findsOneWidget);
    });

    testWidgets('authenticates store manager and navigates to storeHome', (
      tester,
    ) async {
      mockRepo.loginResult = Result.success(
        AuthResponseModel(
          user: const UserModel(
            id: 'mgr_1',
            phoneNumber: '+96893333333',
            fullName: 'Store Manager',
            role: UserRole.storeManager,
            storeId: 'store_101',
          ),
          token: 'mgr_jwt_token',
        ),
      );

      await tester.pumpWidget(buildStaffWidget());

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '+96893333333');
      await tester.enterText(textFields.at(1), 'MgrPass123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Staff Login'));
      await tester.pumpAndSettle();

      expect(mockRepo.loginCallCount, equals(1));
      expect(find.text('Store Home Shell'), findsOneWidget);
    });
  });

  group('RiderLoginScreen', () {
    testWidgets('renders rider portal branding and form fields', (
      tester,
    ) async {
      await tester.pumpWidget(buildRiderWidget());

      expect(find.text('Rider Partner Portal'), findsOneWidget);
      expect(
        find.text('Sign in to accept delivery batches and navigate routes'),
        findsOneWidget,
      );
      expect(find.text('Rider Phone Number'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Rider Login'),
        findsOneWidget,
      );
      expect(find.text('Return to Customer App'), findsOneWidget);
    });

    testWidgets('authenticates rider and navigates to riderHome', (
      tester,
    ) async {
      mockRepo.loginResult = Result.success(
        AuthResponseModel(
          user: const UserModel(
            id: 'rider_1',
            phoneNumber: '+96894444444',
            fullName: 'Rider Tariq',
            role: UserRole.deliveryRider,
          ),
          token: 'rider_jwt_token',
        ),
      );

      await tester.pumpWidget(buildRiderWidget());

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '+96894444444');
      await tester.enterText(textFields.at(1), 'RiderPass123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Rider Login'));
      await tester.pumpAndSettle();

      expect(mockRepo.loginCallCount, equals(1));
      expect(find.text('Rider Home Shell'), findsOneWidget);
    });

    testWidgets('displays error banner when rider login fails', (tester) async {
      mockRepo.loginResult = Result.failure(
        const UnauthorizedFailure(message: 'Invalid phone number or password.'),
      );

      await tester.pumpWidget(buildRiderWidget());

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '+96894444444');
      await tester.enterText(textFields.at(1), 'WrongPass');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Rider Login'));
      await tester.pumpAndSettle();

      expect(mockRepo.loginCallCount, equals(1));
      expect(find.text('Invalid phone number or password.'), findsOneWidget);
    });
  });
}
