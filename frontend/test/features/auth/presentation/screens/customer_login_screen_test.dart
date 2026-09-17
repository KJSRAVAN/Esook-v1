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

  group('CustomerLoginScreen - OTP Flow', () {
    testWidgets('renders initial phone input step with branding and portals', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign in to continue ordering fresh groceries'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Send OTP'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Store Staff'), findsOneWidget);
      expect(find.text('Delivery Rider'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.byKey(const Key('dev_customer_preview_button')), findsOneWidget);
    });

    testWidgets('shows validation error when submitting empty phone number', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your phone number'), findsOneWidget);
      expect(mockRepo.sendOtpCallCount, equals(0));
    });

    testWidgets('shows validation error for phone number shorter than 8 digits', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid phone number'), findsOneWidget);
      expect(mockRepo.sendOtpCallCount, equals(0));
    });

    testWidgets('displays error banner when sendOtp fails', (tester) async {
      mockRepo.sendOtpResult = Result.failure(
        const RateLimitFailure(message: 'Too many OTP requests. Please wait.'),
      );

      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextFormField), '+966501234567');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
      await tester.pumpAndSettle();

      expect(mockRepo.sendOtpCallCount, equals(1));
      expect(mockRepo.lastSendOtpPhone, equals('+966501234567'));
      expect(find.text('Too many OTP requests. Please wait.'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);
    });

    testWidgets('advances to OTP verification step on successful sendOtp', (tester) async {
      mockRepo.sendOtpResult = Result.success('Verification code sent via WhatsApp');

      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextFormField), '+966501234567');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
      await tester.pumpAndSettle();

      expect(mockRepo.sendOtpCallCount, equals(1));
      expect(find.text('Verify Code'), findsOneWidget);
      expect(find.text('Enter the 6-digit code sent to +966501234567'), findsOneWidget);
      expect(find.text('Verification code sent via WhatsApp'), findsOneWidget);
      expect(find.byKey(const Key('otp_code_field')), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Verify & Sign In'), findsOneWidget);
      expect(find.text('Resend Code'), findsOneWidget);
      expect(find.text('Change Phone'), findsOneWidget);
    });

    testWidgets('validates 6-digit OTP code before verifying', (tester) async {
      mockRepo.sendOtpResult = Result.success('Code sent');

      await tester.pumpWidget(buildTestWidget());

      // Advance to OTP step
      await tester.enterText(find.byType(TextFormField), '+966501234567');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
      await tester.pumpAndSettle();

      // Submit empty OTP
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify & Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter the 6-digit OTP code'), findsOneWidget);
      expect(mockRepo.verifyOtpCallCount, equals(0));

      // Enter less than 6 digits
      await tester.enterText(find.byKey(const Key('otp_code_field')), '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify & Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('OTP must be exactly 6 digits'), findsOneWidget);
      expect(mockRepo.verifyOtpCallCount, equals(0));
    });

    testWidgets('submits 6-digit OTP and navigates to customerHome on success', (tester) async {
      mockRepo.sendOtpResult = Result.success('Code sent');
      mockRepo.verifyOtpResult = Result.success(
        AuthResponseModel(
          user: const UserModel(
            id: 'cust_99',
            phoneNumber: '+966501234567',
            fullName: 'Customer',
            role: UserRole.customer,
          ),
          token: 'valid_jwt_access_token',
        ),
      );

      await tester.pumpWidget(buildTestWidget());

      // Send OTP
      await tester.enterText(find.byType(TextFormField), '+966501234567');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
      await tester.pumpAndSettle();

      // Enter OTP
      await tester.enterText(find.byKey(const Key('otp_code_field')), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify & Sign In'));
      await tester.pumpAndSettle();

      expect(mockRepo.verifyOtpCallCount, equals(1));
      expect(mockRepo.lastVerifyOtpPhone, equals('+966501234567'));
      expect(mockRepo.lastVerifyOtpCode, equals('123456'));
      expect(find.text('Customer Home Shell'), findsOneWidget);
    });

    testWidgets('displays error banner when verifyOtp fails (invalid OTP code)', (tester) async {
      mockRepo.sendOtpResult = Result.success('Code sent');
      mockRepo.verifyOtpResult = Result.failure(
        const ValidationFailure(message: 'Invalid code. 4 attempts remaining.'),
      );

      await tester.pumpWidget(buildTestWidget());

      // Send OTP
      await tester.enterText(find.byType(TextFormField), '+966501234567');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
      await tester.pumpAndSettle();

      // Enter wrong OTP
      await tester.enterText(find.byKey(const Key('otp_code_field')), '999999');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify & Sign In'));
      await tester.pumpAndSettle();

      expect(mockRepo.verifyOtpCallCount, equals(1));
      expect(find.text('Invalid code. 4 attempts remaining.'), findsOneWidget);
    });

    testWidgets('resends OTP when tapping Resend Code', (tester) async {
      mockRepo.sendOtpResult = Result.success('First code sent');

      await tester.pumpWidget(buildTestWidget());

      // Send OTP
      await tester.enterText(find.byType(TextFormField), '+966501234567');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
      await tester.pumpAndSettle();

      expect(mockRepo.sendOtpCallCount, equals(1));

      // Tap Resend Code
      mockRepo.sendOtpResult = Result.success('New code sent via WhatsApp');
      await tester.tap(find.text('Resend Code'));
      await tester.pumpAndSettle();

      expect(mockRepo.sendOtpCallCount, equals(2));
      expect(mockRepo.lastSendOtpPhone, equals('+966501234567'));
      expect(find.text('New code sent via WhatsApp'), findsOneWidget);
    });

    testWidgets('returns to phone input step when tapping Change Phone', (tester) async {
      mockRepo.sendOtpResult = Result.success('Code sent');

      await tester.pumpWidget(buildTestWidget());

      // Send OTP
      await tester.enterText(find.byType(TextFormField), '+966501234567');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
      await tester.pumpAndSettle();

      expect(find.text('Verify Code'), findsOneWidget);

      // Tap Change Phone
      await tester.tap(find.text('Change Phone'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Send OTP'), findsOneWidget);
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
