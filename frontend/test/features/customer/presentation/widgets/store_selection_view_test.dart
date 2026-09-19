import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/domain/models/store_model.dart';
import 'package:esouq/features/customer/presentation/widgets/store_card.dart';
import 'package:esouq/features/customer/presentation/widgets/store_selection_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_store_repository.dart';

void main() {
  late MockStoreRepository mockStoreRepo;

  setUp(() {
    mockStoreRepo = MockStoreRepository();
  });

  Widget buildWidget({
    StoreModel? currentSelectedStore,
    required ValueChanged<StoreModel> onStoreSelected,
    VoidCallback? onCancel,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: StoreSelectionView(
          storeRepository: mockStoreRepo,
          currentSelectedStore: currentSelectedStore,
          onStoreSelected: onStoreSelected,
          onCancel: onCancel,
        ),
      ),
    );
  }

  group('StoreSelectionView', () {
    testWidgets('renders loading state initially and then lists stores', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(onStoreSelected: (_) {}));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(StoreCard), findsNWidgets(2));
      expect(find.text('eSOuQ Olaya Flagship'), findsOneWidget);
      expect(find.text('eSOuQ Al Malqa Fresh'), findsOneWidget);
      expect(find.text('Riyadh - Olaya'), findsOneWidget);
      expect(find.text('Riyadh - Al Malqa'), findsOneWidget);
    });

    testWidgets('calls onStoreSelected when tapping a store', (tester) async {
      StoreModel? selected;
      await tester.pumpWidget(
        buildWidget(onStoreSelected: (s) => selected = s),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('eSOuQ Olaya Flagship'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.id, equals('store-1'));
    });

    testWidgets('renders error view on failure and allows retry', (
      tester,
    ) async {
      mockStoreRepo.getStoresResult = Result.failure(
        const NetworkFailure(message: 'Connection failed'),
      );

      await tester.pumpWidget(buildWidget(onStoreSelected: (_) {}));
      await tester.pumpAndSettle();

      expect(find.text('Could Not Load Stores'), findsOneWidget);
      expect(find.text('Connection failed'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Now set success and tap Try Again
      mockStoreRepo.getStoresResult = Result.success(
        mockStoreRepo.defaultStores,
      );
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.byType(StoreCard), findsNWidgets(2));
      expect(find.text('eSOuQ Olaya Flagship'), findsOneWidget);
    });

    testWidgets('renders empty view when no stores exist', (tester) async {
      mockStoreRepo.getStoresResult = Result.success([]);

      await tester.pumpWidget(buildWidget(onStoreSelected: (_) {}));
      await tester.pumpAndSettle();

      expect(find.text('No Active Stores Found'), findsOneWidget);
      expect(find.byType(StoreCard), findsNothing);
    });
  });
}
