import 'package:esouq/core/constants/app_constants.dart';
import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/domain/models/store_model.dart';
import 'package:esouq/features/customer/presentation/screens/customer_market_screen.dart';
import 'package:esouq/features/customer/presentation/widgets/category_filter_bar.dart';
import 'package:esouq/features/customer/presentation/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_product_repository.dart';
import '../../mocks/mock_store_repository.dart';

void main() {
  late MockStoreRepository mockStoreRepo;
  late MockProductRepository mockProductRepo;
  late ValueNotifier<StoreModel?> selectedStoreNotifier;

  setUp(() {
    mockStoreRepo = MockStoreRepository();
    mockProductRepo = MockProductRepository();
    selectedStoreNotifier = ValueNotifier<StoreModel?>(null);
  });

  tearDown(() {
    selectedStoreNotifier.dispose();
  });

  Widget buildWidget({StoreModel? initialStore}) {
    if (initialStore != null) {
      selectedStoreNotifier.value = initialStore;
    }

    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: CustomerMarketScreen(
        storeRepository: mockStoreRepo,
        productRepository: mockProductRepo,
        selectedStoreNotifier: selectedStoreNotifier,
      ),
    );
  }

  group('CustomerMarketScreen', () {
    testWidgets('renders StoreSelectionView when no store is selected', (tester) async {
      await tester.pumpWidget(buildWidget(initialStore: null));
      await tester.pumpAndSettle();

      expect(find.text('Select Supermarket'), findsOneWidget);
      expect(find.text('eSOuQ Olaya Flagship'), findsOneWidget);
    });

    testWidgets('loads catalog and renders products when a store is selected', (tester) async {
      final store = mockStoreRepo.defaultStores.first;
      await tester.pumpWidget(buildWidget(initialStore: store));
      await tester.pumpAndSettle();

      expect(mockProductRepo.getProductsByStoreCallCount, equals(1));
      expect(mockProductRepo.lastStoreIdParam, equals(store.id));

      // Header shows store name and area
      expect(find.text('eSOuQ Olaya Flagship'), findsOneWidget);
      expect(find.text('Riyadh - Olaya'), findsOneWidget);

      // Search bar and category chips
      expect(find.byKey(const Key('market_search_text_field')), findsOneWidget);
      expect(find.byType(CategoryFilterBar), findsOneWidget);
      expect(find.byKey(const Key('category_chip_All')), findsOneWidget);
      expect(find.byKey(const Key('category_chip_Dairy & Eggs')), findsOneWidget);
      expect(find.byKey(const Key('category_chip_Fresh Produce')), findsOneWidget);

      // Product cards
      expect(find.byType(ProductCard), findsNWidgets(3));
      expect(find.text('Fresh Whole Milk 1L'), findsOneWidget);
      expect(find.text('1.25 ${AppConstants.defaultCurrency}'), findsOneWidget);
      expect(find.text('+5 pts'), findsOneWidget);
      expect(find.text('Organic Bananas 1kg'), findsOneWidget);
      expect(find.text('0.85 ${AppConstants.defaultCurrency}'), findsOneWidget);
      expect(find.text('+2 pts'), findsOneWidget);
      expect(find.text('Greek Yogurt 500g'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
    });

    testWidgets('filters products locally by category chip', (tester) async {
      final store = mockStoreRepo.defaultStores.first;
      await tester.pumpWidget(buildWidget(initialStore: store));
      await tester.pumpAndSettle();

      expect(find.byType(ProductCard), findsNWidgets(3));

      // Tap Fresh Produce category
      await tester.tap(find.byKey(const Key('category_chip_Fresh Produce')));
      await tester.pumpAndSettle();

      expect(find.byType(ProductCard), findsOneWidget);
      expect(find.text('Organic Bananas 1kg'), findsOneWidget);
      expect(find.text('Fresh Whole Milk 1L'), findsNothing);

      // Tap All to restore
      await tester.tap(find.byKey(const Key('category_chip_All')));
      await tester.pumpAndSettle();

      expect(find.byType(ProductCard), findsNWidgets(3));
    });

    testWidgets('filters products locally by in-memory search query', (tester) async {
      final store = mockStoreRepo.defaultStores.first;
      await tester.pumpWidget(buildWidget(initialStore: store));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('market_search_text_field')),
        'Milk',
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductCard), findsOneWidget);
      expect(find.text('Fresh Whole Milk 1L'), findsOneWidget);
      expect(find.text('Organic Bananas 1kg'), findsNothing);
    });

    testWidgets('shows empty search result and allows clearing search', (tester) async {
      final store = mockStoreRepo.defaultStores.first;
      await tester.pumpWidget(buildWidget(initialStore: store));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('market_search_text_field')),
        'NonexistentProduct123',
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductCard), findsNothing);
      expect(find.text('No Matching Products'), findsOneWidget);

      await tester.tap(find.text('Clear Filters'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductCard), findsNWidgets(3));
    });

    testWidgets('shows error state and retries on API failure', (tester) async {
      final store = mockStoreRepo.defaultStores.first;
      mockProductRepo.getProductsByStoreResult = Result.failure(
        const ServerFailure(message: 'Server error loading catalog'),
      );

      await tester.pumpWidget(buildWidget(initialStore: store));
      await tester.pumpAndSettle();

      expect(find.text('Could Not Load Products'), findsOneWidget);
      expect(find.text('Server error loading catalog'), findsOneWidget);
      expect(find.byKey(const Key('market_retry_button')), findsOneWidget);

      // Now set success and tap retry
      mockProductRepo.getProductsByStoreResult = Result.success(mockProductRepo.defaultProducts);
      await tester.tap(find.byKey(const Key('market_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ProductCard), findsNWidgets(3));
    });

    testWidgets('shows empty store catalog message when store has 0 products', (tester) async {
      final store = mockStoreRepo.defaultStores.first;
      mockProductRepo.getProductsByStoreResult = Result.success([]);

      await tester.pumpWidget(buildWidget(initialStore: store));
      await tester.pumpAndSettle();

      expect(find.text('No Products in this Store'), findsOneWidget);
    });

    testWidgets('opens store switcher sheet when tapping store header', (tester) async {
      final store = mockStoreRepo.defaultStores.first;
      await tester.pumpWidget(buildWidget(initialStore: store));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('market_store_switcher_button')));
      await tester.pumpAndSettle();

      expect(find.text('Select Supermarket'), findsOneWidget);
      expect(find.text('eSOuQ Al Malqa Fresh'), findsOneWidget);

      // Select second store from sheet
      await tester.tap(find.text('eSOuQ Al Malqa Fresh'));
      await tester.pumpAndSettle();

      expect(selectedStoreNotifier.value?.name, equals('eSOuQ Al Malqa Fresh'));
      expect(find.text('eSOuQ Al Malqa Fresh'), findsOneWidget);
      expect(find.text('Riyadh - Al Malqa'), findsOneWidget);
    });
  });
}
