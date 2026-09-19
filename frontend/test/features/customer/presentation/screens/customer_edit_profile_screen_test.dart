import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/customer/presentation/screens/customer_edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../auth/mocks/mock_auth_repository.dart';

void main() {
  group('CustomerEditProfileScreen', () {
    late MockAuthRepository mockAuthRepository;

    final initialUser = const UserModel(
      id: 'usr_cust_1',
      phoneNumber: '+966501234567',
      email: 'original@esouq.com',
      fullName: 'Original Name',
      role: UserRole.customer,
      isActive: true,
    );

    setUp(() {
      mockAuthRepository = MockAuthRepository();
      mockAuthRepository.currentUser = initialUser;
    });

    Widget buildTestWidget({UserModel? user}) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                key: const Key('open_edit_button'),
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerEditProfileScreen(
                      authRepository: mockAuthRepository,
                      currentUser: user ?? initialUser,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openEditScreen(WidgetTester tester, {UserModel? user}) async {
      await tester.pumpWidget(buildTestWidget(user: user));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open_edit_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('prefills name, email, and read-only phone fields correctly', (
      tester,
    ) async {
      await openEditScreen(tester);

      final nameField = find.byKey(const Key('edit_profile_name_field'));
      final emailField = find.byKey(const Key('edit_profile_email_field'));
      final phoneField = find.byKey(const Key('edit_profile_phone_field'));
      final saveBtn = find.byKey(const Key('edit_profile_save_button'));

      expect(nameField, findsOneWidget);
      expect(emailField, findsOneWidget);
      expect(phoneField, findsOneWidget);
      expect(saveBtn, findsOneWidget);

      expect(find.text('Original Name'), findsOneWidget);
      expect(find.text('original@esouq.com'), findsOneWidget);
      expect(find.text('+966501234567'), findsOneWidget);

      // Verify phone field is read-only
      final phoneTextField = tester.widget<TextField>(
        find.descendant(of: phoneField, matching: find.byType(TextField)),
      );
      expect(phoneTextField.readOnly, isTrue);
      expect(phoneTextField.enabled, isFalse);
    });

    testWidgets(
      'shows validation error when name is empty or shorter than 2 characters',
      (tester) async {
        await openEditScreen(tester);

        final nameField = find.byKey(const Key('edit_profile_name_field'));
        final saveBtn = find.byKey(const Key('edit_profile_save_button'));

        // Test empty name
        await tester.enterText(nameField, '');
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(find.text('Please enter your name'), findsOneWidget);
        expect(mockAuthRepository.updateProfileCallCount, equals(0));

        // Test 1 character name
        await tester.enterText(nameField, 'A');
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(find.text('Name must be at least 2 characters'), findsOneWidget);
        expect(mockAuthRepository.updateProfileCallCount, equals(0));
      },
    );

    testWidgets('shows validation error when email format is invalid', (
      tester,
    ) async {
      await openEditScreen(tester);

      final emailField = find.byKey(const Key('edit_profile_email_field'));
      final saveBtn = find.byKey(const Key('edit_profile_save_button'));

      await tester.enterText(emailField, 'not-an-email');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(mockAuthRepository.updateProfileCallCount, equals(0));
    });

    testWidgets('handles no changes cleanly without triggering API call', (
      tester,
    ) async {
      await openEditScreen(tester);

      final saveBtn = find.byKey(const Key('edit_profile_save_button'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Should not call updateProfile because nothing changed
      expect(mockAuthRepository.updateProfileCallCount, equals(0));
      expect(find.text('No changes to save'), findsOneWidget);
    });

    testWidgets(
      'calls updateProfile with modified name and email on save and returns to Account',
      (tester) async {
        await openEditScreen(tester);

        final nameField = find.byKey(const Key('edit_profile_name_field'));
        final emailField = find.byKey(const Key('edit_profile_email_field'));
        final saveBtn = find.byKey(const Key('edit_profile_save_button'));

        await tester.enterText(nameField, 'New Name');
        await tester.enterText(emailField, 'new@esouq.com');
        await tester.tap(saveBtn);
        await tester.pump();

        expect(mockAuthRepository.updateProfileCallCount, equals(1));
        expect(mockAuthRepository.lastUpdateName, equals('New Name'));
        expect(mockAuthRepository.lastUpdateEmail, equals('new@esouq.com'));

        await tester.pumpAndSettle();
        expect(find.text('Profile updated successfully'), findsOneWidget);
        expect(find.byType(CustomerEditProfileScreen), findsNothing);
      },
    );

    testWidgets('remains on screen and displays error when API update fails', (
      tester,
    ) async {
      mockAuthRepository.updateProfileResult = Result.failure(
        const ValidationFailure(message: 'Email already registered'),
      );

      await openEditScreen(tester);

      final nameField = find.byKey(const Key('edit_profile_name_field'));
      final saveBtn = find.byKey(const Key('edit_profile_save_button'));

      await tester.enterText(nameField, 'Updated Name');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerEditProfileScreen), findsOneWidget);
      expect(find.text('Email already registered'), findsAtLeastNWidgets(1));

      // Field input is retained after failure
      expect(find.text('Updated Name'), findsOneWidget);
    });
  });
}
