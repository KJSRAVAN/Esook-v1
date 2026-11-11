import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/file_picker/image_file_picker.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:esouq/features/store/domain/repositories/store_products_repository.dart';
import 'package:esouq/features/store/presentation/widgets/edit_product_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStoreProductsRepoForEdit implements StoreProductsRepository {
  List<ProductModel> products = [];
  String? lastUpdatedProductId;
  String? lastUpdatedName;
  double? lastUpdatedPrice;
  double? lastUpdatedOfferPrice;
  String? lastUpdatedImageUrl;
  String? lastUploadedFileName;
  List<int>? lastUploadedFileBytes;
  Result<String> uploadImageResult = Result.success('https://cdn.example.com/uploads/edited-product.png');

  @override
  Future<Result<List<ProductModel>>> getStoreProducts(String storeId) async {
    return Result.success(products);
  }

  @override
  Future<Result<String>> uploadProductImage({
    required String storeId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    lastUploadedFileName = fileName;
    lastUploadedFileBytes = fileBytes;
    return uploadImageResult;
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
    String? categoryId,
    String? category,
    String? imageUrl,
    int? sortOrder,
    bool? isAvailable,
  }) async {
    lastUpdatedProductId = productId;
    lastUpdatedName = name;
    lastUpdatedPrice = price;
    lastUpdatedOfferPrice = offerPrice;
    lastUpdatedImageUrl = imageUrl;
    final updated = ProductModel(
      id: productId,
      name: name ?? 'Existing',
      price: price ?? 10.0,
      offerPrice: offerPrice,
      description: description,
      category: category,
      imageUrl: imageUrl,
      isAvailable: isAvailable ?? true,
      storeId: storeId,
    );
    return Result.success(updated);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeStoreProductsRepoForEdit repo;
  const initialProduct = ProductModel(
    id: 'prod-edit-1',
    name: 'Organic Bananas 1kg',
    price: 6.50,
    description: 'Fresh organic bananas from Ecuador',
    category: 'Produce',
    imageUrl: 'https://cdn.example.com/bananas.jpg',
    isAvailable: true,
    storeId: 'store-1',
  );

  setUp(() {
    repo = FakeStoreProductsRepoForEdit();
    repo.products = [initialProduct];
  });

  void setupViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Widget buildTestDialog({Future<SelectedImageFile?> Function()? onPickImage}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_edit_dialog_btn'),
            onPressed: () {
              EditProductDialog.show(
                context,
                storeId: 'store-1',
                product: initialProduct,
                productsRepository: repo,
                onPickImage: onPickImage,
              );
            },
            child: const Text('Open Edit'),
          ),
        ),
      ),
    );
  }

  testWidgets('EditProductDialog renders initial product details and form inputs', (tester) async {
    await tester.pumpWidget(buildTestDialog());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_edit_dialog_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Store Item'), findsOneWidget);
    expect(find.byKey(const Key('edit_product_name_input')), findsOneWidget);
    expect(find.byKey(const Key('edit_product_price_input')), findsOneWidget);
    expect(find.byKey(const Key('edit_product_upload_image_btn')), findsOneWidget);
    expect(find.byKey(const Key('edit_product_submit_btn')), findsOneWidget);

    final nameField = tester.widget<TextFormField>(find.byKey(const Key('edit_product_name_input')));
    expect(nameField.controller?.text, 'Organic Bananas 1kg');

    final priceField = tester.widget<TextFormField>(find.byKey(const Key('edit_product_price_input')));
    expect(priceField.controller?.text, '6.50');
  });

  testWidgets('Upload image button picks file, uploads via repo, updates imageUrl field and preserves it on save', (tester) async {
    final fakeFile = SelectedImageFile(
      name: 'banana_fresh.png',
      bytes: [1, 2, 3, 4, 5],
    );

    await tester.pumpWidget(buildTestDialog(
      onPickImage: () async => fakeFile,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_edit_dialog_btn')));
    await tester.pumpAndSettle();

    // Tap upload image button
    await tester.ensureVisible(find.byKey(const Key('edit_product_upload_image_btn')));
    await tester.tap(find.byKey(const Key('edit_product_upload_image_btn')));
    await tester.pumpAndSettle();

    // Verify uploadProductImage was called
    expect(repo.lastUploadedFileName, 'banana_fresh.png');
    expect(repo.lastUploadedFileBytes, [1, 2, 3, 4, 5]);

    // Verify image input field updated
    final urlField = tester.widget<TextFormField>(find.byKey(const Key('edit_product_image_input')));
    expect(urlField.controller?.text, 'https://cdn.example.com/uploads/edited-product.png');

    // Submit edit
    await tester.ensureVisible(find.byKey(const Key('edit_product_submit_btn')));
    await tester.tap(find.byKey(const Key('edit_product_submit_btn')));
    await tester.pumpAndSettle();

    // Verify repository updateProduct received the new image URL
    expect(repo.lastUpdatedProductId, 'prod-edit-1');
    expect(repo.lastUpdatedImageUrl, 'https://cdn.example.com/uploads/edited-product.png');
    expect(find.text('Edit Store Item'), findsNothing);
  });

  testWidgets('Upload image failure displays error message in EditProductDialog', (tester) async {
    repo.uploadImageResult = Result.failure(const ServerFailure(message: 'Storage quota exceeded'));
    final fakeFile = SelectedImageFile(
      name: 'large_photo.png',
      bytes: [1, 2, 3],
    );

    await tester.pumpWidget(buildTestDialog(
      onPickImage: () async => fakeFile,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_edit_dialog_btn')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('edit_product_upload_image_btn')));
    await tester.tap(find.byKey(const Key('edit_product_upload_image_btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit_product_image_error')), findsOneWidget);
    expect(find.text('Storage quota exceeded'), findsOneWidget);
  });

  testWidgets('Upload image rejects file exceeding 5MB limit in EditProductDialog', (tester) async {
    final oversizedFile = SelectedImageFile(
      name: 'huge_image.png',
      bytes: List.filled(6 * 1024 * 1024, 0),
    );

    await tester.pumpWidget(buildTestDialog(
      onPickImage: () async => oversizedFile,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_edit_dialog_btn')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('edit_product_upload_image_btn')));
    await tester.tap(find.byKey(const Key('edit_product_upload_image_btn')));
    await tester.pumpAndSettle();

    expect(repo.lastUploadedFileName, isNull);
    expect(find.byKey(const Key('edit_product_image_error')), findsOneWidget);
    expect(find.text('Selected image exceeds the 5 MB limit'), findsOneWidget);
  });

  testWidgets('validates offer price and successfully submits updated offer price', (tester) async {
    setupViewport(tester);
    await tester.pumpWidget(buildTestDialog());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_edit_dialog_btn')));
    await tester.pumpAndSettle();

    // Regular price is 6.50. Input an offer price of 7.00 (invalid: higher than price)
    await tester.enterText(find.byKey(const Key('edit_product_offer_price_input')), '7.00');

    await tester.ensureVisible(find.byKey(const Key('edit_product_submit_btn')));
    await tester.tap(find.byKey(const Key('edit_product_submit_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Offer price must be less than regular price'), findsOneWidget);
    expect(repo.lastUpdatedOfferPrice, isNull);

    // Correct offer price to 5.00
    await tester.enterText(find.byKey(const Key('edit_product_offer_price_input')), '5.00');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit_product_submit_btn')));
    await tester.pumpAndSettle();

    expect(repo.lastUpdatedProductId, 'prod-edit-1');
    expect(repo.lastUpdatedOfferPrice, equals(5.0));
  });
}

