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
        AppRoutes.login: (_) =>
            CustomerLoginScreen(authRepository: effectiveRepo),
        AppRoutes.profileSetup: (_) =>
            const Scaffold(body: Text('Profile Setup Shell')),
        AppRoutes.customerHome: (_) =>
            const Scaffold(body: Text('Customer Home Shell')),
        AppRoutes.staffLogin: (_) =>
            const Scaffold(body: Text('Staff Login Shell')),
        AppRoutes.riderLogin: (_) =>
            const Scaffold(body: Text('Rider Login Shell')),
        AppRoutes.adminMagicLink: (_) =>
            const Scaffold(body: Text('Admin Magic Link Shell')),
        AppRoutes.devCustomerPreview: (_) =>
            const Scaffold(body: Text('Dev Customer Preview Shell')),
      },
      home: AuthScope(
        repository: effectiveRepo,
        child: CustomerLoginScreen(authRepository: effectiveRepo),
      ),
    );
  }

  void setupViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('CustomerLoginScreen - Partner OTP Login Flow', () {
    testWidgets(
      'Step 1: renders full name, email, phone, and request OTP CTA without password or signup link',
      (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('Welcome to eSOuQ'), findsOneWidget);
        expect(
          find.text('Enter your details to sign in or get started'),
          findsOneWidget,
        );

        // Required Step 1 Fields
        expect(find.text('Full Name'), findsOneWidget);
        expect(find.byKey(const Key('customer_name_field')), findsOneWidget);

        expect(find.text('Email Address'), findsOneWidget);
        expect(find.byKey(const Key('customer_email_field')), findsOneWidget);

        expect(find.text('Phone Number'), findsOneWidget);
        expect(find.byKey(const Key('customer_phone_field')), findsOneWidget);

        // CTA
        expect(find.widgetWithText(ElevatedButton, 'Request OTP'), findsOneWidget);
        expect(
          find.byKey(const Key('customer_request_otp_button')),
          findsOneWidget,
        );

        // Assert absence of password field, email/phone toggle, and signup link
        expect(find.byKey(const Key('customer_password_field')), findsNothing);
        expect(find.text('Password'), findsNothing);
        expect(find.text("Don't have an account?"), findsNothing);
        expect(find.text('Sign Up'), findsNothing);
        expect(find.byKey(const Key('customer_to_signup_button')), findsNothing);

        // Portals
        expect(find.text('Store Staff'), findsOneWidget);
        expect(find.text('Delivery Rider'), findsOneWidget);
        expect(find.text('Admin'), findsOneWidget);
      },
    );

    testWidgets('Step 1: validates empty/required fields on Request OTP tap', (
      tester,
    ) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byKey(const Key('customer_request_otp_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your email address'), findsOneWidget);
      expect(find.text('Please enter your phone number'), findsOneWidget);
      expect(mockRepo.sendOtpCallCount, equals(0));
    });

    testWidgets('Step 1: validates short name, invalid email, and malformed phone', (
      tester,
    ) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.byKey(const Key('customer_name_field')),
        'A',
      );
      await tester.enterText(
        find.byKey(const Key('customer_email_field')),
        'invalid-email-address',
      );
      await tester.enterText(
        find.byKey(const Key('customer_phone_field')),
        '123',
      );

      await tester.tap(find.byKey(const Key('customer_request_otp_button')));
      await tester.pumpAndSettle();

      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(find.text('Please enter a valid phone number'), findsOneWidget);
      expect(mockRepo.sendOtpCallCount, equals(0));
    });

    testWidgets(
      'Step 1 -> Step 2: submitting valid details calls sendOtp and transitions to OTP step',
      (tester) async {
        setupViewport(tester);
        mockRepo.sendOtpResult = Result.success('OTP sent successfully');

        await tester.pumpWidget(buildTestWidget());

        await tester.enterText(
          find.byKey(const Key('customer_name_field')),
          'Ahmed Ali',
        );
        await tester.enterText(
          find.byKey(const Key('customer_email_field')),
          'ahmed@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('customer_phone_field')),
          '+966501234567',
        );

        await tester.tap(find.byKey(const Key('customer_request_otp_button')));
        await tester.pumpAndSettle();

        expect(mockRepo.sendOtpCallCount, equals(1));
        expect(mockRepo.lastSendOtpName, equals('Ahmed Ali'));
        expect(mockRepo.lastSendOtpEmail, equals('ahmed@example.com'));
        expect(mockRepo.lastSendOtpPhone, equals('+966501234567'));

        // Step 2 OTP UI should now be displayed
        expect(find.text('Verify Phone'), findsOneWidget);
        expect(find.byKey(const Key('customer_otp_field')), findsOneWidget);
        expect(
          find.byKey(const Key('customer_verify_otp_button')),
          findsOneWidget,
        );
        expect(find.text('OTP sent successfully'), findsOneWidget);
      },
    );

    testWidgets('Step 1: shows error banner when sendOtp fails', (tester) async {
      setupViewport(tester);
      mockRepo.sendOtpResult = Result.failure(
        const RateLimitFailure(
          message: 'Too many OTP requests. Please wait.',
        ),
      );

      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.byKey(const Key('customer_name_field')),
        'Ahmed Ali',
      );
      await tester.enterText(
        find.byKey(const Key('customer_email_field')),
        'ahmed@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('customer_phone_field')),
        '+966501234567',
      );

      await tester.tap(find.byKey(const Key('customer_request_otp_button')));
      await tester.pumpAndSettle();

      expect(find.text('Too many OTP requests. Please wait.'), findsOneWidget);
      expect(find.byKey(const Key('customer_otp_field')), findsNothing);
    });

    testWidgets('Step 2: validates 6-digit OTP code input', (tester) async {
      setupViewport(tester);
      mockRepo.sendOtpResult = Result.success('OTP sent');

      await tester.pumpWidget(buildTestWidget());

      // Transition to Step 2
      await tester.enterText(
        find.byKey(const Key('customer_name_field')),
        'Ahmed Ali',
      );
      await tester.enterText(
        find.byKey(const Key('customer_email_field')),
        'ahmed@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('customer_phone_field')),
        '+966501234567',
      );
      await tester.tap(find.byKey(const Key('customer_request_otp_button')));
      await tester.pumpAndSettle();

      // Submit empty OTP
      await tester.tap(find.byKey(const Key('customer_verify_otp_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter the 6-digit verification code'),
        findsOneWidget,
      );
      expect(mockRepo.verifyOtpCallCount, equals(0));

      // Enter incomplete OTP
      await tester.enterText(
        find.byKey(const Key('customer_otp_field')),
        '123',
      );
      await tester.tap(find.byKey(const Key('customer_verify_otp_button')));
      await tester.pumpAndSettle();

      expect(find.text('Code must be exactly 6 digits'), findsOneWidget);
      expect(mockRepo.verifyOtpCallCount, equals(0));
    });

    testWidgets(
      'Step 2: verifying OTP for new customer (isNew == true) routes to Profile Setup',
      (tester) async {
        setupViewport(tester);
        mockRepo.sendOtpResult = Result.success('OTP sent');
        mockRepo.verifyOtpResult = Result.success(
          const AuthResponseModel(
            user: UserModel(
              id: 'new_cust_1',
              phoneNumber: '+966501234567',
              fullName: 'Ahmed Ali',
              email: 'ahmed@example.com',
              role: UserRole.customer,
            ),
            token: 'mock_jwt_token',
            isNew: true,
          ),
        );

        await tester.pumpWidget(buildTestWidget());

        // Step 1
        await tester.enterText(
          find.byKey(const Key('customer_name_field')),
          'Ahmed Ali',
        );
        await tester.enterText(
          find.byKey(const Key('customer_email_field')),
          'ahmed@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('customer_phone_field')),
          '+966501234567',
        );
        await tester.tap(find.byKey(const Key('customer_request_otp_button')));
        await tester.pumpAndSettle();

        // Step 2
        await tester.enterText(
          find.byKey(const Key('customer_otp_field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('customer_verify_otp_button')));
        await tester.pumpAndSettle();

        expect(mockRepo.verifyOtpCallCount, equals(1));
        expect(mockRepo.lastVerifyOtpPhone, equals('+966501234567'));
        expect(mockRepo.lastVerifyOtpCode, equals('123456'));

        // Routed to Profile Setup Shell because isNew == true
        expect(find.text('Profile Setup Shell'), findsOneWidget);
        expect(find.text('Customer Home Shell'), findsNothing);
      },
    );

    testWidgets(
      'Step 2: verifying OTP for returning customer (isNew == false) routes to Customer Home',
      (tester) async {
        setupViewport(tester);
        mockRepo.sendOtpResult = Result.success('OTP sent');
        mockRepo.verifyOtpResult = Result.success(
          const AuthResponseModel(
            user: UserModel(
              id: 'existing_cust_1',
              phoneNumber: '+966501234567',
              fullName: 'Ahmed Ali',
              email: 'ahmed@example.com',
              role: UserRole.customer,
            ),
            token: 'mock_jwt_token',
            isNew: false,
          ),
        );

        await tester.pumpWidget(buildTestWidget());

        // Step 1
        await tester.enterText(
          find.byKey(const Key('customer_name_field')),
          'Ahmed Ali',
        );
        await tester.enterText(
          find.byKey(const Key('customer_email_field')),
          'ahmed@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('customer_phone_field')),
          '+966501234567',
        );
        await tester.tap(find.byKey(const Key('customer_request_otp_button')));
        await tester.pumpAndSettle();

        // Step 2
        await tester.enterText(
          find.byKey(const Key('customer_otp_field')),
          '654321',
        );
        await tester.tap(find.byKey(const Key('customer_verify_otp_button')));
        await tester.pumpAndSettle();

        expect(mockRepo.verifyOtpCallCount, equals(1));
        expect(mockRepo.lastVerifyOtpPhone, equals('+966501234567'));
        expect(mockRepo.lastVerifyOtpCode, equals('654321'));

        // Routed to Customer Home Shell because isNew == false
        expect(find.text('Customer Home Shell'), findsOneWidget);
        expect(find.text('Profile Setup Shell'), findsNothing);
      },
    );

    testWidgets('Step 2: displays error banner on invalid OTP code', (tester) async {
      setupViewport(tester);
      mockRepo.sendOtpResult = Result.success('OTP sent');
      mockRepo.verifyOtpResult = Result.failure(
        const ValidationFailure(message: 'Invalid or expired OTP code'),
      );

      await tester.pumpWidget(buildTestWidget());

      // Step 1
      await tester.enterText(
        find.byKey(const Key('customer_name_field')),
        'Ahmed Ali',
      );
      await tester.enterText(
        find.byKey(const Key('customer_email_field')),
        'ahmed@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('customer_phone_field')),
        '+966501234567',
      );
      await tester.tap(find.byKey(const Key('customer_request_otp_button')));
      await tester.pumpAndSettle();

      // Step 2
      await tester.enterText(
        find.byKey(const Key('customer_otp_field')),
        '000000',
      );
      await tester.tap(find.byKey(const Key('customer_verify_otp_button')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid or expired OTP code'), findsOneWidget);
      expect(find.text('Customer Home Shell'), findsNothing);
      expect(find.text('Profile Setup Shell'), findsNothing);
    });

    testWidgets('Step 2: resend code triggers sendOtp again', (tester) async {
      setupViewport(tester);
      mockRepo.sendOtpResult = Result.success('Code sent');

      await tester.pumpWidget(buildTestWidget());

      // Step 1
      await tester.enterText(
        find.byKey(const Key('customer_name_field')),
        'Ahmed Ali',
      );
      await tester.enterText(
        find.byKey(const Key('customer_email_field')),
        'ahmed@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('customer_phone_field')),
        '+966501234567',
      );
      await tester.tap(find.byKey(const Key('customer_request_otp_button')));
      await tester.pumpAndSettle();

      expect(mockRepo.sendOtpCallCount, equals(1));

      // Resend OTP in Step 2
      await tester.tap(find.byKey(const Key('customer_resend_otp_button')));
      await tester.pumpAndSettle();

      expect(mockRepo.sendOtpCallCount, equals(2));
      expect(find.text('Code sent'), findsOneWidget);
    });

    testWidgets('Step 2: displays rate limit error banner when resendOtp fails with 429', (tester) async {
      setupViewport(tester);
      mockRepo.sendOtpResult = Result.success('Code sent');

      await tester.pumpWidget(buildTestWidget());

      // Step 1
      await tester.enterText(
        find.byKey(const Key('customer_name_field')),
        'Ahmed Ali',
      );
      await tester.enterText(
        find.byKey(const Key('customer_email_field')),
        'ahmed@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('customer_phone_field')),
        '+966501234567',
      );
      await tester.tap(find.byKey(const Key('customer_request_otp_button')));
      await tester.pumpAndSettle();

      // Configure next sendOtp to fail with rate limit
      mockRepo.sendOtpResult = Result.failure(
        const RateLimitFailure(
          message: 'Too many OTP requests. Please wait before requesting another code.',
        ),
      );

      // Resend OTP in Step 2
      await tester.tap(find.byKey(const Key('customer_resend_otp_button')));
      await tester.pumpAndSettle();

      expect(mockRepo.sendOtpCallCount, equals(2));
      expect(
        find.text('Too many OTP requests. Please wait before requesting another code.'),
        findsOneWidget,
      );
    });

    testWidgets('Step 2: Change number returns to Step 1', (tester) async {
      setupViewport(tester);
      mockRepo.sendOtpResult = Result.success('Code sent');

      await tester.pumpWidget(buildTestWidget());

      // Step 1
      await tester.enterText(
        find.byKey(const Key('customer_name_field')),
        'Ahmed Ali',
      );
      await tester.enterText(
        find.byKey(const Key('customer_email_field')),
        'ahmed@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('customer_phone_field')),
        '+966501234567',
      );
      await tester.tap(find.byKey(const Key('customer_request_otp_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customer_otp_field')), findsOneWidget);

      // Tap Change button
      await tester.tap(find.byKey(const Key('customer_change_phone_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customer_otp_field')), findsNothing);
      expect(find.byKey(const Key('customer_name_field')), findsOneWidget);
      expect(find.byKey(const Key('customer_email_field')), findsOneWidget);
      expect(find.byKey(const Key('customer_phone_field')), findsOneWidget);
    });

    testWidgets('navigates to Store Staff portal', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Store Staff'));
      await tester.pumpAndSettle();

      expect(find.text('Staff Login Shell'), findsOneWidget);
    });

    testWidgets('navigates to Delivery Rider portal', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Delivery Rider'));
      await tester.pumpAndSettle();

      expect(find.text('Rider Login Shell'), findsOneWidget);
    });

    testWidgets('navigates to Admin portal', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      expect(find.text('Admin Magic Link Shell'), findsOneWidget);
    });
  });
}
