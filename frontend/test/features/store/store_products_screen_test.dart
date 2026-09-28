import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/auth/domain/repositories/auth_repository.dart';
import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:esouq/features/store/domain/models/store_category_model.dart';
import 'package:esouq/features/store/domain/repositories/store_categories_repository.dart';
import 'package:esouq/features/store/domain/repositories/store_orders_repository.dart';
import 'package:esouq/features/store/domain/repositories/store_products_repository.dart';
import 'package:esouq/features/store/presentation/screens/store_products_screen.dart';
import 'package:esouq/features/store/presentation/widgets/store_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockStoreProductsRepository implements StoreProductsRepository {
  List<ProductModel> products = [
    const ProductModel(
      id: 'p-1',
      name: 'Fresh Apples 1kg',
      price: 8.50,
      category: 'Produce',
      description: 'Crisp local apples',
      isAvailable: true,
      storeId: 'store-1',
    ),
    const ProductModel(
      id: 'p-2',
      name: 'White Bread',
      price: 4.00,
      category: 'Bakery',
      description: 'Sliced sandwich bread',
      isAvailable: false,
      storeId: 'store-1',
    ),
  ];

  String? lastToggledId;
  bool? lastToggledValue;

  @override
  Future<Result<List<ProductModel>>> getStoreProducts(String storeId) async {
    return Result.success(List.from(products));
  }

  @override
  Future<Result<ProductModel>> createProduct({
    required String storeId,
    required String name,
    String? description,
    required double price,
    String? categoryId,
    String? category,
    String? imageUrl,
    int? sortOrder,
  }) async {
    final created = ProductModel(
      id: 'p-${products.length + 1}',
      name: name,
      price: price,
      description: description,
      category: category,
      imageUrl: imageUrl,
      isAvailable: true,
      storeId: storeId,
    );
    products.insert(0, created);
    return Result.success(created);
  }

  @override
  Future<Result<ProductModel>> updateProduct({
    required String storeId,
    required String productId,
    String? name,
    String? description,
    double? price,
    String? categoryId,
    String? category,
    String? imageUrl,
    int? sortOrder,
    bool? isAvailable,
  }) async {
    final idx = products.indexWhere((p) => p.id == productId);
    if (idx >= 0) {
      final existing = products[idx];
      final updated = ProductModel(
        id: existing.id,
        name: name ?? existing.name,
        price: price ?? existing.price,
        description: description ?? existing.description,
        category: category ?? existing.category,
        imageUrl: imageUrl ?? existing.imageUrl,
        isAvailable: isAvailable ?? existing.isAvailable,
        storeId: existing.storeId,
      );
      products[idx] = updated;
      return Result.success(updated);
    }
    return Result.failure(const ServerFailure(message: 'Product not found'));
  }

  @override
  Future<Result<ProductModel>> toggleAvailability({
    required String storeId,
    required String productId,
    required bool isAvailable,
  }) async {
    lastToggledId = productId;
    lastToggledValue = isAvailable;
    final idx = products.indexWhere((p) => p.id == productId);
    if (idx >= 0) {
      final updated = ProductModel(
        id: products[idx].id,
        name: products[idx].name,
        price: products[idx].price,
        category: products[idx].category,
        description: products[idx].description,
        imageUrl: products[idx].imageUrl,
        isAvailable: isAvailable,
        storeId: storeId,
      );
      products[idx] = updated;
      return Result.success(updated);
    }
    return Result.failure(const ServerFailure(message: 'Product not found'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStoreCategoriesRepository implements StoreCategoriesRepository {
  @override
  Future<Result<List<StoreCategoryModel>>> getCategories(String storeId) async {
    return Result.success(const [
      StoreCategoryModel(id: 'Produce', name: 'Produce', storeId: 'store-1'),
      StoreCategoryModel(id: 'Bakery', name: 'Bakery', storeId: 'store-1'),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStoreOrdersRepository implements StoreOrdersRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockStoreProductsRepository productsRepo;
  late MockStoreCategoriesRepository categoriesRepo;
  late MockStoreOrdersRepository ordersRepo;
  late MockAuthRepository authRepo;

  setUp(() {
    productsRepo = MockStoreProductsRepository();
    categoriesRepo = MockStoreCategoriesRepository();
    ordersRepo = MockStoreOrdersRepository();
    authRepo = MockAuthRepository();
  });

  Widget buildScreenForUser({required UserRole role, String storeId = 'store-1'}) {
    final user = UserModel(
      id: 'user-1',
      fullName: 'Sara Staff',
      phoneNumber: '+966551234567',
      role: role,
      storeId: storeId,
    );

    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: StoreScope(
        ordersRepository: ordersRepo,
        productsRepository: productsRepo,
        categoriesRepository: categoriesRepo,
        authRepository: authRepo,
        currentUser: user,
        storeId: storeId,
        child: const StoreProductsScreen(),
      ),
    );
  }

  testWidgets('Store STAFF can see Add Product FAB and individual product action controls', (tester) async {
    await tester.pumpWidget(buildScreenForUser(role: UserRole.storeStaff));
    await tester.pumpAndSettle();

    // Staff sees products list
    expect(find.text('Fresh Apples 1kg'), findsOneWidget);
    expect(find.text('White Bread'), findsOneWidget);

    // Staff sees Add Product FAB
    expect(find.byKey(const Key('store_add_product_fab')), findsOneWidget);

    // Staff sees individual product edit buttons and availability toggle switches
    expect(find.byKey(const Key('product_edit_btn_p-1')), findsOneWidget);
    expect(find.byKey(const Key('product_toggle_p-1')), findsOneWidget);
    expect(find.byKey(const Key('product_edit_btn_p-2')), findsOneWidget);
    expect(find.byKey(const Key('product_toggle_p-2')), findsOneWidget);

    // Super Admin-only CSV bulk import must NOT be present on store products screen
    expect(find.byKey(const Key('admin_catalog_csv_import_btn')), findsNothing);
    expect(find.text('Bulk Import Products (CSV)'), findsNothing);
  });

  testWidgets('Store STAFF can toggle availability on a product', (tester) async {
    await tester.pumpWidget(buildScreenForUser(role: UserRole.storeStaff));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('product_toggle_p-1'));
    expect(toggle, findsOneWidget);

    // Tap toggle switch for p-1
    await tester.tap(toggle);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(productsRepo.lastToggledId, 'p-1');
    expect(productsRepo.lastToggledValue, isFalse);
    expect(find.text('Fresh Apples 1kg is now Unavailable'), findsOneWidget);
  });

  testWidgets('Store STAFF can open CreateProductDialog and add a single product', (tester) async {
    await tester.pumpWidget(buildScreenForUser(role: UserRole.storeStaff));
    await tester.pumpAndSettle();

    // Tap Add Product FAB
    await tester.tap(find.byKey(const Key('store_add_product_fab')));
    await tester.pumpAndSettle();

    // CreateProductDialog opens
    expect(find.text('Add Store Item'), findsOneWidget);

    // Fill product details
    await tester.enterText(find.byKey(const Key('create_product_name_input')), 'Greek Yogurt 500g');
    await tester.enterText(find.byKey(const Key('create_product_price_input')), '7.50');

    // Submit
    await tester.ensureVisible(find.byKey(const Key('create_product_submit_btn')));
    await tester.tap(find.byKey(const Key('create_product_submit_btn')));
    await tester.pumpAndSettle();

    // Dialog pops and product list is updated with Greek Yogurt
    expect(find.text('Greek Yogurt 500g'), findsOneWidget);
    expect(find.text('Greek Yogurt 500g created successfully'), findsOneWidget);
  });

  testWidgets('Store STAFF can open EditProductDialog and edit an existing product', (tester) async {
    await tester.pumpWidget(buildScreenForUser(role: UserRole.storeStaff));
    await tester.pumpAndSettle();

    // Tap edit button on p-1
    await tester.tap(find.byKey(const Key('product_edit_btn_p-1')));
    await tester.pumpAndSettle();

    // EditProductDialog opens
    expect(find.text('Edit Store Item'), findsOneWidget);

    // Edit price
    await tester.enterText(find.byKey(const Key('edit_product_price_input')), '9.25');

    // Submit edit
    await tester.ensureVisible(find.byKey(const Key('edit_product_submit_btn')));
    await tester.tap(find.byKey(const Key('edit_product_submit_btn')));
    await tester.pumpAndSettle();

    // Dialog pops and updated price is displayed
    expect(find.text('Fresh Apples 1kg updated successfully'), findsOneWidget);
    expect(find.text('9.25 AED'), findsOneWidget);
  });

  testWidgets('Customer role does NOT see Add Product FAB or edit/toggle controls', (tester) async {
    await tester.pumpWidget(buildScreenForUser(role: UserRole.customer));
    await tester.pumpAndSettle();

    // Products are displayed
    expect(find.text('Fresh Apples 1kg'), findsOneWidget);

    // Management controls are hidden
    expect(find.byKey(const Key('store_add_product_fab')), findsNothing);
    expect(find.byKey(const Key('product_edit_btn_p-1')), findsNothing);
    expect(find.byKey(const Key('product_toggle_p-1')), findsNothing);
  });
}
