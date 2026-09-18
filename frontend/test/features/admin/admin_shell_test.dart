import 'package:esouq/core/error/failures.dart';
import 'package:esouq/features/admin/domain/models/admin_area_model.dart';
import 'package:esouq/features/admin/domain/models/admin_store_model.dart';
import 'package:esouq/features/admin/domain/models/admin_user_model.dart';
import 'package:esouq/features/admin/domain/repositories/admin_drivers_repository.dart';
import 'package:esouq/features/admin/domain/repositories/admin_stores_repository.dart';
import 'package:esouq/features/admin/domain/repositories/admin_users_repository.dart';
import 'package:esouq/features/admin/presentation/screens/admin_shell.dart';
import 'package:esouq/features/auth/domain/models/auth_response_model.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  bool loggedOut = false;

  @override
  Future<void> logout() async {
    loggedOut = true;
  }

  @override
  Future<Result<UserModel?>> checkSession() async => Result.success(null);
  @override
  Future<Result<UserModel>> getCurrentUser() async => Result.success(
        const UserModel(id: 'admin-1', phoneNumber: '+966500000000', fullName: 'Admin', role: UserRole.superAdmin),
      );
  @override
  Future<Result<AuthResponseModel>> login({required String phoneNumber, required String password}) async =>
      Result.failure(const UnknownFailure(message: 'Not implemented in fake'));
  @override
  Future<Result<AuthResponseModel>> refreshToken() async =>
      Result.failure(const UnknownFailure(message: 'Not implemented in fake'));
  @override
  Future<Result<String>> requestAdminMagicLink({required String email}) async => Result.success('Link sent');
  @override
  Future<Result<String>> sendOtp({required String phone, String? email, String? name}) async => Result.success('Sent');
  @override
  Future<Result<AuthResponseModel>> signupCustomer({required String phoneNumber, required String fullName, required String password, String? address}) async =>
      Result.failure(const UnknownFailure(message: 'Not implemented in fake'));
  @override
  Future<Result<AuthResponseModel>> verifyAdminMagicLink({required String token}) async =>
      Result.failure(const UnknownFailure(message: 'Not implemented in fake'));
  @override
  Future<Result<AuthResponseModel>> verifyOtp({required String phone, required String code}) async =>
      Result.failure(const UnknownFailure(message: 'Not implemented in fake'));
  @override
  Future<Result<UserModel>> updateProfile({String? name, String? email}) async =>
      Result.failure(const UnknownFailure(message: 'Not implemented in fake'));
}

class FakeAdminUsersRepository implements AdminUsersRepository {
  @override
  Future<Result<AdminUsersPage>> getUsers({int page = 1, int limit = 50, String? role}) async {
    return Result.success(
      const AdminUsersPage(
        users: [
          AdminUserModel(id: 'u-1', name: 'Super Admin', role: UserRole.superAdmin, email: 'admin@esook.store'),
          AdminUserModel(id: 'u-2', name: 'Manager Riyadh', role: UserRole.storeManager, storeId: 'store-1'),
          AdminUserModel(id: 'u-3', name: 'Driver Mohammed', role: UserRole.deliveryRider, phone: '+966501234567'),
        ],
        total: 3,
        page: 1,
        limit: 50,
      ),
    );
  }
}

class FakeAdminDriversRepository implements AdminDriversRepository {
  @override
  Future<Result<List<AdminUserModel>>> getDrivers({int page = 1, int limit = 50}) async {
    return Result.success(
      const [
        AdminUserModel(id: 'd-1', name: 'Driver Mohammed', role: UserRole.deliveryRider, phone: '+966501234567'),
      ],
    );
  }

  @override
  Future<Result<AdminUserModel>> registerDriver({
    required String name,
    required String phone,
    required String password,
    String? storeId,
  }) async {
    return Result.success(
      AdminUserModel(id: 'd-2', name: name, role: UserRole.deliveryRider, phone: phone),
    );
  }
}

class FakeAdminStoresRepository implements AdminStoresRepository {
  @override
  Future<Result<List<AdminStoreModel>>> getStores() async {
    return Result.success(
      const [
        AdminStoreModel(id: 'store-1', name: 'Fresh Mart Riyadh', areaId: 'area-1', area: 'Riyadh', areaName: 'Riyadh'),
      ],
    );
  }

  @override
  Future<Result<List<AdminAreaModel>>> getAreas() async {
    return Result.success(
      const [
        AdminAreaModel(id: 'area-1', name: 'Riyadh'),
      ],
    );
  }

  @override
  Future<Result<AdminStoreModel>> createStore({
    required String name,
    String? areaId,
    String? area,
    String? address,
    String? phone,
    String? phoneNumber,
    bool? isActive,
  }) async {
    return Result.success(
      AdminStoreModel(id: 'store-2', name: name, areaId: areaId ?? 'area-1', area: area ?? 'Riyadh', address: address, phone: phone),
    );
  }

  @override
  Future<Result<AdminStoreModel>> updateStore({
    required String storeId,
    String? name,
    String? area,
    String? address,
    String? phone,
    String? phoneNumber,
    bool? isActive,
  }) async {
    return Result.success(
      AdminStoreModel(id: storeId, name: name ?? 'Store', areaId: 'area-1', area: area ?? 'Riyadh', isActive: isActive ?? true),
    );
  }
}

void main() {
  group('AdminShell Widget & Navigation Tests', () {
    late FakeAuthRepository authRepo;
    late FakeAdminUsersRepository usersRepo;
    late FakeAdminDriversRepository driversRepo;
    late FakeAdminStoresRepository storesRepo;

    setUp(() {
      authRepo = FakeAuthRepository();
      usersRepo = FakeAdminUsersRepository();
      driversRepo = FakeAdminDriversRepository();
      storesRepo = FakeAdminStoresRepository();
    });

    Widget createTestWidget({int initialIndex = 0}) {
      return MaterialApp(
        routes: {
          '/auth/login': (_) => const Scaffold(body: Text('Login Screen')),
        },
        home: AdminShell(
          initialIndex: initialIndex,
          authRepository: authRepo,
          usersRepository: usersRepo,
          driversRepository: driversRepo,
          storesRepository: storesRepo,
        ),
      );
    }

    testWidgets('renders AdminShell with Dashboard tab by default', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(find.text('System Overview'), findsOneWidget);
      expect(find.text('Stores'), findsWidgets);
      expect(find.text('Total Users'), findsOneWidget);
    });

    testWidgets('can switch navigation tabs to Stores, Users, Drivers, Orders', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Stores tab
      await tester.tap(find.byIcon(Icons.storefront_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Store Management'), findsOneWidget);
      expect(find.text('Fresh Mart Riyadh'), findsOneWidget);

      // Tap Users tab
      await tester.tap(find.byIcon(Icons.people_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('User Directory'), findsOneWidget);
      expect(find.text('Super Admin'), findsOneWidget);
      expect(find.text('Manager Riyadh'), findsOneWidget);

      // Tap Drivers tab
      await tester.tap(find.byIcon(Icons.delivery_dining_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Riders & Drivers'), findsOneWidget);
      expect(find.text('Driver Mohammed'), findsOneWidget);

      // Tap Orders tab
      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Orders Oversight'), findsOneWidget);
      expect(find.text('Orders Oversight Architecture'), findsOneWidget);
    });

    testWidgets('logout button invokes logout on AuthRepository', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin_logout_button')));
      await tester.pumpAndSettle();

      expect(authRepo.loggedOut, isTrue);
    });
  });
}
