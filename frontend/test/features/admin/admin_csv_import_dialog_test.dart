import 'dart:async';
import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/admin/presentation/widgets/admin_csv_import_dialog.dart';
import 'package:esouq/features/store/domain/models/csv_import_result_model.dart';
import 'package:esouq/features/store/domain/repositories/store_products_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStoreProductsRepositoryForDialog implements StoreProductsRepository {
  bool shouldDelay = false;
  Completer<Result<CsvImportResultModel>>? pendingCompleter;
  Result<CsvImportResultModel>? resultToReturn;
  String? lastStoreId;
  List<int>? lastBytes;
  String? lastFileName;

  @override
  Future<Result<CsvImportResultModel>> importCsv({
    required String storeId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    lastStoreId = storeId;
    lastBytes = fileBytes;
    lastFileName = fileName;

    if (shouldDelay && pendingCompleter != null) {
      return pendingCompleter!.future;
    }

    return resultToReturn ??
        Result.success(
          const CsvImportResultModel(
            imported: 10,
            updated: 2,
            skipped: 1,
            errors: [
              CsvRowErrorModel(row: 3, message: 'Invalid unit price', field: 'price'),
            ],
          ),
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeStoreProductsRepositoryForDialog repo;

  setUp(() {
    repo = FakeStoreProductsRepositoryForDialog();
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
    SelectedCsvFile? initialFile,
    Future<SelectedCsvFile?> Function()? onPickFile,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AdminCsvImportDialog(
          storeId: 'store-1',
          storeName: 'Downtown Branch',
          productsRepository: repo,
          initialFile: initialFile,
          onPickFile: onPickFile,
        ),
      ),
    );
  }

  group('AdminCsvImportDialog', () {
    testWidgets('renders idle state with title and file selector', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('Bulk Import Products (CSV)'), findsOneWidget);
      expect(find.text('Store: Downtown Branch'), findsOneWidget);
      expect(find.byKey(const Key('csv_file_picker_btn')), findsOneWidget);
      expect(find.byKey(const Key('csv_load_sample_btn')), findsOneWidget);
      expect(find.byKey(const Key('csv_import_submit_btn')), findsOneWidget);
    });

    testWidgets('loading sample CSV populates file and enables submit', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Tap sample template
      await tester.tap(find.byKey(const Key('csv_load_sample_btn')));
      await tester.pumpAndSettle();

      expect(find.text('sample_products.csv'), findsOneWidget);
      expect(find.byKey(const Key('csv_raw_text_input')), findsOneWidget);

      // Now submit is enabled
      await tester.tap(find.byKey(const Key('csv_import_submit_btn')));
      await tester.pumpAndSettle();

      expect(repo.lastStoreId, 'store-1');
      expect(repo.lastFileName, 'sample_products.csv');
      expect(repo.lastBytes, isNotEmpty);
    });

    testWidgets('shows loading state while import is processing', (tester) async {
      setupViewport(tester);
      repo.shouldDelay = true;
      repo.pendingCompleter = Completer<Result<CsvImportResultModel>>();

      final sampleFile = SelectedCsvFile.fromString(
        name: 'test.csv',
        content: 'name,price\nApple,5.0',
      );

      await tester.pumpWidget(createSubject(initialFile: sampleFile));
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.byKey(const Key('csv_import_submit_btn')));
      await tester.pump(); // Start async call

      expect(find.byKey(const Key('csv_import_loading_indicator')), findsOneWidget);
      expect(find.text('Processing CSV Catalog...'), findsOneWidget);

      // Complete the call
      repo.pendingCompleter!.complete(
        Result.success(
          const CsvImportResultModel(imported: 5, updated: 1, skipped: 0, errors: []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Import Completed'), findsOneWidget);
    });

    testWidgets('displays success state with imported, updated, skipped metrics and row errors', (tester) async {
      setupViewport(tester);
      repo.resultToReturn = Result.success(
        const CsvImportResultModel(
          imported: 15,
          updated: 4,
          skipped: 2,
          errors: [
            CsvRowErrorModel(row: 6, message: 'Price cannot be negative', field: 'price'),
            CsvRowErrorModel(row: 11, message: 'Unknown category', field: 'category'),
          ],
        ),
      );

      final sampleFile = SelectedCsvFile.fromString(
        name: 'test.csv',
        content: 'name,price\nApple,5.0',
      );

      await tester.pumpWidget(createSubject(initialFile: sampleFile));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('csv_import_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Import Completed'), findsOneWidget);
      expect(find.byKey(const Key('csv_stat_imported')), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.byKey(const Key('csv_stat_updated')), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.byKey(const Key('csv_stat_skipped')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Row-level errors
      expect(find.text('Row-Level Errors (2)'), findsOneWidget);
      expect(find.text('Price cannot be negative'), findsOneWidget);
      expect(find.text('Unknown category'), findsOneWidget);
      expect(find.text('Row 6'), findsOneWidget);
      expect(find.text('Row 11'), findsOneWidget);
      expect(find.byKey(const Key('csv_import_done_btn')), findsOneWidget);
    });

    testWidgets('displays failure state on server failure and allows retry', (tester) async {
      setupViewport(tester);
      repo.resultToReturn = Result.failure(
        const ServerFailure(message: 'Invalid CSV headers: missing price column'),
      );

      final sampleFile = SelectedCsvFile.fromString(
        name: 'bad_test.csv',
        content: 'name,desc\nApple,Fresh',
      );

      await tester.pumpWidget(createSubject(initialFile: sampleFile));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('csv_import_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Import Failed'), findsOneWidget);
      expect(find.text('Invalid CSV headers: missing price column'), findsOneWidget);
      expect(find.byKey(const Key('csv_import_retry_btn')), findsOneWidget);

      // Tap retry -> returns to idle view
      await tester.tap(find.byKey(const Key('csv_import_retry_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Bulk Import Products (CSV)'), findsOneWidget);
      expect(find.byKey(const Key('csv_import_submit_btn')), findsOneWidget);
    });
  });
}
