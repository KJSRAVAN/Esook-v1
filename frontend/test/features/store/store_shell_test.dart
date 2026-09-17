import 'package:esouq/core/error/failures.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/auth/domain/repositories/auth_repository.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:esouq/features/store/domain/models/store_category_model.dart';
import 'package:esouq/features/store/domain/repositories/store_categories_repository.dart';
import 'package:esouq/features/store/domain/repositories/store_orders_repository.dart';
import 'package:esouq/features/store/domain/repositories/store_products_repository.dart';
import 'package:esouq/features/store/presentation/screens/store_assignment_required_screen.dart';
import 'package:esouq/features/store/presentation/screens/store_dashboard_screen.dart';
import 'package:esouq/features/store/presentation/screens/store_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  bool logoutCalled = false;
  UserModel? currentUser;

  @override
  Future<Result<UserModel>> getCurrentUser() async {
    if (currentUser != null) return Result.success(currentUser!);
    return Result.failure(const UnknownFailure(message: 'Not logged in'));
  }

  @override
  Future<Result<void>> logout() async {
    logoutCalled = true;
    return Result.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStoreOrdersRepository implements StoreOrdersRepository {
  List<OrderModel> orders = [];

  @override
  Future<Result<List<OrderModel>>> getStoreOrders({
    required String storeId,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    return Result.success(orders);
  }

  @override
  Future<Result<OrderModel>> getOrderById(String orderId) async {
    return Result.success(orders.firstWhere((o) => o.id == orderId));
  }

  @override
  Future<Result<OrderModel>> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    String? rejectedReason,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = orders[idx].copyWith(status: status);
      orders[idx] = updated;
      return Result.success(updated);
    }
    return Result.failure(const UnknownFailure(message: 'Order not found'));
  }
}

class FakeStoreProductsRepository implements StoreProductsRepository {
  List<ProductModel> products = [];
  bool deleteCalled = false;

  @override
  Future<Result<List<ProductModel>>> getStoreProducts(String storeId) async {
    return Result.success(products);
  }

  @override
  Future<Result<ProductModel>> createProduct({
    required String storeId,
    required String name,
    String? description,
    required double price,
    String? categoryId,
    String? imageUrl,
    int? sortOrder,
  }) async {
    final newProd = ProductModel(
      id: 'prod-${products.length + 1}',
      storeId: storeId,
      name: name,
      price: price,
      categoryId: categoryId,
      description: description,
    );
    products.add(newProd);
    return Result.success(newProd);
  }

  @override
  Future<Result<ProductModel>> updateProduct({
    required String storeId,
    required String productId,
    String? name,
    String? description,
    double? price,
    String? categoryId,
    String? imageUrl,
    int? sortOrder,
    bool? isAvailable,
  }) async {
    final idx = products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final existing = products[idx];
      final updated = ProductModel(
        id: existing.id,
        storeId: existing.storeId,
        name: name ?? existing.name,
        price: price ?? existing.price,
        description: description ?? existing.description,
        categoryId: categoryId ?? existing.categoryId,
        imageUrl: imageUrl ?? existing.imageUrl,
        sortOrder: sortOrder ?? existing.sortOrder,
        isAvailable: isAvailable ?? existing.isAvailable,
      );
      products[idx] = updated;
      return Result.success(updated);
    }
    return Result.failure(const UnknownFailure(message: 'Product not found'));
  }

  @override
  Future<Result<ProductModel>> toggleAvailability({
    required String storeId,
    required String productId,
    required bool isAvailable,
  }) async {
    return updateProduct(
      storeId: storeId,
      productId: productId,
      isAvailable: isAvailable,
    );
  }

  @override
  Future<Result<void>> deleteProduct({
    required String storeId,
    required String productId,
  }) async {
    deleteCalled = true;
    products.removeWhere((p) => p.id == productId);
    return Result.success(null);
  }
}

class FakeStoreCategoriesRepository implements StoreCategoriesRepository {
  List<StoreCategoryModel> categories = [];

  @override
  Future<Result<List<StoreCategoryModel>>> getCategories(String storeId) async {
    return Result.success(categories);
  }

  @override
  Future<Result<StoreCategoryModel>> createCategory({
    required String storeId,
    required String name,
    int? sortOrder,
  }) async {
    final cat = StoreCategoryModel(
      id: 'cat-${categories.length + 1}',
      storeId: storeId,
      name: name,
      sortOrder: sortOrder ?? 0,
    );
    categories.add(cat);
    return Result.success(cat);
  }
}

void main() {
  group('StoreShell Widget & Navigation Tests', () {
    late FakeAuthRepository authRepo;
    late FakeStoreOrdersRepository ordersRepo;
    late FakeStoreProductsRepository productsRepo;
    late FakeStoreCategoriesRepository categoriesRepo;

    const staffUser = UserModel(
      id: 'staff-1',
      phoneNumber: '+966501234567',
      fullName: 'Store Staff Member',
      role: UserRole.storeStaff,
      storeId: 'store-101',
    );

    const managerUser = UserModel(
      id: 'manager-1',
      phoneNumber: '+966509876543',
      fullName: 'Store General Manager',
      role: UserRole.storeManager,
      storeId: 'store-101',
    );

    const unassignedUser = UserModel(
      id: 'staff-2',
      phoneNumber: '+966501112233',
      fullName: 'Unassigned Staff',
      role: UserRole.storeStaff,
      storeId: null,
    );

    setUp(() {
      authRepo = FakeAuthRepository();
      ordersRepo = FakeStoreOrdersRepository();
      productsRepo = FakeStoreProductsRepository();
      categoriesRepo = FakeStoreCategoriesRepository();

      productsRepo.products = [
        const ProductModel(
          id: 'prod-1',
          storeId: 'store-101',
          name: 'Organic Milk 1L',
          price: 12.00,
          isAvailable: true,
        ),
      ];

      ordersRepo.orders = [
        const OrderModel(
          id: 'ord-1',
          orderNumber: 'ESK-001',
          customerId: 'cust-1',
          storeId: 'store-101',
          status: OrderStatus.pending,
          fulfillment: FulfillmentType.delivery,
          subtotal: 12.00,
          total: 12.00,
        ),
      ];
    });

    Widget createTestWidget({required UserModel user}) {
      authRepo.currentUser = user;
      return MaterialApp(
        routes: {
          '/auth/login': (_) => const Scaffold(body: Text('Login Screen')),
        },
        home: StoreShell(
          initialUser: user,
          authRepository: authRepo,
          ordersRepository: ordersRepo,
          productsRepository: productsRepo,
          categoriesRepository: categoriesRepo,
        ),
      );
    }

    testWidgets('renders StoreDashboardScreen by default for staff', (tester) async {
      await tester.pumpWidget(createTestWidget(user: staffUser));
      await tester.pumpAndSettle();

      expect(find.byType(StoreDashboardScreen), findsOneWidget);
      expect(find.text('Store Operations'), findsOneWidget);
      expect(find.text('Order Pipeline'), findsOneWidget);
    });

    testWidgets('unassigned store user displays StoreAssignmentRequiredScreen', (tester) async {
      await tester.pumpWidget(createTestWidget(user: unassignedUser));
      await tester.pumpAndSettle();

      expect(find.byType(StoreAssignmentRequiredScreen), findsOneWidget);
      expect(find.text('Store Assignment Required'), findsOneWidget);
    });

    testWidgets('navigation switches between Dashboard, Orders, Products, Categories, Account', (tester) async {
      await tester.pumpWidget(createTestWidget(user: staffUser));
      await tester.pumpAndSettle();

      // Navigate to Orders tab
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      expect(find.text('Store Orders'), findsOneWidget);

      // Navigate to Products tab
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.text('Store Products'), findsOneWidget);

      // Navigate to Categories tab
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      expect(find.text('Store Categories'), findsOneWidget);

      // Navigate to Account tab
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Staff Account'), findsOneWidget);
      expect(find.text('Store Staff Member'), findsOneWidget);
    });

    testWidgets('Staff user CANNOT see add product, edit product, or add category FABs', (tester) async {
      await tester.pumpWidget(createTestWidget(user: staffUser));
      await tester.pumpAndSettle();

      // Go to Products
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_add_product_fab')), findsNothing);
      expect(find.byKey(const Key('product_edit_btn_prod-1')), findsNothing);
      expect(find.byKey(const Key('product_toggle_prod-1')), findsNothing);

      // Go to Categories
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_add_category_fab')), findsNothing);
    });

    testWidgets('Manager user CAN see add product, edit product, toggle availability, add category', (tester) async {
      await tester.pumpWidget(createTestWidget(user: managerUser));
      await tester.pumpAndSettle();

      // Go to Products
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_add_product_fab')), findsOneWidget);
      expect(find.byKey(const Key('product_edit_btn_prod-1')), findsOneWidget);
      expect(find.byKey(const Key('product_toggle_prod-1')), findsOneWidget);

      // Verify delete product button does not exist for Manager
      expect(find.byKey(const Key('product_delete_btn_prod-1')), findsNothing);

      // Go to Categories
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_add_category_fab')), findsOneWidget);
    });

    testWidgets('Account screen sign out button calls auth logout', (tester) async {
      await tester.pumpWidget(createTestWidget(user: staffUser));
      await tester.pumpAndSettle();

      // Go to Account
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();

      // Tap Sign out button
      await tester.tap(find.byKey(const Key('store_account_signout_btn')));
      await tester.pumpAndSettle();

      // Confirm dialog
      await tester.tap(find.byKey(const Key('store_account_confirm_signout_btn')));
      await tester.pumpAndSettle();

      expect(authRepo.logoutCalled, isTrue);
    });
  });
}
