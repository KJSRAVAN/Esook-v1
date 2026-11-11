import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/file_picker/image_file_picker.dart';
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
  double? lastCreatedOfferPrice;
  String? lastCreatedImageUrl;
  String? lastUploadedFileName;
  List<int>? lastUploadedFileBytes;
  Result<String> uploadImageResult = Result.success('https://cdn.example.com/uploads/product.jpg');

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
  Future<Result<ProductModel>> createProduct({
    required String storeId,
    required String name,
    String? description,
    required double price,
    double? offerPrice,
    int? pointsValue,
    String? categoryId,
    String? category,
    String? imageUrl,
    int? sortOrder,
  }) async {
    lastCreatedName = name;
    lastCreatedPrice = price;
    lastCreatedOfferPrice = offerPrice;
    lastCreatedImageUrl = imageUrl;
    final created = ProductModel(
      id: 'prod-new-1',
      name: name,
      price: price,
      offerPrice: offerPrice,
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
            key: const Key('open_dialog_btn'),
            onPressed: () {
              CreateProductDialog.show(
                context,
                storeId: 'store-123',
                productsRepository: repo,
                onPickImage: onPickImage,
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
    expect(find.byKey(const Key('create_product_upload_image_btn')), findsOneWidget);
    expect(find.byKey(const Key('create_product_submit_btn')), findsOneWidget);
  });

  testWidgets('validates required name and price fields', (tester) async {
    await tester.pumpWidget(buildTestDialog());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();

    // Tap submit without inputting required fields
    await tester.ensureVisible(find.byKey(const Key('create_product_submit_btn')));
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
    await tester.ensureVisible(find.byKey(const Key('create_product_submit_btn')));
    await tester.tap(find.byKey(const Key('create_product_submit_btn')));
    await tester.pumpAndSettle();

    expect(repo.lastCreatedName, 'Almarai Milk 2L');
    expect(repo.lastCreatedPrice, 11.50);
    // Dialog should have popped
    expect(find.text('Add Store Item'), findsNothing);
  });

  testWidgets('Upload image button picks file, uploads via repo, and populates imageUrl', (tester) async {
    setupViewport(tester);
    final fakeFile = SelectedImageFile(
      name: 'milk_jug.png',
      bytes: [10, 20, 30, 40],
    );

    await tester.pumpWidget(buildTestDialog(
      onPickImage: () async => fakeFile,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();

    // Tap upload image button
    await tester.ensureVisible(find.byKey(const Key('create_product_upload_image_btn')));
    await tester.tap(find.byKey(const Key('create_product_upload_image_btn')));
    await tester.pumpAndSettle();

    // Verify uploadProductImage was called with picked bytes and name
    expect(repo.lastUploadedFileName, 'milk_jug.png');
    expect(repo.lastUploadedFileBytes, [10, 20, 30, 40]);

    // Verify the URL input is populated with uploaded URL
    final urlField = tester.widget<TextFormField>(find.byKey(const Key('create_product_image_input')));
    expect(urlField.controller?.text, 'https://cdn.example.com/uploads/product.jpg');

    // Fill required fields and submit
    await tester.enterText(find.byKey(const Key('create_product_name_input')), 'Fresh Milk');
    await tester.enterText(find.byKey(const Key('create_product_price_input')), '5.00');
    await tester.ensureVisible(find.byKey(const Key('create_product_submit_btn')));
    await tester.tap(find.byKey(const Key('create_product_submit_btn')));
    await tester.pumpAndSettle();

    // Verify created product preserved the uploaded image URL
    expect(repo.lastCreatedImageUrl, 'https://cdn.example.com/uploads/product.jpg');
  });

  testWidgets('Upload image failure displays error message', (tester) async {
    repo.uploadImageResult = Result.failure(const ServerFailure(message: 'Storage full'));
    final fakeFile = SelectedImageFile(
      name: 'large_photo.jpg',
      bytes: [1, 2, 3],
    );

    await tester.pumpWidget(buildTestDialog(
      onPickImage: () async => fakeFile,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();

    // Tap upload image button
    await tester.ensureVisible(find.byKey(const Key('create_product_upload_image_btn')));
    await tester.tap(find.byKey(const Key('create_product_upload_image_btn')));
    await tester.pumpAndSettle();

    // Verify error message is rendered
    expect(find.byKey(const Key('create_product_image_error')), findsOneWidget);
    expect(find.text('Storage full'), findsOneWidget);
  });

  testWidgets('Upload image rejects file exceeding 5MB limit before network call', (tester) async {
    final oversizedFile = SelectedImageFile(
      name: 'giant.png',
      bytes: List.filled(6 * 1024 * 1024, 0),
    );

    await tester.pumpWidget(buildTestDialog(
      onPickImage: () async => oversizedFile,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();

    // Tap upload image button
    await tester.ensureVisible(find.byKey(const Key('create_product_upload_image_btn')));
    await tester.tap(find.byKey(const Key('create_product_upload_image_btn')));
    await tester.pumpAndSettle();

    // Verify rejected without calling repository
    expect(repo.lastUploadedFileName, isNull);
    expect(find.byKey(const Key('create_product_image_error')), findsOneWidget);
    expect(find.text('Selected image exceeds the 5 MB limit'), findsOneWidget);
  });

  testWidgets('validates offer price must be less than regular price and submits valid offer price', (tester) async {
    setupViewport(tester);
    await tester.pumpWidget(buildTestDialog());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();

    // Fill product name
    await tester.enterText(find.byKey(const Key('create_product_name_input')), 'Special Coffee');
    // Fill regular price: 10.00
    await tester.enterText(find.byKey(const Key('create_product_price_input')), '10.00');
    // Fill invalid offer price: 15.00 (greater than regular price)
    await tester.enterText(find.byKey(const Key('create_product_offer_price_input')), '15.00');

    // Attempt to submit
    await tester.ensureVisible(find.byKey(const Key('create_product_submit_btn')));
    await tester.tap(find.byKey(const Key('create_product_submit_btn')));
    await tester.pumpAndSettle();

    // Verify error shown and not created
    expect(find.text('Offer price must be less than regular price'), findsOneWidget);
    expect(repo.lastCreatedName, isNull);

    // Correct offer price to 8.00 (valid discount)
    await tester.enterText(find.byKey(const Key('create_product_offer_price_input')), '8.00');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create_product_submit_btn')));
    await tester.pumpAndSettle();

    // Verify successfully submitted with offer price
    expect(repo.lastCreatedName, equals('Special Coffee'));
    expect(repo.lastCreatedPrice, equals(10.0));
    expect(repo.lastCreatedOfferPrice, equals(8.0));
  });
}
