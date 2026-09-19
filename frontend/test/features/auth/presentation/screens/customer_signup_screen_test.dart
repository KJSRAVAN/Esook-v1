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

  group('CustomerSignupScreen', () {
    testWidgets('renders all required signup fields and labels', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Create Account'), findsNWidgets(2));
      expect(
        find.text('Join eSOuQ for fast delivery of fresh essentials'),
        findsOneWidget,
      );
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Delivery Address (Optional)'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Create Account'),
        findsOneWidget,
      );
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('validates required fields on empty submit', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your phone number'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
      expect(mockRepo.signupCallCount, equals(0));
    });

    testWidgets('enforces 8 character minimum password rule', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Fatima Al-Balushi');
      await tester.enterText(textFields.at(1), '+96898765432');
      await tester.enterText(textFields.at(2), 'short'); // 5 chars

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
      expect(mockRepo.signupCallCount, equals(0));
    });

    testWidgets(
      'successfully signs up customer and navigates to customerHome',
      (tester) async {
        mockRepo.signupResult = Result.success(
          AuthResponseModel(
            user: const UserModel(
              id: 'cust_99',
              phoneNumber: '+96898765432',
              fullName: 'Fatima Al-Balushi',
              role: UserRole.customer,
              address: 'Villa 12, Muscat',
            ),
            token: 'signup_jwt_token',
          ),
        );

        await tester.pumpWidget(buildTestWidget());

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'Fatima Al-Balushi');
        await tester.enterText(textFields.at(1), '+96898765432');
        await tester.enterText(textFields.at(2), 'SecurePass123');
        await tester.enterText(textFields.at(3), 'Villa 12, Muscat');

        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Create Account'),
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
        await tester.pumpAndSettle();

        expect(mockRepo.signupCallCount, equals(1));
        expect(mockRepo.lastSignupName, equals('Fatima Al-Balushi'));
        expect(mockRepo.lastSignupPhone, equals('+96898765432'));
        expect(mockRepo.lastSignupPassword, equals('SecurePass123'));
        expect(mockRepo.lastSignupAddress, equals('Villa 12, Muscat'));
        expect(find.text('Customer Home Shell'), findsOneWidget);
      },
    );

    testWidgets(
      'displays conflict error banner when phone is already registered',
      (tester) async {
        mockRepo.signupResult = Result.failure(
          const ConflictFailure(
            message: 'A user with this phone number already exists.',
          ),
        );

        await tester.pumpWidget(buildTestWidget());

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'Fatima Al-Balushi');
        await tester.enterText(textFields.at(1), '+96898765432');
        await tester.enterText(textFields.at(2), 'SecurePass123');

        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Create Account'),
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
        await tester.pumpAndSettle();

        expect(mockRepo.signupCallCount, equals(1));
        expect(
          find.text('A user with this phone number already exists.'),
          findsOneWidget,
        );
      },
    );
  });
}
