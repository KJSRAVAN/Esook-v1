import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/routing/app_routes.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/auth/domain/models/auth_response_model.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/auth/presentation/screens/customer_login_screen.dart';
import 'package:esouq/features/auth/presentation/widgets/auth_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_auth_repository.dart';

void main() {
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  Widget buildTestWidget({MockAuthRepository? repo}) {
    final effectiveRepo = repo ?? mockRepo;
    return MaterialApp(
      theme: AppTheme.lightTheme,
      routes: {
        AppRoutes.login: (_) => CustomerLoginScreen(authRepository: effectiveRepo),
        AppRoutes.signup: (_) => const Scaffold(body: Text('Signup Screen Placeholder')),
        AppRoutes.customerHome: (_) => const Scaffold(body: Text('Customer Home Shell')),
        AppRoutes.staffLogin: (_) => const Scaffold(body: Text('Staff Login Shell')),
        AppRoutes.riderLogin: (_) => const Scaffold(body: Text('Rider Login Shell')),
        AppRoutes.adminMagicLink: (_) => const Scaffold(body: Text('Admin Magic Link Shell')),
        AppRoutes.devCustomerPreview: (_) => const Scaffold(body: Text('Dev Customer Preview Shell')),
      },
      home: AuthScope(
        repository: effectiveRepo,
        child: CustomerLoginScreen(authRepository: effectiveRepo),
      ),
    );
  }

  group('CustomerLoginScreen', () {
    testWidgets('renders all required form elements and branding', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign in to continue ordering fresh groceries'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Store Staff'), findsOneWidget);
      expect(find.text('Delivery Rider'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.byKey(const Key('dev_customer_preview_button')), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty form', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your phone number'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
      expect(mockRepo.loginCallCount, equals(0));
    });

    testWidgets('shows validation error for invalid phone number length', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.widgetWithText(TextFormField, '').first, '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid phone number'), findsOneWidget);
      expect(mockRepo.loginCallCount, equals(0));
    });

    testWidgets('toggles password visibility correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final visibilityButton = find.byTooltip('Show password');
      expect(visibilityButton, findsOneWidget);

      final passwordFieldFinder = find.byType(EditableText).last;
      EditableText passwordField = tester.widget<EditableText>(passwordFieldFinder);
      expect(passwordField.obscureText, isTrue);

      await tester.tap(visibilityButton);
      await tester.pumpAndSettle();

      passwordField = tester.widget<EditableText>(passwordFieldFinder);
      expect(passwordField.obscureText, isFalse);
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('submits credentials and navigates to customerHome on success', (tester) async {
      mockRepo.loginResult = Result.success(
        AuthResponseModel(
          user: const UserModel(
            id: 'u1',
            phoneNumber: '+96891234567',
            fullName: 'Salim',
            role: UserRole.customer,
          ),
          token: 'valid_jwt',
        ),
      );

      await tester.pumpWidget(buildTestWidget());

      // Enter phone and password
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '+96891234567');
      await tester.enterText(textFields.at(1), 'SecretPassword123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(mockRepo.loginCallCount, equals(1));
      expect(mockRepo.lastLoginPhone, equals('+96891234567'));
      expect(mockRepo.lastLoginPassword, equals('SecretPassword123'));
      expect(find.text('Customer Home Shell'), findsOneWidget);
    });

    testWidgets('displays error banner on 401 unauthorized and preserves inputs', (tester) async {
      mockRepo.loginResult = Result.failure(
        const UnauthorizedFailure(message: 'Invalid phone number or password.'),
      );

      await tester.pumpWidget(buildTestWidget());

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '+96891234567');
      await tester.enterText(textFields.at(1), 'WrongPassword');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(mockRepo.loginCallCount, equals(1));
      expect(find.text('Invalid phone number or password.'), findsOneWidget);
      // Verify inputs are preserved
      expect(find.text('+96891234567'), findsOneWidget);
      expect(find.text('WrongPassword'), findsOneWidget);
    });

    testWidgets('navigates to signup screen when tapping Sign Up', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Signup Screen Placeholder'), findsOneWidget);
    });

    testWidgets('navigates to devCustomerPreview when tapping Developer Preview button in debug mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final buttonFinder = find.byKey(const Key('dev_customer_preview_button'));
      await tester.ensureVisible(buttonFinder);
      await tester.pumpAndSettle();

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Dev Customer Preview Shell'), findsOneWidget);
    });
  });
}
