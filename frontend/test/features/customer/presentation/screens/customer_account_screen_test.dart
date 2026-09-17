import 'package:esouq/core/routing/app_routes.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/customer/presentation/screens/customer_account_screen.dart';
import 'package:esouq/features/customer/presentation/screens/customer_edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../auth/mocks/mock_auth_repository.dart';

void main() {
  group('CustomerAccountScreen', () {
    late MockAuthRepository mockAuthRepository;

    final testUser = const UserModel(
      id: 'usr_customer_1',
      phoneNumber: '+966501234567',
      email: 'customer@esouq.com',
      fullName: 'Fatima Al-Zahra',
      role: UserRole.customer,
      isActive: true,
    );

    setUp(() {
      mockAuthRepository = MockAuthRepository();
      mockAuthRepository.currentUser = testUser;
    });

    Widget buildTestWidget({UserModel? initialUser}) {
      return MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.login) {
            return MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Login Screen')),
            );
          }
          return null;
        },
        home: CustomerAccountScreen(
          authRepository: mockAuthRepository,
          initialUser: initialUser,
        ),
      );
    }

    testWidgets('renders real user name, phone, email, and role badge',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(initialUser: testUser));
      await tester.pumpAndSettle();

      expect(find.text('Customer Account'), findsOneWidget);
      expect(find.byKey(const Key('account_user_name')), findsOneWidget);
      expect(find.text('Fatima Al-Zahra'), findsOneWidget);
      expect(find.byKey(const Key('account_user_phone')), findsOneWidget);
      expect(find.text('+966501234567'), findsOneWidget);
      expect(find.byKey(const Key('account_user_email')), findsOneWidget);
      expect(find.text('customer@esouq.com'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('Edit Profile action exists and navigates to CustomerEditProfileScreen',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(initialUser: testUser));
      await tester.pumpAndSettle();

      final editTile = find.byKey(const Key('account_edit_profile_tile'));
      expect(editTile, findsOneWidget);

      await tester.tap(editTile);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerEditProfileScreen), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('Sign Out button remains functional and calls repository logout',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(initialUser: testUser));
      await tester.pumpAndSettle();

      final signOutBtn = find.byKey(const Key('account_signout_button'));
      expect(signOutBtn, findsOneWidget);

      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();

      expect(mockAuthRepository.logoutCallCount, equals(1));
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('refreshes profile information when refresh button is tapped',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(initialUser: testUser));
      await tester.pumpAndSettle();

      // Update the user in repository
      final updatedUser = const UserModel(
        id: 'usr_customer_1',
        phoneNumber: '+966501234567',
        email: 'newemail@esouq.com',
        fullName: 'Fatima Updated',
        role: UserRole.customer,
      );
      mockAuthRepository.currentUser = updatedUser;

      final refreshBtn = find.byKey(const Key('account_refresh_button'));
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      expect(find.text('Fatima Updated'), findsOneWidget);
      expect(find.text('newemail@esouq.com'), findsOneWidget);
    });
  });
}
