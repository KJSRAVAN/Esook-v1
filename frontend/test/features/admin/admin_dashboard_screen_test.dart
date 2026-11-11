import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/admin/domain/models/admin_store_model.dart';
import 'package:esouq/features/admin/domain/models/admin_user_model.dart';
import 'package:esouq/features/admin/domain/repositories/admin_stores_repository.dart';
import 'package:esouq/features/admin/domain/repositories/admin_users_repository.dart';
import 'package:esouq/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAdminUsersRepository implements AdminUsersRepository {
  AdminUsersPage? usersPage;
  bool shouldFail = false;
  String errorMessage = 'Failed to load users';

  @override
  Future<Result<AdminUsersPage>> getUsers({
    int page = 1,
    int limit = 50,
    String? role,
  }) async {
    if (shouldFail) {
      return Result.failure(ServerFailure(message: errorMessage));
    }
    return Result.success(
      usersPage ??
          const AdminUsersPage(
            users: [],
            total: 0,
            page: 1,
            limit: 50,
          ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAdminStoresRepository implements AdminStoresRepository {
  List<AdminStoreModel> stores = [];
  bool shouldFail = false;
  String errorMessage = 'A database error occurred';

  @override
  Future<Result<List<AdminStoreModel>>> getStores() async {
    if (shouldFail) {
      return Result.failure(ServerFailure(message: errorMessage));
    }
    return Result.success(stores);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeAdminUsersRepository fakeUsersRepo;
  late FakeAdminStoresRepository fakeStoresRepo;

  setUp(() {
    fakeUsersRepo = FakeAdminUsersRepository();
    fakeStoresRepo = FakeAdminStoresRepository();
  });

  Widget createWidget() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: AdminDashboardScreen(
        usersRepository: fakeUsersRepo,
        storesRepository: fakeStoresRepo,
      ),
    );
  }

  final testUsers = [
    const AdminUserModel(
      id: 'u-1',
      name: 'Customer One',
      role: UserRole.customer,
    ),
    const AdminUserModel(
      id: 'u-2',
      name: 'Staff One',
      role: UserRole.storeStaff,
    ),
    const AdminUserModel(
      id: 'u-3',
      name: 'Rider One',
      role: UserRole.deliveryRider,
    ),
  ];

  final testStores = [
    const AdminStoreModel(
      id: 's-1',
      name: 'Store Riyadh',
      area: 'area-1',
      isActive: true,
    ),
    const AdminStoreModel(
      id: 's-2',
      name: 'Store Jeddah',
      area: 'area-2',
      isActive: false,
    ),
  ];

  group('AdminDashboardScreen - Migration 7 Resilience', () {
    testWidgets('renders all stat cards when both users and stores succeed', (tester) async {
      fakeUsersRepo.usersPage = AdminUsersPage(
        users: testUsers,
        total: 3,
        page: 1,
        limit: 100,
      );
      fakeStoresRepo.stores = testStores;

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('System Overview'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_warning_banner')), findsNothing);
      expect(find.text('Stores'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 stores
      expect(find.text('1 Active'), findsOneWidget); // 1 active
      expect(find.text('Total Users'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // 3 total users
    });

    testWidgets('renders partial dashboard with warning banner when stores fail but users succeed (Migration 7 case)', (tester) async {
      fakeUsersRepo.usersPage = AdminUsersPage(
        users: testUsers,
        total: 3,
        page: 1,
        limit: 100,
      );
      fakeStoresRepo.shouldFail = true;
      fakeStoresRepo.errorMessage = 'A database error occurred';

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Does NOT show full-screen error
      expect(find.text('Dashboard Error'), findsNothing);
      expect(find.byKey(const Key('dashboard_retry_button')), findsNothing);

      // Shows live overview and partial warning banner
      expect(find.text('System Overview'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_warning_banner')), findsOneWidget);
      expect(
        find.textContaining('Store statistics unavailable: A database error occurred. User metrics are live.'),
        findsOneWidget,
      );

      // Stores stat card shows graceful fallback
      expect(find.text('--'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);

      // Users stats remain live and accurate
      expect(find.text('Total Users'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1 Customers'), findsOneWidget);
      expect(find.text('1 Customers'), findsOneWidget);
    });

    testWidgets('shows full-screen error when both users and stores fail', (tester) async {
      fakeUsersRepo.shouldFail = true;
      fakeUsersRepo.errorMessage = 'Database down';
      fakeStoresRepo.shouldFail = true;
      fakeStoresRepo.errorMessage = 'Database down';

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Error'), findsOneWidget);
      expect(find.text('Database down'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_retry_button')), findsOneWidget);
      expect(find.text('System Overview'), findsNothing);
    });
  });
}
