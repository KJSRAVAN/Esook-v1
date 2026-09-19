import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/routing/app_routes.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/auth/domain/models/auth_response_model.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/auth/presentation/screens/admin_magic_link_pending_screen.dart';
import 'package:esouq/features/auth/presentation/screens/admin_magic_link_request_screen.dart';
import 'package:esouq/features/auth/presentation/screens/admin_verify_screen.dart';
import 'package:esouq/features/auth/presentation/widgets/auth_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_auth_repository.dart';

void main() {
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  Widget buildRequestWidget() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      routes: {
        AppRoutes.login: (_) =>
            const Scaffold(body: Text('Customer Login Shell')),
        AppRoutes.adminHome: (_) =>
            const Scaffold(body: Text('Admin Home Shell')),
        AppRoutes.adminPending: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return AdminMagicLinkPendingScreen(
            email: args?['email'] ?? 'admin@esook.com',
            authRepository: mockRepo,
          );
        },
      },
      home: AuthScope(
        repository: mockRepo,
        child: AdminMagicLinkRequestScreen(authRepository: mockRepo),
      ),
    );
  }

  Widget buildPendingWidget({String email = 'admin@esook.com'}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      routes: {
        AppRoutes.adminMagicLink: (_) =>
            const Scaffold(body: Text('Admin Request Shell')),
      },
      home: AuthScope(
        repository: mockRepo,
        child: AdminMagicLinkPendingScreen(
          email: email,
          authRepository: mockRepo,
        ),
      ),
    );
  }

  Widget buildVerifyWidget({String? token}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      routes: {
        AppRoutes.adminHome: (_) =>
            const Scaffold(body: Text('Admin Home Shell')),
        AppRoutes.adminMagicLink: (_) =>
            const Scaffold(body: Text('Admin Request Shell')),
      },
      home: AuthScope(
        repository: mockRepo,
        child: AdminVerifyScreen(token: token, authRepository: mockRepo),
      ),
    );
  }

  group('Admin Authentication Flow', () {
    testWidgets(
      'request screen validates email/password and logs in super admin',
      (tester) async {
        mockRepo.loginResult = Result.success(
          const AuthResponseModel(
            user: UserModel(
              id: 'admin_1',
              phoneNumber: '+966500000001',
              email: 'admin@esook.store',
              fullName: 'Super Admin',
              role: UserRole.superAdmin,
            ),
            token: 'mock_admin_jwt',
          ),
        );

        await tester.pumpWidget(buildRequestWidget());

        expect(find.text('Admin Portal'), findsOneWidget);
        expect(find.text('Administrator Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);

        // Submit empty
        await tester.tap(find.widgetWithText(ElevatedButton, 'Admin Sign In'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter your administrator email'),
          findsOneWidget,
        );
        expect(mockRepo.loginCallCount, equals(0));

        // Submit invalid email
        await tester.enterText(
          find.byType(TextFormField).first,
          'not-an-email',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Admin Sign In'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid email address'), findsOneWidget);

        // Submit valid email and password
        await tester.enterText(
          find.byType(TextFormField).first,
          'admin@esook.store',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'AdminPass@123',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Admin Sign In'));
        await tester.pumpAndSettle();

        expect(mockRepo.loginCallCount, equals(1));
        expect(mockRepo.lastLoginEmail, equals('admin@esook.store'));
        expect(mockRepo.lastLoginPassword, equals('AdminPass@123'));
        expect(find.text('Admin Home Shell'), findsOneWidget);
      },
    );

    testWidgets('request screen rejects non-super-admin user', (tester) async {
      mockRepo.loginResult = Result.success(
        const AuthResponseModel(
          user: UserModel(
            id: 'staff_1',
            phoneNumber: '+966500000002',
            email: 'staff@esook.store',
            fullName: 'Store Staff',
            role: UserRole.storeStaff,
          ),
          token: 'mock_staff_jwt',
        ),
      );

      await tester.pumpWidget(buildRequestWidget());

      await tester.enterText(
        find.byType(TextFormField).first,
        'staff@esook.store',
      );
      await tester.enterText(find.byType(TextFormField).last, 'StaffPass@123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Admin Sign In'));
      await tester.pumpAndSettle();

      expect(mockRepo.loginCallCount, equals(1));
      expect(
        find.text('Access denied. Super Administrator privileges required.'),
        findsOneWidget,
      );
      expect(find.text('Admin Home Shell'), findsNothing);
    });

    testWidgets('pending screen renders email and throttles resend button', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPendingWidget(email: 'superadmin@esouq.com'),
      );

      expect(find.text('Check Your Email'), findsOneWidget);
      expect(find.text('superadmin@esouq.com'), findsOneWidget);

      // Resend button should start in cooldown
      expect(find.textContaining('Resend Link in'), findsOneWidget);
      final resendButton = find.byType(OutlinedButton);
      final outlinedButtonWidget = tester.widget<OutlinedButton>(resendButton);
      expect(outlinedButtonWidget.onPressed, isNull);

      // Fast-forward cooldown timer
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.text('Resend Login Link'), findsOneWidget);

      // Tap resend
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Resend Login Link'),
      );
      await tester.pumpAndSettle();

      expect(mockRepo.requestMagicLinkCallCount, equals(1));
      expect(
        find.text('A fresh login link has been sent to your email.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'verify screen redeems valid token and navigates to adminHome',
      (tester) async {
        mockRepo.verifyMagicLinkResult = Result.success(
          AuthResponseModel(
            user: const UserModel(
              id: 'admin_1',
              phoneNumber: '+96890000000',
              fullName: 'Super Admin',
              role: UserRole.superAdmin,
            ),
            token: 'verified_admin_jwt',
          ),
        );

        await tester.pumpWidget(
          buildVerifyWidget(token: 'valid_secure_token_123'),
        );
        await tester.pumpAndSettle();

        expect(mockRepo.verifyMagicLinkCallCount, equals(1));
        expect(mockRepo.lastVerifyToken, equals('valid_secure_token_123'));
        expect(find.text('Admin Home Shell'), findsOneWidget);
      },
    );

    testWidgets(
      'verify screen handles expired/invalid token with retry action',
      (tester) async {
        mockRepo.verifyMagicLinkResult = Result.failure(
          const UnauthorizedFailure(
            message: 'Magic link has expired or is invalid.',
          ),
        );

        await tester.pumpWidget(buildVerifyWidget(token: 'expired_token_999'));
        await tester.pumpAndSettle();

        expect(mockRepo.verifyMagicLinkCallCount, equals(1));
        expect(find.text('Link Expired or Invalid'), findsOneWidget);
        expect(
          find.text('Magic link has expired or is invalid.'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(ElevatedButton, 'Request New Link'),
          findsOneWidget,
        );

        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Request New Link'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Admin Request Shell'), findsOneWidget);
      },
    );
  });
}
