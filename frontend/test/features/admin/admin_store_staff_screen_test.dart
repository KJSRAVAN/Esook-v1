import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/admin/domain/models/admin_store_model.dart';
import 'package:esouq/features/admin/domain/models/admin_user_model.dart';
import 'package:esouq/features/admin/domain/repositories/admin_users_repository.dart';
import 'package:esouq/features/admin/presentation/screens/admin_store_staff_screen.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';

class MockAdminUsersRepository implements AdminUsersRepository {
  List<AdminUserModel> usersToReturn = [];
  AppFailure? failureToReturn;

  AdminUserModel? createdUserToReturn;
  AppFailure? createFailureToReturn;

  AdminUserModel? updatedUserToReturn;
  AppFailure? updateFailureToReturn;

  AppFailure? deleteFailureToReturn;

  int getUsersCallCount = 0;
  int createStaffCallCount = 0;
  int updateStaffCallCount = 0;
  int deleteStaffCallCount = 0;

  String? lastStoreId;
  String? lastName;
  String? lastEmail;
  String? lastPhone;
  String? lastRole;
  String? lastPassword;

  String? lastUpdatedUserId;
  String? lastUpdatedName;
  String? lastUpdatedEmail;
  String? lastUpdatedRole;
  bool? lastUpdatedIsActive;
  String? lastUpdatedPassword;

  String? lastDeletedUserId;

  @override
  Future<Result<AdminUsersPage>> getUsers({
    int page = 1,
    int limit = 50,
    String? role,
  }) async {
    getUsersCallCount++;
    if (failureToReturn != null) {
      return Result.failure(failureToReturn!);
    }
    return Result.success(
      AdminUsersPage(
        users: usersToReturn,
        total: usersToReturn.length,
        page: page,
        limit: limit,
      ),
    );
  }

  @override
  Future<Result<AdminUserModel>> createStaffAccount({
    required String storeId,
    required String name,
    required String email,
    String? phone,
    required String role,
    required String password,
  }) async {
    createStaffCallCount++;
    lastStoreId = storeId;
    lastName = name;
    lastEmail = email;
    lastPhone = phone;
    lastRole = role;
    lastPassword = password;

    if (createFailureToReturn != null) {
      return Result.failure(createFailureToReturn!);
    }

    final created = createdUserToReturn ??
        AdminUserModel(
          id: 'staff-created',
          name: name,
          email: email,
          phone: phone,
          role: role == 'MANAGER' ? UserRole.storeManager : UserRole.storeStaff,
          storeId: storeId,
          isActive: true,
        );

    // Add to usersToReturn so subsequent list refresh sees it
    usersToReturn.add(created);

    return Result.success(created);
  }

  @override
  Future<Result<AdminUserModel>> updateStaffAccount({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? password,
    String? role,
    String? storeId,
    bool? isActive,
  }) async {
    updateStaffCallCount++;
    lastUpdatedUserId = userId;
    lastUpdatedName = name;
    lastUpdatedEmail = email;
    lastUpdatedRole = role;
    lastUpdatedIsActive = isActive;
    lastUpdatedPassword = password;

    if (updateFailureToReturn != null) {
      return Result.failure(updateFailureToReturn!);
    }

    final index = usersToReturn.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final existing = usersToReturn[index];
      final updated = existing.copyWith(
        name: name,
        email: email,
        phone: phone,
        role: role != null
            ? (role == 'MANAGER' ? UserRole.storeManager : UserRole.storeStaff)
            : existing.role,
        isActive: isActive,
      );
      usersToReturn[index] = updated;
      return Result.success(updated);
    }

    return Result.success(
      updatedUserToReturn ??
          AdminUserModel(
            id: userId,
            name: name ?? 'Updated Staff',
            email: email,
            role: role == 'MANAGER'
                ? UserRole.storeManager
                : UserRole.storeStaff,
            isActive: isActive ?? true,
          ),
    );
  }

  @override
  Future<Result<void>> deleteStaffAccount(String userId) async {
    deleteStaffCallCount++;
    lastDeletedUserId = userId;

    if (deleteFailureToReturn != null) {
      return Result.failure(deleteFailureToReturn!);
    }

    usersToReturn.removeWhere((u) => u.id == userId);
    return Result.success(null);
  }
}

void main() {
  late MockAdminUsersRepository mockUsersRepo;
  const testStore = AdminStoreModel(
    id: 'store-1',
    name: 'eSOuQ Olaya Supermarket',
    areaId: 'area-1',
    areaName: 'Olaya, Riyadh',
    address: 'King Fahd Rd, Olaya',
    phone: '+966112345678',
    isActive: true,
  );

  setUp(() {
    mockUsersRepo = MockAdminUsersRepository();
  });

  Widget buildScreen() {
    return MaterialApp(
      home: AdminStoreStaffScreen(
        store: testStore,
        usersRepository: mockUsersRepo,
      ),
    );
  }

  group('AdminStoreStaffScreen', () {
    testWidgets('renders store header and summary chips', (tester) async {
      mockUsersRepo.usersToReturn = [];

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Store Staff'), findsOneWidget);
      expect(find.text('eSOuQ Olaya Supermarket'), findsWidgets);
      expect(find.text('0 Mgr'), findsOneWidget);
      expect(find.text('0 Staff'), findsOneWidget);
      expect(find.byKey(const Key('add_staff_member_fab')), findsOneWidget);
    });

    testWidgets('displays assigned staff and filters out staff from other stores', (tester) async {
      mockUsersRepo.usersToReturn = [
        const AdminUserModel(
          id: 'u-1',
          name: 'Tariq Al-Harbi',
          email: 'tariq@esook.store',
          phone: '+966501111111',
          role: UserRole.storeStaff,
          storeId: 'store-1', // Matches testStore
          isActive: true,
        ),
        const AdminUserModel(
          id: 'u-2',
          name: 'Sarah Manager',
          email: 'sarah@esook.store',
          phone: '+966502222222',
          role: UserRole.storeManager,
          storeId: 'store-1', // Matches testStore
          isActive: true,
        ),
        const AdminUserModel(
          id: 'u-3',
          name: 'Other Store Staff',
          email: 'other@esook.store',
          phone: '+966503333333',
          role: UserRole.storeStaff,
          storeId: 'store-2', // Different store!
          isActive: true,
        ),
      ];

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Only staff from store-1 should be shown
      expect(find.text('Tariq Al-Harbi'), findsOneWidget);
      expect(find.text('Sarah Manager'), findsOneWidget);
      expect(find.text('Other Store Staff'), findsNothing);

      // Verify role labels
      expect(find.text('Store Staff'), findsWidgets);
      expect(find.text('Manager'), findsOneWidget);

      // Header chips
      expect(find.text('1 Mgr'), findsOneWidget);
      expect(find.text('1 Staff'), findsOneWidget);
    });

    testWidgets('shows empty state when no staff assigned to store', (tester) async {
      mockUsersRepo.usersToReturn = [];

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('No Staff Assigned'), findsOneWidget);
      expect(
        find.text('No staff or manager accounts are currently associated with "eSOuQ Olaya Supermarket".'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('empty_add_staff_btn')), findsOneWidget);
    });

    testWidgets('opens Add Staff Dialog, validates form, and creates account via POST /users/staff', (tester) async {
      mockUsersRepo.usersToReturn = [];

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_staff_member_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_staff_dialog')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('add_staff_dialog')),
          matching: find.text('Add Staff Member'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('staff_name_input')), findsOneWidget);
      expect(find.byKey(const Key('staff_email_input')), findsOneWidget);
      expect(find.byKey(const Key('staff_phone_input')), findsOneWidget);
      expect(find.byKey(const Key('staff_role_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('staff_password_input')), findsOneWidget);

      // Attempt submit without filling inputs
      await tester.ensureVisible(find.byKey(const Key('staff_submit_btn')));
      await tester.tap(find.byKey(const Key('staff_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter staff full name'), findsOneWidget);
      expect(mockUsersRepo.createStaffCallCount, 0);

      // Fill valid values
      await tester.enterText(find.byKey(const Key('staff_name_input')), 'Fahad Staff');
      await tester.enterText(find.byKey(const Key('staff_email_input')), 'fahad@esook.store');
      await tester.enterText(find.byKey(const Key('staff_phone_input')), '+966509876543');
      await tester.enterText(find.byKey(const Key('staff_password_input')), 'SecurePass123');

      await tester.ensureVisible(find.byKey(const Key('staff_submit_btn')));
      await tester.tap(find.byKey(const Key('staff_submit_btn')));
      await tester.pumpAndSettle();

      expect(mockUsersRepo.createStaffCallCount, 1);
      expect(mockUsersRepo.lastStoreId, 'store-1');
      expect(mockUsersRepo.lastName, 'Fahad Staff');
      expect(mockUsersRepo.lastEmail, 'fahad@esook.store');
      expect(mockUsersRepo.lastPhone, '+966509876543');
      expect(mockUsersRepo.lastRole, 'STAFF');

      // Verify list refreshed and created staff appears
      expect(find.text('Fahad Staff'), findsOneWidget);
      expect(find.text('Staff account created successfully.'), findsOneWidget);
    });

    testWidgets('handles duplicate account creation failure gracefully', (tester) async {
      mockUsersRepo.usersToReturn = [];
      mockUsersRepo.createFailureToReturn = const ConflictFailure(
        message: 'An account with this email or phone number already exists.',
        statusCode: 409,
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_staff_member_fab')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('staff_name_input')), 'Existing Staff');
      await tester.enterText(find.byKey(const Key('staff_email_input')), 'existing@esook.store');
      await tester.enterText(find.byKey(const Key('staff_password_input')), 'Password123');

      await tester.ensureVisible(find.byKey(const Key('staff_submit_btn')));
      await tester.tap(find.byKey(const Key('staff_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff_dialog_error_banner')), findsOneWidget);
      expect(
        find.textContaining('already exists'),
        findsOneWidget,
      );
    });

    testWidgets('edits staff account via PATCH /users/staff/:userId with only changed fields', (tester) async {
      mockUsersRepo.usersToReturn = [
        const AdminUserModel(
          id: 'u-edit-1',
          name: 'Original Name',
          email: 'orig@esook.store',
          phone: '+966501111111',
          role: UserRole.storeStaff,
          storeId: 'store-1',
          isActive: true,
        ),
      ];

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Original Name'), findsOneWidget);

      // Tap Edit button
      await tester.tap(find.byKey(const Key('edit_staff_btn_u-edit-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_staff_dialog')), findsOneWidget);
      expect(find.text('Edit Staff Account'), findsOneWidget);

      // Change name
      await tester.enterText(find.byKey(const Key('edit_staff_name_input')), 'Promoted Manager');

      // Change role to MANAGER
      await tester.ensureVisible(find.byKey(const Key('edit_staff_role_dropdown')));
      await tester.tap(find.byKey(const Key('edit_staff_role_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Store Manager').last);
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.byKey(const Key('edit_staff_submit_btn')));
      await tester.tap(find.byKey(const Key('edit_staff_submit_btn')));
      await tester.pumpAndSettle();

      expect(mockUsersRepo.updateStaffCallCount, 1);
      expect(mockUsersRepo.lastUpdatedUserId, 'u-edit-1');
      expect(mockUsersRepo.lastUpdatedName, 'Promoted Manager');
      expect(mockUsersRepo.lastUpdatedRole, 'MANAGER');
      expect(mockUsersRepo.lastUpdatedEmail, isNull); // Email didn't change
      expect(mockUsersRepo.lastUpdatedPassword, isNull); // Password not updated

      expect(find.text('Staff account updated successfully.'), findsOneWidget);
      expect(find.text('Promoted Manager'), findsOneWidget);
    });

    testWidgets('toggles staff active status with confirmation dialog', (tester) async {
      mockUsersRepo.usersToReturn = [
        const AdminUserModel(
          id: 'u-toggle-1',
          name: 'Active Staff',
          email: 'active@esook.store',
          role: UserRole.storeStaff,
          storeId: 'store-1',
          isActive: true,
        ),
      ];

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsWidgets);

      // Tap active toggle badge
      await tester.tap(find.byKey(const Key('toggle_active_btn_u-toggle-1')));
      await tester.pumpAndSettle();

      expect(find.text('Deactivate Staff Account?'), findsOneWidget);

      // Confirm deactivation
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();

      expect(mockUsersRepo.updateStaffCallCount, 1);
      expect(mockUsersRepo.lastUpdatedUserId, 'u-toggle-1');
      expect(mockUsersRepo.lastUpdatedIsActive, isFalse);

      expect(find.text('Disabled'), findsWidgets);
    });

    testWidgets('permanently deletes staff account after confirmation and refreshes list', (tester) async {
      mockUsersRepo.usersToReturn = [
        const AdminUserModel(
          id: 'u-del-1',
          name: 'Staff To Delete',
          email: 'delete@esook.store',
          role: UserRole.storeStaff,
          storeId: 'store-1',
          isActive: true,
        ),
      ];

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Staff To Delete'), findsOneWidget);

      // Tap delete button
      await tester.tap(find.byKey(const Key('delete_staff_btn_u-del-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirm_delete_staff_dialog')), findsOneWidget);
      expect(find.text('Delete Staff Account'), findsOneWidget);

      // Cancel first
      await tester.tap(find.byKey(const Key('cancel_delete_staff_btn')));
      await tester.pumpAndSettle();

      expect(mockUsersRepo.deleteStaffCallCount, 0);
      expect(find.text('Staff To Delete'), findsOneWidget);

      // Tap delete again and confirm
      await tester.tap(find.byKey(const Key('delete_staff_btn_u-del-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_delete_staff_btn')));
      await tester.pumpAndSettle();

      expect(mockUsersRepo.deleteStaffCallCount, 1);
      expect(mockUsersRepo.lastDeletedUserId, 'u-del-1');

      expect(find.text('Staff member "Staff To Delete" deleted permanently.'), findsOneWidget);
      expect(find.text('No Staff Assigned'), findsOneWidget);
    });

    testWidgets('handles delete failure without prematurely removing staff member', (tester) async {
      mockUsersRepo.usersToReturn = [
        const AdminUserModel(
          id: 'u-fail-1',
          name: 'Staff Fail Delete',
          email: 'fail@esook.store',
          role: UserRole.storeStaff,
          storeId: 'store-1',
          isActive: true,
        ),
      ];
      mockUsersRepo.deleteFailureToReturn = const ServerFailure(
        message: 'Internal server error deleting user',
        statusCode: 500,
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_staff_btn_u-fail-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_delete_staff_btn')));
      await tester.pumpAndSettle();

      expect(mockUsersRepo.deleteStaffCallCount, 1);
      expect(find.text('Internal server error deleting user'), findsOneWidget);
      // Staff member is still present!
      expect(find.text('Staff Fail Delete'), findsOneWidget);
    });
  });
}
