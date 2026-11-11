import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/admin/domain/models/admin_store_model.dart';
import 'package:esouq/features/admin/domain/models/admin_user_model.dart';
import 'package:esouq/features/admin/domain/repositories/admin_drivers_repository.dart';
import 'package:esouq/features/admin/domain/repositories/admin_stores_repository.dart';
import 'package:esouq/features/admin/domain/repositories/admin_users_repository.dart';
import 'package:esouq/features/admin/presentation/screens/admin_shell.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/auth/domain/repositories/auth_repository.dart';
import 'package:esouq/features/customer/application/points_notifier.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:esouq/features/customer/domain/models/store_model.dart';
import 'package:esouq/features/customer/domain/repositories/order_repository.dart';
import 'package:esouq/features/customer/presentation/screens/customer_shell.dart';
import 'package:esouq/features/customer/presentation/widgets/customer_points_badge.dart';
import 'package:esouq/features/rider/domain/models/rider_order_model.dart';
import 'package:esouq/features/rider/domain/repositories/rider_repository.dart';
import 'package:esouq/features/rider/presentation/screens/rider_shell.dart';
import 'package:esouq/features/store/domain/models/store_category_model.dart';
import 'package:esouq/features/store/domain/repositories/store_categories_repository.dart';
import 'package:esouq/features/store/domain/repositories/store_orders_repository.dart';
import 'package:esouq/features/store/domain/repositories/store_products_repository.dart';
import 'package:esouq/features/store/presentation/screens/store_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_cart_repository.dart';
import '../../mocks/mock_order_repository.dart';
import '../../mocks/mock_product_repository.dart';
import '../../mocks/mock_store_repository.dart';

// --- Fakes for non-customer roles ---

class FakeAuthRepo implements AuthRepository {
  final UserModel user;
  FakeAuthRepo(this.user);

  @override
  Future<Result<UserModel>> getCurrentUser() async => Result.success(user);
  @override
  Future<Result<void>> logout() async => Result.success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStoreOrdersRepo implements StoreOrdersRepository {
  @override
  Future<Result<List<OrderModel>>> getStoreOrders({
    required String storeId,
    String? status,
    int page = 1,
    int limit = 50,
  }) async => Result.success([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStoreProductsRepo implements StoreProductsRepository {
  @override
  Future<Result<List<ProductModel>>> getStoreProducts(String storeId) async =>
      Result.success([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStoreCategoriesRepo implements StoreCategoriesRepository {
  @override
  Future<Result<List<StoreCategoryModel>>> getCategories(
    String storeId,
  ) async => Result.success([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRiderRepo implements RiderRepository {
  @override
  Future<Result<List<RiderOrderModel>>> getAvailableOrders() async =>
      Result.success([]);
  @override
  Future<Result<RiderOrderModel?>> getActiveOrder() async =>
      Result.success(null);
  @override
  Future<Result<List<RiderOrderModel>>> getHistory() async =>
      Result.success([]);
  @override
  Future<Result<bool>> toggleAvailability(bool isOnline) async =>
      Result.success(true);
  @override
  Future<Result<Map<String, dynamic>>> getProfile() async =>
      Result.success({});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAdminStoresRepo implements AdminStoresRepository {
  @override
  Future<Result<List<AdminStoreModel>>> getStores() async =>
      Result.success([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAdminUsersRepo implements AdminUsersRepository {
  @override
  Future<Result<AdminUsersPage>> getUsers({
    int page = 1,
    int limit = 50,
    String? role,
  }) async =>
      Result.success(const AdminUsersPage(users: [], total: 0, page: 1, limit: 50));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAdminDriversRepo implements AdminDriversRepository {
  @override
  Future<Result<List<AdminUserModel>>> getDrivers({
    int page = 1,
    int limit = 50,
  }) async => Result.success([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Loyalty Points Role Isolation', () {
    testWidgets(
      'CUSTOMER role displays customer points badge in customer app shell',
      (tester) async {
        const customerUser = UserModel(
          id: 'cust-1',
          phoneNumber: '+966500000001',
          fullName: 'Customer One',
          role: UserRole.customer,
        );
        final mockAuthRepo = FakeAuthRepo(customerUser);
        final mockOrderRepo = MockOrderRepository();
        mockOrderRepo.ordersToReturn = [];
        mockOrderRepo.pointsInfoToReturn = const CustomerPointsInfo(
          isEnabled: true,
          balance: 250,
        );
        final pointsNotifier = PointsNotifier(
          orderRepository: mockOrderRepo,
          initialPointsInfo: const CustomerPointsInfo(
            isEnabled: true,
            balance: 250,
          ),
        );

        final testStore = const StoreModel(
          id: 'store-1',
          name: 'eSOuQ Olaya Flagship',
          area: 'Riyadh - Olaya',
          isActive: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: CustomerShell(
              authRepository: mockAuthRepo,
              orderRepository: mockOrderRepo,
              storeRepository: MockStoreRepository(),
              productRepository: MockProductRepository(),
              cartRepository: MockCartRepository(),
              pointsNotifier: pointsNotifier,
              initialSelectedStore: testStore,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CustomerPointsBadge), findsOneWidget);
        expect(find.byKey(const Key('customer_points_badge')), findsOneWidget);
        expect(find.text('250 pts'), findsOneWidget);

        pointsNotifier.dispose();
      },
    );

    testWidgets(
      'STORE STAFF role on StoreShell does NOT display customer points badge',
      (tester) async {
        const staffUser = UserModel(
          id: 'staff-1',
          phoneNumber: '+966511111111',
          fullName: 'Store Worker',
          role: UserRole.storeStaff,
          storeId: 'store-1',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: StoreShell(
              authRepository: FakeAuthRepo(staffUser),
              ordersRepository: FakeStoreOrdersRepo(),
              productsRepository: FakeStoreProductsRepo(),
              categoriesRepository: FakeStoreCategoriesRepo(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CustomerPointsBadge), findsNothing);
        expect(find.byKey(const Key('customer_points_badge')), findsNothing);
        expect(find.textContaining('pts'), findsNothing);
      },
    );

    testWidgets(
      'RIDER role on RiderShell does NOT display customer points badge',
      (tester) async {
        const riderUser = UserModel(
          id: 'rider-1',
          phoneNumber: '+966522222222',
          fullName: 'Delivery Driver',
          role: UserRole.deliveryRider,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: RiderShell(
              authRepository: FakeAuthRepo(riderUser),
              riderRepository: FakeRiderRepo(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CustomerPointsBadge), findsNothing);
        expect(find.byKey(const Key('customer_points_badge')), findsNothing);
        expect(find.textContaining('pts'), findsNothing);
      },
    );

    testWidgets(
      'ADMIN role on AdminShell does NOT display customer points badge',
      (tester) async {
        const adminUser = UserModel(
          id: 'admin-1',
          phoneNumber: '+966533333333',
          fullName: 'Super Admin',
          role: UserRole.superAdmin,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: AdminShell(
              authRepository: FakeAuthRepo(adminUser),
              storesRepository: FakeAdminStoresRepo(),
              usersRepository: FakeAdminUsersRepo(),
              driversRepository: FakeAdminDriversRepo(),
              ordersRepository: FakeStoreOrdersRepo(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CustomerPointsBadge), findsNothing);
        expect(find.byKey(const Key('customer_points_badge')), findsNothing);
        expect(find.textContaining('pts'), findsNothing);
      },
    );
  });
}
