import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/routing/app_routes.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/auth/presentation/screens/customer_signup_screen.dart';
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
        AppRoutes.login: (_) =>
            const Scaffold(body: Text('Login Screen Shell')),
        AppRoutes.signup: (_) =>
            CustomerSignupScreen(authRepository: effectiveRepo),
      },
      home: AuthScope(
        repository: effectiveRepo,
        child: CustomerSignupScreen(authRepository: effectiveRepo),
      ),
    );
  }

  group('CustomerSignupScreen - Email/Password Contract', () {
    testWidgets(
      'renders all 4 required backend fields and no delivery address or OTP',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestWidget());

        expect(find.text('Create Account'), findsNWidgets(2));
        expect(
          find.text('Join eSOuQ for fast delivery of fresh essentials'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('signup_name_field')), findsOneWidget);
        expect(find.byKey(const Key('signup_phone_field')), findsOneWidget);
        expect(find.byKey(const Key('signup_email_field')), findsOneWidget);
        expect(find.byKey(const Key('signup_password_field')), findsOneWidget);
        expect(find.byKey(const Key('signup_submit_button')), findsOneWidget);
        expect(find.byKey(const Key('signup_to_login_button')), findsOneWidget);

        // Verification of field absences: NO address, NO optional label, NO OTP wording
        expect(find.text('Delivery Address'), findsNothing);
        expect(find.text('Address'), findsNothing);
        expect(find.textContaining(RegExp(r'optional', caseSensitive: false)), findsNothing);
        expect(find.textContaining(RegExp(r'backup OTP', caseSensitive: false)), findsNothing);
        expect(find.textContaining(RegExp(r'OTP', caseSensitive: false)), findsNothing);
        expect(find.byKey(const Key('otp_code_field')), findsNothing);
      },
    );

    testWidgets('shows validation errors when submitting empty form', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byKey(const Key('signup_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your phone number'), findsOneWidget);
      expect(find.text('Please enter your email address'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
      expect(mockRepo.signupCallCount, equals(0));
    });

    testWidgets('validates name length, email format, and password length', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.byKey(const Key('signup_name_field')),
        'A',
      );
      await tester.enterText(
        find.byKey(const Key('signup_phone_field')),
        '123',
      );
      await tester.enterText(
        find.byKey(const Key('signup_email_field')),
        'not-an-email',
      );
      await tester.enterText(
        find.byKey(const Key('signup_password_field')),
        'short',
      );

      await tester.tap(find.byKey(const Key('signup_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
      expect(find.text('Please enter a valid phone number'), findsOneWidget);
      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
      expect(mockRepo.signupCallCount, equals(0));
    });

    testWidgets(
      'submitting valid details calls signupCustomer and shows confirmation',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestWidget());

        await tester.enterText(
          find.byKey(const Key('signup_name_field')),
          'Ahmed Ali',
        );
        await tester.enterText(
          find.byKey(const Key('signup_phone_field')),
          '+966501234567',
        );
        await tester.enterText(
          find.byKey(const Key('signup_email_field')),
          'ahmed@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('signup_password_field')),
          'Customer@1234',
        );

        await tester.tap(find.byKey(const Key('signup_submit_button')));
        await tester.pumpAndSettle();

        expect(mockRepo.signupCallCount, equals(1));
        expect(mockRepo.lastSignupName, equals('Ahmed Ali'));
        expect(mockRepo.lastSignupPhone, equals('+966501234567'));
        expect(mockRepo.lastSignupEmail, equals('ahmed@example.com'));
        expect(mockRepo.lastSignupPassword, equals('Customer@1234'));

        expect(find.text('Account Created!'), findsOneWidget);
        expect(
          find.text('Account created successfully. You can now log in.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('signup_proceed_to_login_button')),
          findsOneWidget,
        );

        // Tap proceed to login
        await tester.tap(
          find.byKey(const Key('signup_proceed_to_login_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Login Screen Shell'), findsOneWidget);
      },
    );

    testWidgets('shows error banner on duplicate email/phone conflict', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      mockRepo.signupCustomerResult = Result.failure(
        const ConflictFailure(
          message: 'Email address is already registered',
        ),
      );

      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.byKey(const Key('signup_name_field')),
        'Ahmed Ali',
      );
      await tester.enterText(
        find.byKey(const Key('signup_email_field')),
        'ahmed@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('signup_phone_field')),
        '+966501234567',
      );
      await tester.enterText(
        find.byKey(const Key('signup_password_field')),
        'Customer@1234',
      );

      await tester.tap(find.byKey(const Key('signup_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Email address is already registered'), findsOneWidget);
      expect(find.text('Account Created!'), findsNothing);
    });

    testWidgets('navigates to login screen on Sign In link tap', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byKey(const Key('signup_to_login_button')));
      await tester.pumpAndSettle();

      expect(find.text('Login Screen Shell'), findsOneWidget);
    });
  });
}
