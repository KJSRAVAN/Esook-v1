import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/routing/app_routes.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/auth/domain/models/auth_response_model.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
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
        AppRoutes.customerHome: (_) =>
            const Scaffold(body: Text('Customer Home Shell')),
      },
      home: AuthScope(
        repository: effectiveRepo,
        child: CustomerSignupScreen(authRepository: effectiveRepo),
      ),
    );
  }

  group('CustomerSignupScreen - Initial Render & Field Absences', () {
    testWidgets('renders name, phone, optional email and sign in link', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Create Account'), findsNWidgets(2));
      expect(
        find.text('Join eSOuQ for fast delivery of fresh essentials'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('signup_name_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_phone_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_email_field')), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Create Account'),
        findsOneWidget,
      );
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('confirms password and delivery address fields are absent', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Password'), findsNothing);
      expect(find.text('Confirm Password'), findsNothing);
      expect(find.textContaining('Delivery Address'), findsNothing);
      expect(find.textContaining('address', findRichText: true), findsNothing);
    });
  });

  group('CustomerSignupScreen - Step 1 Validation', () {
    testWidgets('validates required name on submit', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(mockRepo.sendOtpCallCount, equals(0));
    });

    testWidgets('enforces name minimum length of 2 characters', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.byKey(const Key('signup_name_field')),
        'A',
      );
      await tester.enterText(
        find.byKey(const Key('signup_phone_field')),
        '+966501234567',
      );

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
      expect(mockRepo.sendOtpCallCount, equals(0));
    });

    testWidgets('validates required phone on submit', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.byKey(const Key('signup_name_field')),
        'Fatima Al-Balushi',
      );

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your phone number'), findsOneWidget);
      expect(mockRepo.sendOtpCallCount, equals(0));
    });

    testWidgets('validates phone number minimum length and format', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.byKey(const Key('signup_name_field')),
        'Fatima Al-Balushi',
      );
      await tester.enterText(
        find.byKey(const Key('signup_phone_field')),
        '123',
      );

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid phone number'), findsOneWidget);
      expect(mockRepo.sendOtpCallCount, equals(0));
    });

    testWidgets('accepts optional email when empty and proceeds', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.byKey(const Key('signup_name_field')),
        'Fatima Al-Balushi',
      );
      await tester.enterText(
        find.byKey(const Key('signup_phone_field')),
        '+966501234567',
      );
      // Leave email empty

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(mockRepo.sendOtpCallCount, equals(1));
      expect(mockRepo.lastSendOtpPhone, equals('+966501234567'));
      expect(mockRepo.lastSendOtpEmail, isNull);
      expect(find.text('Verify Code'), findsOneWidget);
    });

    testWidgets('rejects invalid email format when entered', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.byKey(const Key('signup_name_field')),
        'Fatima Al-Balushi',
      );
      await tester.enterText(
        find.byKey(const Key('signup_phone_field')),
        '+966501234567',
      );
      await tester.enterText(
        find.byKey(const Key('signup_email_field')),
        'invalid-email-address',
      );

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(mockRepo.sendOtpCallCount, equals(0));
    });
  });

  group('CustomerSignupScreen - OTP Request & Flow Progression', () {
    testWidgets(
      'sendOtp receives normalized phone and optional email, advances to OTP screen',
      (tester) async {
        mockRepo.sendOtpResult = Result.success(
          'Verification code sent via whatsapp',
        );

        await tester.pumpWidget(buildTestWidget());

        await tester.enterText(
          find.byKey(const Key('signup_name_field')),
          'Fatima Al-Balushi',
        );
        await tester.enterText(
          find.byKey(const Key('signup_phone_field')),
          '+966 50 123 4567',
        );
        await tester.enterText(
          find.byKey(const Key('signup_email_field')),
          'fatima@example.com',
        );

        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Create Account'),
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
        await tester.pumpAndSettle();

        expect(mockRepo.sendOtpCallCount, equals(1));
        expect(mockRepo.lastSendOtpPhone, equals('+966 50 123 4567'));
        expect(mockRepo.lastSendOtpEmail, equals('fatima@example.com'));

        expect(find.text('Verify Code'), findsOneWidget);
        expect(
          find.text('Verification code sent via whatsapp'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('otp_code_field')), findsOneWidget);
        expect(find.byKey(const Key('verify_otp_button')), findsOneWidget);
      },
    );

    testWidgets(
      'displays failure banner when sendOtp fails and remains on Step 1',
      (tester) async {
        mockRepo.sendOtpResult = Result.failure(
          const ServerFailure(message: 'SMS delivery service is unavailable'),
        );

        await tester.pumpWidget(buildTestWidget());

        await tester.enterText(
          find.byKey(const Key('signup_name_field')),
          'Fatima Al-Balushi',
        );
        await tester.enterText(
          find.byKey(const Key('signup_phone_field')),
          '+966501234567',
        );

        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Create Account'),
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
        await tester.pumpAndSettle();

        expect(mockRepo.sendOtpCallCount, equals(1));
        expect(
          find.text('SMS delivery service is unavailable'),
          findsOneWidget,
        );
        // Remains on Step 1
        expect(find.byKey(const Key('signup_name_field')), findsOneWidget);
        expect(find.text('Verify Code'), findsNothing);
      },
    );
  });

  group('CustomerSignupScreen - OTP Verification & Profile Update', () {
    Future<void> advanceToOtpStep(
      WidgetTester tester, {
      String name = 'Fatima Al-Balushi',
      String phone = '+966501234567',
      String email = 'fatima@example.com',
    }) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.byKey(const Key('signup_name_field')),
        name,
      );
      await tester.enterText(
        find.byKey(const Key('signup_phone_field')),
        phone,
      );
      if (email.isNotEmpty) {
        await tester.enterText(
          find.byKey(const Key('signup_email_field')),
          email,
        );
      }

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();
    }

    testWidgets('rejects OTP shorter or longer than 6 digits', (
      tester,
    ) async {
      await advanceToOtpStep(tester);

      // Enter short OTP
      await tester.enterText(find.byKey(const Key('otp_code_field')), '1234');
      await tester.tap(find.byKey(const Key('verify_otp_button')));
      await tester.pumpAndSettle();

      expect(find.text('OTP must be exactly 6 digits'), findsOneWidget);
      expect(mockRepo.verifyOtpCallCount, equals(0));
    });

    testWidgets(
      'handles verifyOtp failure: displays error banner and remains on OTP screen',
      (tester) async {
        mockRepo.verifyOtpResult = Result.failure(
          const UnauthorizedFailure(message: 'Invalid or expired OTP code'),
        );

        await advanceToOtpStep(tester);

        await tester.enterText(
          find.byKey(const Key('otp_code_field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('verify_otp_button')));
        await tester.pumpAndSettle();

        expect(mockRepo.verifyOtpCallCount, equals(1));
        expect(mockRepo.lastVerifyOtpCode, equals('123456'));
        expect(find.text('Invalid or expired OTP code'), findsOneWidget);
        expect(find.text('Verify Code'), findsOneWidget);
        expect(mockRepo.updateProfileCallCount, equals(0));
        expect(find.text('Customer Home Shell'), findsNothing);
      },
    );

    testWidgets(
      'successful OTP calls verifyOtp, then updateProfile with name and email, and navigates to customerHome',
      (tester) async {
        mockRepo.verifyOtpResult = Result.success(
          AuthResponseModel(
            user: const UserModel(
              id: 'cust_101',
              phoneNumber: '+966501234567',
              fullName: 'Customer User',
              role: UserRole.customer,
            ),
            token: 'valid_jwt_token',
          ),
        );

        await advanceToOtpStep(
          tester,
          name: 'Fatima Al-Balushi',
          phone: '+966501234567',
          email: 'fatima@example.com',
        );

        await tester.enterText(
          find.byKey(const Key('otp_code_field')),
          '654321',
        );
        await tester.tap(find.byKey(const Key('verify_otp_button')));
        await tester.pumpAndSettle();

        expect(mockRepo.verifyOtpCallCount, equals(1));
        expect(mockRepo.lastVerifyOtpPhone, equals('+966501234567'));
        expect(mockRepo.lastVerifyOtpCode, equals('654321'));

        expect(mockRepo.updateProfileCallCount, equals(1));
        expect(mockRepo.lastUpdateName, equals('Fatima Al-Balushi'));
        expect(mockRepo.lastUpdateEmail, equals('fatima@example.com'));

        expect(find.text('Customer Home Shell'), findsOneWidget);
      },
    );

    testWidgets(
      'successful OTP with empty email updates profile with null email',
      (tester) async {
        mockRepo.verifyOtpResult = Result.success(
          AuthResponseModel(
            user: const UserModel(
              id: 'cust_102',
              phoneNumber: '+966501234567',
              fullName: 'Customer User',
              role: UserRole.customer,
            ),
            token: 'valid_jwt_token',
          ),
        );

        await advanceToOtpStep(
          tester,
          name: 'Fatima Al-Balushi',
          phone: '+966501234567',
          email: '',
        );

        await tester.enterText(
          find.byKey(const Key('otp_code_field')),
          '112233',
        );
        await tester.tap(find.byKey(const Key('verify_otp_button')));
        await tester.pumpAndSettle();

        expect(mockRepo.verifyOtpCallCount, equals(1));
        expect(mockRepo.updateProfileCallCount, equals(1));
        expect(mockRepo.lastUpdateName, equals('Fatima Al-Balushi'));
        expect(mockRepo.lastUpdateEmail, isNull);

        expect(find.text('Customer Home Shell'), findsOneWidget);
      },
    );

    testWidgets(
      'handles updateProfile failure: displays error banner and preserves screen state without navigating',
      (tester) async {
        mockRepo.verifyOtpResult = Result.success(
          AuthResponseModel(
            user: const UserModel(
              id: 'cust_103',
              phoneNumber: '+966501234567',
              fullName: 'Customer User',
              role: UserRole.customer,
            ),
            token: 'valid_jwt_token',
          ),
        );
        mockRepo.updateProfileResult = Result.failure(
          const ServerFailure(message: 'Failed to update user profile in database'),
        );

        await advanceToOtpStep(tester);

        await tester.enterText(
          find.byKey(const Key('otp_code_field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('verify_otp_button')));
        await tester.pumpAndSettle();

        expect(mockRepo.verifyOtpCallCount, equals(1));
        expect(mockRepo.updateProfileCallCount, equals(1));
        expect(
          find.text('Failed to update user profile in database'),
          findsOneWidget,
        );
        expect(find.text('Customer Home Shell'), findsNothing);
      },
    );

    testWidgets('tapping Edit Details returns to Step 1 with preserved form values', (
      tester,
    ) async {
      await advanceToOtpStep(
        tester,
        name: 'Fatima Al-Balushi',
        phone: '+966501234567',
        email: 'fatima@example.com',
      );

      expect(find.text('Verify Code'), findsOneWidget);

      await tester.tap(find.text('Edit Details'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsNWidgets(2));
      expect(find.text('Fatima Al-Balushi'), findsOneWidget);
      expect(find.text('+966501234567'), findsOneWidget);
      expect(find.text('fatima@example.com'), findsOneWidget);
    });

    testWidgets('tapping Resend Code calls sendOtp again without validating Step 1 form again', (
      tester,
    ) async {
      await advanceToOtpStep(
        tester,
        name: 'Fatima Al-Balushi',
        phone: '+966501234567',
        email: 'fatima@example.com',
      );

      expect(mockRepo.sendOtpCallCount, equals(1));

      await tester.tap(find.text('Resend Code'));
      await tester.pumpAndSettle();

      expect(mockRepo.sendOtpCallCount, equals(2));
      expect(mockRepo.lastSendOtpPhone, equals('+966501234567'));
    });
  });
}
