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
    testWidgets(
      'renders staff portal branding, method selector, and Saudi phone hint',
      (tester) async {
        await tester.pumpWidget(buildStaffWidget());

        expect(find.text('Store Operations'), findsOneWidget);
        expect(
          find.text(
            'Staff & Store Manager sign-in for orders, stock & inventory',
          ),
          findsOneWidget,
        );
        expect(find.text('Phone Number'), findsOneWidget);
        expect(find.text('Email Address'), findsOneWidget);
        expect(find.text('Staff Phone Number'), findsOneWidget);
        expect(find.text('+966 50 123 4567'), findsOneWidget);
        expect(find.text('+968 9123 4567'), findsNothing); // Oman hint removed
        expect(
          find.widgetWithText(ElevatedButton, 'Staff Login'),
          findsOneWidget,
        );
        expect(find.text('Return to Customer App'), findsOneWidget);
      },
    );

    testWidgets(
      'authenticates store staff using phone + password and navigates to storeHome',
      (tester) async {
        mockRepo.loginResult = Result.success(
          AuthResponseModel(
            user: const UserModel(
              id: 'staff_1',
              phoneNumber: '+966512345678',
              fullName: 'Store Associate',
              role: UserRole.storeStaff,
              storeId: 'store_101',
            ),
            token: 'staff_jwt_token',
          ),
        );

        await tester.pumpWidget(buildStaffWidget());

        await tester.enterText(
          find.byKey(const Key('staff_phone_field')),
          '+966512345678',
        );
        await tester.enterText(
          find.byKey(const Key('staff_password_field')),
          'StaffPass123',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Staff Login'));
        await tester.pumpAndSettle();

        expect(mockRepo.loginCallCount, equals(1));
        expect(mockRepo.lastLoginPhone, equals('+966512345678'));
        expect(mockRepo.lastLoginEmail, isNull);
        expect(mockRepo.lastLoginPassword, equals('StaffPass123'));
        expect(find.text('Store Home Shell'), findsOneWidget);
      },
    );

    testWidgets(
      'authenticates store manager using phone + password and navigates to storeHome',
      (tester) async {
        mockRepo.loginResult = Result.success(
          AuthResponseModel(
            user: const UserModel(
              id: 'mgr_1',
              phoneNumber: '+966523456789',
              fullName: 'Store Manager',
              role: UserRole.storeManager,
              storeId: 'store_101',
            ),
            token: 'mgr_jwt_token',
          ),
        );

        await tester.pumpWidget(buildStaffWidget());

        await tester.enterText(
          find.byKey(const Key('staff_phone_field')),
          '+966523456789',
        );
        await tester.enterText(
          find.byKey(const Key('staff_password_field')),
          'MgrPass123',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Staff Login'));
        await tester.pumpAndSettle();

        expect(mockRepo.loginCallCount, equals(1));
        expect(mockRepo.lastLoginPhone, equals('+966523456789'));
        expect(mockRepo.lastLoginEmail, isNull);
        expect(find.text('Store Home Shell'), findsOneWidget);
      },
    );

    testWidgets(
      'authenticates store staff using email + password request and navigates to storeHome',
      (tester) async {
        mockRepo.loginResult = Result.success(
          AuthResponseModel(
            user: const UserModel(
              id: 'staff_2',
              phoneNumber: '+966512345678',
              email: 'staff.ahmed@esook.store',
              fullName: 'Ahmed Staff',
              role: UserRole.storeStaff,
              storeId: 'store_101',
            ),
            token: 'staff_email_jwt',
          ),
        );

        await tester.pumpWidget(buildStaffWidget());

        // Switch to Email mode
        await tester.tap(find.text('Email Address'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('staff_email_field')), findsOneWidget);
        expect(find.byKey(const Key('staff_phone_field')), findsNothing);

        await tester.enterText(
          find.byKey(const Key('staff_email_field')),
          'staff.ahmed@esook.store',
        );
        await tester.enterText(
          find.byKey(const Key('staff_password_field')),
          'StaffEmailPass123',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Staff Login'));
        await tester.pumpAndSettle();

        expect(mockRepo.loginCallCount, equals(1));
        expect(mockRepo.lastLoginEmail, equals('staff.ahmed@esook.store'));
        expect(mockRepo.lastLoginPhone, isNull);
        expect(mockRepo.lastLoginPassword, equals('StaffEmailPass123'));
        expect(find.text('Store Home Shell'), findsOneWidget);
      },
    );

    testWidgets(
      'accepts and normalizes international Indian phone number (+91 98765 43210)',
      (tester) async {
        mockRepo.loginResult = Result.success(
          AuthResponseModel(
            user: const UserModel(
              id: 'staff_norm',
              phoneNumber: '+966501234567',
              fullName: 'Normalized Staff',
              role: UserRole.storeStaff,
            ),
            token: 'jwt_norm',
          ),
        );

        await tester.pumpWidget(buildStaffWidget());

        // Enter Indian format with spaces
        await tester.enterText(
          find.byKey(const Key('staff_phone_field')),
          '+91 98765 43210',
        );
        await tester.enterText(
          find.byKey(const Key('staff_password_field')),
          'Pass1234',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Staff Login'));
        await tester.pumpAndSettle();

        expect(mockRepo.loginCallCount, equals(1));
        expect(mockRepo.lastLoginPhone, equals('+919876543210'));
      },
    );

    testWidgets(
      'normalizes phone entered with international prefix and spaces (+966 50 123 4567)',
      (tester) async {
        mockRepo.loginResult = Result.success(
          AuthResponseModel(
            user: const UserModel(
              id: 'staff_spaces',
              phoneNumber: '+966501234567',
              fullName: 'Spaces Staff',
              role: UserRole.storeStaff,
            ),
            token: 'jwt_spaces',
          ),
        );

        await tester.pumpWidget(buildStaffWidget());

        await tester.enterText(
          find.byKey(const Key('staff_phone_field')),
          '+966 50 123 4567',
        );
        await tester.enterText(
          find.byKey(const Key('staff_password_field')),
          'Pass1234',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Staff Login'));
        await tester.pumpAndSettle();

        expect(mockRepo.loginCallCount, equals(1));
        expect(mockRepo.lastLoginPhone, equals('+966501234567'));
      },
    );

    testWidgets(
      'rejects local phone number without country context and shows validation error',
      (tester) async {
        await tester.pumpWidget(buildStaffWidget());

        // Local format without country code cannot be blindly assumed
        await tester.enterText(
          find.byKey(const Key('staff_phone_field')),
          '050 123 4567',
        );
        await tester.enterText(
          find.byKey(const Key('staff_password_field')),
          'Pass1234',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Staff Login'));
        await tester.pumpAndSettle();

        expect(mockRepo.loginCallCount, equals(0));
        expect(
          find.text('Please enter a valid phone number'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows validation error on invalid or overlength phone number',
      (tester) async {
        await tester.pumpWidget(buildStaffWidget());

        await tester.enterText(
          find.byKey(const Key('staff_phone_field')),
          '12345',
        );
        await tester.enterText(
          find.byKey(const Key('staff_password_field')),
          'Pass1234',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Staff Login'));
        await tester.pumpAndSettle();

        expect(mockRepo.loginCallCount, equals(0));
        expect(
          find.text('Please enter a valid phone number'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows validation error on invalid email address',
      (tester) async {
        await tester.pumpWidget(buildStaffWidget());

        await tester.tap(find.text('Email Address'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('staff_email_field')),
          'notanemail',
        );
        await tester.enterText(
          find.byKey(const Key('staff_password_field')),
          'Pass1234',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Staff Login'));
        await tester.pumpAndSettle();

        expect(mockRepo.loginCallCount, equals(0));
        expect(find.text('Please enter a valid email address'), findsOneWidget);
      },
    );

    testWidgets(
      'denies access and shows error when non-staff/non-manager role logs in',
      (tester) async {
        mockRepo.loginResult = Result.success(
          AuthResponseModel(
            user: const UserModel(
              id: 'cust_intruder',
              phoneNumber: '+966501234567',
              fullName: 'Customer Intruder',
              role: UserRole.customer,
            ),
            token: 'cust_jwt',
          ),
        );

        await tester.pumpWidget(buildStaffWidget());

        await tester.enterText(
          find.byKey(const Key('staff_phone_field')),
          '+966501234567',
        );
        await tester.enterText(
          find.byKey(const Key('staff_password_field')),
          'Pass1234',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Staff Login'));
        await tester.pumpAndSettle();

        expect(mockRepo.loginCallCount, equals(1));
        expect(
          find.text('Access denied. Store Staff or Store Manager privileges required.'),
          findsOneWidget,
        );
        expect(find.text('Store Home Shell'), findsNothing);
      },
    );
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

    testWidgets('authenticates rider with Indian international phone number (+919876543210)', (tester) async {
      mockRepo.loginResult = Result.success(
        AuthResponseModel(
          user: const UserModel(
            id: 'rider_in',
            phoneNumber: '+919876543210',
            fullName: 'Rider Arjun',
            role: UserRole.deliveryRider,
          ),
          token: 'rider_jwt_in',
        ),
      );

      await tester.pumpWidget(buildRiderWidget());

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '+91 98765 43210');
      await tester.enterText(textFields.at(1), 'RiderPass123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Rider Login'));
      await tester.pumpAndSettle();

      expect(mockRepo.loginCallCount, equals(1));
      expect(mockRepo.lastLoginPhone, equals('+919876543210'));
      expect(find.text('Rider Home Shell'), findsOneWidget);
    });

    testWidgets('shows validation error on invalid rider phone number', (tester) async {
      await tester.pumpWidget(buildRiderWidget());

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'invalid-phone');
      await tester.enterText(textFields.at(1), 'RiderPass123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Rider Login'));
      await tester.pumpAndSettle();

      expect(mockRepo.loginCallCount, equals(0));
      expect(find.text('Please enter a valid phone number'), findsOneWidget);
    });
  });
}
