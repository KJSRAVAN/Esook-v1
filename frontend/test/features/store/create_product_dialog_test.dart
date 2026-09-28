import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:esouq/features/store/domain/repositories/store_products_repository.dart';
import 'package:esouq/features/store/presentation/widgets/create_product_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStoreProductsRepo implements StoreProductsRepository {
  List<ProductModel> products = [];
  String? lastCreatedName;
  double? lastCreatedPrice;

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
    String? category,
    String? imageUrl,
    int? sortOrder,
  }) async {
    lastCreatedName = name;
    lastCreatedPrice = price;
    final created = ProductModel(
      id: 'prod-new-1',
      name: name,
      price: price,
      description: description,
      category: category,
      imageUrl: imageUrl,
      isAvailable: true,
      storeId: storeId,
    );
    products.add(created);
    return Result.success(created);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeStoreProductsRepo repo;

  setUp(() {
    repo = FakeStoreProductsRepo();
  });

  Widget buildTestDialog() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_dialog_btn'),
            onPressed: () {
              CreateProductDialog.show(
                context,
                storeId: 'store-123',
                productsRepository: repo,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  testWidgets('CreateProductDialog renders with finite constraints without layout exceptions under AppTheme.light', (tester) async {
    await tester.pumpWidget(buildTestDialog());
    await tester.pumpAndSettle();

    // Open dialog
    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();

    // Verify dialog header and form fields render without layout assertion errors
    expect(find.text('Add Store Item'), findsOneWidget);
    expect(find.byKey(const Key('create_product_name_input')), findsOneWidget);
    expect(find.byKey(const Key('create_product_price_input')), findsOneWidget);
    expect(find.byKey(const Key('create_product_submit_btn')), findsOneWidget);
  });

  testWidgets('validates required name and price fields', (tester) async {
    await tester.pumpWidget(buildTestDialog());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();

    // Tap submit without inputting required fields
    await tester.tap(find.byKey(const Key('create_product_submit_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Product name is required'), findsOneWidget);
    expect(find.text('Price is required'), findsOneWidget);
  });

  testWidgets('creates product successfully and closes dialog', (tester) async {
    await tester.pumpWidget(buildTestDialog());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();

    // Fill form
    await tester.enterText(find.byKey(const Key('create_product_name_input')), 'Almarai Milk 2L');
    await tester.enterText(find.byKey(const Key('create_product_price_input')), '11.50');
    await tester.enterText(find.byKey(const Key('create_product_description_input')), 'Fresh cow milk');

    // Submit
    await tester.tap(find.byKey(const Key('create_product_submit_btn')));
    await tester.pumpAndSettle();

    expect(repo.lastCreatedName, 'Almarai Milk 2L');
    expect(repo.lastCreatedPrice, 11.50);
    // Dialog should have popped
    expect(find.text('Add Store Item'), findsNothing);
  });
}
