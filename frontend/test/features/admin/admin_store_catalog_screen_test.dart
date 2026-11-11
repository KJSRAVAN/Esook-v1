import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/admin/domain/models/admin_store_model.dart';
import 'package:esouq/features/admin/domain/repositories/admin_drivers_repository.dart';
import 'package:esouq/features/admin/domain/repositories/admin_stores_repository.dart';
import 'package:esouq/features/admin/domain/repositories/admin_users_repository.dart';
import 'package:esouq/features/admin/presentation/screens/admin_store_catalog_screen.dart';
import 'package:esouq/features/admin/presentation/screens/admin_stores_screen.dart';
import 'package:esouq/features/admin/presentation/widgets/admin_csv_import_dialog.dart';
import 'package:esouq/features/admin/presentation/widgets/admin_scope.dart';
import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:esouq/features/store/domain/models/csv_import_result_model.dart';
import 'package:esouq/features/store/domain/models/store_category_model.dart';
import 'package:esouq/features/store/domain/repositories/store_categories_repository.dart';
import 'package:esouq/features/store/domain/repositories/store_products_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAdminUsersRepository implements AdminUsersRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAdminDriversRepository implements AdminDriversRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAdminStoresRepository implements AdminStoresRepository {
  List<AdminStoreModel> stores = [];
  bool shouldFail = false;

  @override
  Future<Result<List<AdminStoreModel>>> getStores() async {
    if (shouldFail) {
      return Result.failure(const ServerFailure(message: 'Failed to fetch stores'));
    }
    return Result.success(stores);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStoreProductsRepository implements StoreProductsRepository {
  Map<String, List<ProductModel>> productsByStore = {};
  bool shouldFailGet = false;
  bool shouldFailToggle = false;
  String? lastToggledStoreId;
  String? lastToggledProductId;
  bool? lastToggledStatus;

  @override
  Future<Result<List<ProductModel>>> getStoreProducts(String storeId) async {
    if (shouldFailGet) {
      return Result.failure(const ServerFailure(message: 'Failed to load catalog'));
    }
    final list = productsByStore[storeId] ?? [];
    return Result.success(List.from(list));
  }

  @override
  Future<Result<ProductModel>> toggleAvailability({
    required String storeId,
    required String productId,
    required bool isAvailable,
  }) async {
    if (shouldFailToggle) {
      return Result.failure(const ServerFailure(message: 'Toggle failed'));
    }
    lastToggledStoreId = storeId;
    lastToggledProductId = productId;
    lastToggledStatus = isAvailable;

    final list = productsByStore[storeId] ?? [];
    final idx = list.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final existing = list[idx];
      final updated = ProductModel(
        id: existing.id,
        storeId: existing.storeId,
        categoryId: existing.categoryId,
        name: existing.name,
        description: existing.description,
        price: existing.price,
        category: existing.category,
        imageUrl: existing.imageUrl,
        isAvailable: isAvailable,
        sortOrder: existing.sortOrder,
        loyaltyPointsPerUnit: existing.loyaltyPointsPerUnit,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      list[idx] = updated;
      return Result.success(updated);
    }
    return Result.failure(const UnknownFailure(message: 'Product not found'));
  }

  @override
  Future<Result<ProductModel>> createProduct({
    required String storeId,
    required String name,
    String? description,
    required double price,
    double? offerPrice,
    int? pointsValue,
    String? category,
    String? categoryId,
    String? imageUrl,
    int? sortOrder,
  }) async {
    final newProd = ProductModel(
      id: 'prod-${DateTime.now().millisecondsSinceEpoch}',
      storeId: storeId,
      name: name,
      price: price,
      offerPrice: offerPrice,
      category: category,
      categoryId: categoryId,
      description: description,
      imageUrl: imageUrl,
      sortOrder: sortOrder ?? 0,
      isAvailable: true,
    );
    final list = productsByStore.putIfAbsent(storeId, () => []);
    list.insert(0, newProd);
    return Result.success(newProd);
  }

  @override
  Future<Result<ProductModel>> updateProduct({
    required String storeId,
    required String productId,
    String? name,
    String? description,
    double? price,
    double? offerPrice,
    bool clearOfferPrice = false,
    int? pointsValue,
    String? category,
    String? categoryId,
    String? imageUrl,
    int? sortOrder,
    bool? isAvailable,
  }) async {
    final list = productsByStore[storeId] ?? [];
    final idx = list.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final existing = list[idx];
      final updated = ProductModel(
        id: existing.id,
        storeId: existing.storeId,
        name: name ?? existing.name,
        description: description ?? existing.description,
        price: price ?? existing.price,
        offerPrice: offerPrice ?? existing.offerPrice,
        category: category ?? existing.category,
        categoryId: categoryId ?? existing.categoryId,
        imageUrl: imageUrl ?? existing.imageUrl,
        sortOrder: sortOrder ?? existing.sortOrder,
        isAvailable: isAvailable ?? existing.isAvailable,
        loyaltyPointsPerUnit: existing.loyaltyPointsPerUnit,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      list[idx] = updated;
      return Result.success(updated);
    }
    return Result.failure(const UnknownFailure(message: 'Product not found'));
  }

  bool shouldFailImport = false;
  CsvImportResultModel? importResultToReturn;
  String? lastImportStoreId;
  List<int>? lastImportFileBytes;
  String? lastImportFileName;

  @override
  Future<Result<CsvImportResultModel>> importCsv({
    required String storeId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    lastImportStoreId = storeId;
    lastImportFileBytes = fileBytes;
    lastImportFileName = fileName;

    if (shouldFailImport) {
      return Result.failure(const ServerFailure(message: 'CSV import failed on server'));
    }

    return Result.success(
      importResultToReturn ??
          const CsvImportResultModel(
            imported: 3,
            updated: 1,
            skipped: 0,
            errors: [],
          ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStoreCategoriesRepository implements StoreCategoriesRepository {
  Map<String, List<StoreCategoryModel>> categoriesByStore = {};

  @override
  Future<Result<List<StoreCategoryModel>>> getCategories(String storeId) async {
    return Result.success(categoriesByStore[storeId] ?? []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeAdminUsersRepository usersRepo;
  late FakeAdminDriversRepository driversRepo;
  late FakeAdminStoresRepository storesRepo;
  late FakeStoreProductsRepository productsRepo;
  late FakeStoreCategoriesRepository categoriesRepo;

  final store1 = const AdminStoreModel(
    id: 'store-1',
    name: 'Al-Madina Hypermarket',
    areaName: 'Downtown',
    isActive: true,
  );
  final store2 = const AdminStoreModel(
    id: 'store-2',
    name: 'Olaya Express',
    areaName: 'Olaya',
    isActive: true,
  );

  final product1 = const ProductModel(
    id: 'prod-1',
    storeId: 'store-1',
    name: 'Fresh Red Apple',
    price: 4.50,
    category: 'Produce',
    isAvailable: true,
  );
  final product2 = const ProductModel(
    id: 'prod-2',
    storeId: 'store-1',
    name: 'Almarai Full Fat Milk 2L',
    price: 11.00,
    category: 'Dairy',
    isAvailable: true,
  );
  final product3 = const ProductModel(
    id: 'prod-3',
    storeId: 'store-2',
    name: 'Whole Grain Bread',
    price: 5.25,
    category: 'Bakery',
    isAvailable: false,
  );

  setUp(() {
    usersRepo = FakeAdminUsersRepository();
    driversRepo = FakeAdminDriversRepository();
    storesRepo = FakeAdminStoresRepository();
    productsRepo = FakeStoreProductsRepository();
    categoriesRepo = FakeStoreCategoriesRepository();

    storesRepo.stores = [store1, store2];
    productsRepo.productsByStore = {
      'store-1': [product1, product2],
      'store-2': [product3],
    };
  });

  void setupViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createSubject({
    String? initialStoreId,
    bool? isSuperAdmin,
    Future<SelectedCsvFile?> Function()? onPickCsvFile,
  }) {
    return MaterialApp(
      home: AdminStoreCatalogScreen(
        initialStoreId: initialStoreId,
        storesRepository: storesRepo,
        productsRepository: productsRepo,
        categoriesRepository: categoriesRepo,
        isSuperAdmin: isSuperAdmin,
        onPickCsvFile: onPickCsvFile,
      ),
    );
  }

  group('AdminStoreCatalogScreen', () {
    testWidgets('loads stores and displays initial store catalog products',
        (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createSubject(initialStoreId: 'store-1'));
      await tester.pumpAndSettle();

      expect(find.text('Store Catalog Oversight'), findsOneWidget);
      expect(find.byKey(const Key('admin_catalog_store_dropdown')), findsOneWidget);
      expect(find.text('Fresh Red Apple'), findsOneWidget);
      expect(find.text('4.50 AED'), findsOneWidget);
      expect(find.text('Almarai Full Fat Milk 2L'), findsOneWidget);
      expect(find.text('11.00 AED'), findsOneWidget);
      expect(find.text('Available'), findsNWidgets(2));
    });

    testWidgets('switching store in dropdown loads products for selected store',
        (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createSubject(initialStoreId: 'store-1'));
      await tester.pumpAndSettle();

      expect(find.text('Fresh Red Apple'), findsOneWidget);

      // Open store dropdown
      await tester.tap(find.byKey(const Key('admin_catalog_store_dropdown')));
      await tester.pumpAndSettle();

      // Tap Olaya Express (store-2)
      await tester.tap(find.text('Olaya Express (Olaya)').last);
      await tester.pumpAndSettle();

      // Olaya Express products should now be displayed
      expect(find.text('Whole Grain Bread'), findsOneWidget);
      expect(find.text('5.25 AED'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('Fresh Red Apple'), findsNothing);
    });

    testWidgets('search query filters products by name', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createSubject(initialStoreId: 'store-1'));
      await tester.pumpAndSettle();

      expect(find.text('Fresh Red Apple'), findsOneWidget);
      expect(find.text('Almarai Full Fat Milk 2L'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('admin_catalog_search_input')),
        'Apple',
      );
      await tester.pumpAndSettle();

      expect(find.text('Fresh Red Apple'), findsOneWidget);
      expect(find.text('Almarai Full Fat Milk 2L'), findsNothing);
    });

    testWidgets('category filter chips filter products by category',
        (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createSubject(initialStoreId: 'store-1'));
      await tester.pumpAndSettle();

      // Chips for Dairy and Produce should exist
      expect(find.text('Produce'), findsWidgets);
      expect(find.text('Dairy'), findsWidgets);

      // Tap Dairy chip
      await tester.tap(find.widgetWithText(FilterChip, 'Dairy'));
      await tester.pumpAndSettle();

      expect(find.text('Almarai Full Fat Milk 2L'), findsOneWidget);
      expect(find.text('Fresh Red Apple'), findsNothing);

      // Tap All Items chip
      await tester.tap(find.widgetWithText(FilterChip, 'All Items'));
      await tester.pumpAndSettle();

      expect(find.text('Fresh Red Apple'), findsOneWidget);
      expect(find.text('Almarai Full Fat Milk 2L'), findsOneWidget);
    });

    testWidgets('inline availability switch toggles product availability',
        (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createSubject(initialStoreId: 'store-1'));
      await tester.pumpAndSettle();

      final toggleKey = find.byKey(const Key('product_toggle_prod-1'));
      expect(toggleKey, findsOneWidget);

      // Toggle from true to false
      await tester.tap(toggleKey);
      await tester.pumpAndSettle();

      expect(productsRepo.lastToggledStoreId, 'store-1');
      expect(productsRepo.lastToggledProductId, 'prod-1');
      expect(productsRepo.lastToggledStatus, false);
      expect(find.text('Fresh Red Apple is now Unavailable'), findsOneWidget);
    });

    testWidgets('displays empty state and add first product button when catalog empty',
        (tester) async {
      setupViewport(tester);
      productsRepo.productsByStore['store-1'] = [];

      await tester.pumpWidget(createSubject(initialStoreId: 'store-1'));
      await tester.pumpAndSettle();

      expect(find.text('No Products in Catalog'), findsOneWidget);
      expect(find.byKey(const Key('empty_add_product_btn')), findsOneWidget);
    });

    testWidgets('displays error state and retries on failure', (tester) async {
      setupViewport(tester);
      productsRepo.shouldFailGet = true;

      await tester.pumpWidget(createSubject(initialStoreId: 'store-1'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Catalog'), findsOneWidget);
      expect(find.byKey(const Key('products_retry_btn')), findsOneWidget);

      // Now resolve error and retry
      productsRepo.shouldFailGet = false;
      await tester.tap(find.byKey(const Key('products_retry_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Fresh Red Apple'), findsOneWidget);
      expect(find.text('Almarai Full Fat Milk 2L'), findsOneWidget);
    });

    testWidgets('restricts CSV import action based on Super Admin access',
        (tester) async {
      setupViewport(tester);

      // Non-super-admin should not see CSV import button
      await tester.pumpWidget(createSubject(
        initialStoreId: 'store-1',
        isSuperAdmin: false,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_catalog_csv_import_btn')), findsNothing);

      // Super admin should see CSV import button
      await tester.pumpWidget(createSubject(
        initialStoreId: 'store-1',
        isSuperAdmin: true,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_catalog_csv_import_btn')), findsOneWidget);
    });

    testWidgets('CSV upload action opens dialog and refreshes catalog after successful upload',
        (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createSubject(
        initialStoreId: 'store-1',
        isSuperAdmin: true,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_catalog_csv_import_btn')), findsOneWidget);

      // Tap CSV import button
      await tester.tap(find.byKey(const Key('admin_catalog_csv_import_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Bulk Import Products (CSV)'), findsOneWidget);

      // Populate file via template
      await tester.tap(find.byKey(const Key('csv_load_sample_btn')));
      await tester.pumpAndSettle();

      // Configure a new imported item in productsByStore to verify refresh
      final importedProd = const ProductModel(
        id: 'prod-imported-1',
        storeId: 'store-1',
        name: 'Imported Organic Kiwi',
        price: 15.00,
        category: 'Produce',
        isAvailable: true,
      );
      productsRepo.productsByStore['store-1']!.add(importedProd);

      // Tap Upload & Import
      await tester.tap(find.byKey(const Key('csv_import_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Import Completed'), findsOneWidget);
      expect(find.byKey(const Key('csv_stat_imported')), findsOneWidget);

      // Tap Done to close dialog
      await tester.tap(find.byKey(const Key('csv_import_done_btn')));
      await tester.pumpAndSettle();

      // Catalog should have refreshed and display the new product
      expect(find.text('Imported Organic Kiwi'), findsOneWidget);
      expect(find.text('15.00 AED'), findsOneWidget);

      // Success SnackBar is visible
      expect(find.textContaining('CSV Import complete'), findsOneWidget);
    });
  });

  group('AdminStoresScreen Manage Catalog navigation', () {
    testWidgets('Manage Catalog button on store card navigates to catalog screen',
        (tester) async {
      setupViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminScope(
            usersRepository: usersRepo,
            driversRepository: driversRepo,
            storesRepository: storesRepo,
            productsRepository: productsRepo,
            categoriesRepository: categoriesRepo,
            child: AdminStoresScreen(storesRepository: storesRepo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('manage_catalog_btn_store-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('manage_catalog_btn_store-1')));
      await tester.pumpAndSettle();

      // Should have navigated to AdminStoreCatalogScreen
      expect(find.text('Store Catalog Oversight'), findsOneWidget);
      expect(find.text('Fresh Red Apple'), findsOneWidget);
    });
  });
}
