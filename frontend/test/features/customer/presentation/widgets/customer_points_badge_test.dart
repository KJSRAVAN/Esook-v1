import 'dart:async';

import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/application/points_notifier.dart';
import 'package:esouq/features/customer/cart/application/cart_notifier.dart';
import 'package:esouq/features/customer/domain/models/store_model.dart';
import 'package:esouq/features/customer/domain/repositories/order_repository.dart';
import 'package:esouq/features/customer/presentation/widgets/customer_points_badge.dart';
import 'package:esouq/features/customer/presentation/widgets/customer_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_cart_repository.dart';
import '../../mocks/mock_order_repository.dart';
import '../../mocks/mock_product_repository.dart';
import '../../mocks/mock_store_repository.dart';

void main() {
  group('CustomerPointsBadge', () {
    late MockOrderRepository mockOrderRepository;
    late PointsNotifier pointsNotifier;
    late CartNotifier cartNotifier;
    late ValueNotifier<StoreModel?> storeNotifier;

    setUp(() {
      mockOrderRepository = MockOrderRepository();
      pointsNotifier = PointsNotifier(orderRepository: mockOrderRepository);
      cartNotifier = CartNotifier(cartRepository: MockCartRepository());
      storeNotifier = ValueNotifier<StoreModel?>(null);
    });

    tearDown(() {
      pointsNotifier.dispose();
      cartNotifier.dispose();
      storeNotifier.dispose();
    });

    Widget buildTestWidget({
      PointsNotifier? explicitNotifier,
      bool wrapWithCustomerScope = false,
      String currency = 'SAR',
    }) {
      Widget content = Scaffold(
        appBar: AppBar(
          title: const Text('Test Screen'),
          actions: [
            CustomerPointsBadge(
              pointsNotifier: explicitNotifier,
              currency: currency,
            ),
          ],
        ),
        body: const Center(child: Text('Content')),
      );

      if (wrapWithCustomerScope) {
        content = CustomerScope(
          storeRepository: MockStoreRepository(),
          productRepository: MockProductRepository(),
          cartRepository: MockCartRepository(),
          orderRepository: mockOrderRepository,
          cartNotifier: cartNotifier,
          pointsNotifier: pointsNotifier,
          selectedStoreNotifier: storeNotifier,
          child: content,
        );
      }

      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: content,
      );
    }

    testWidgets('renders nothing when no PointsNotifier is provided', (tester) async {
      await tester.pumpWidget(buildTestWidget(explicitNotifier: null));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customer_points_badge')), findsNothing);
      expect(find.byKey(const Key('customer_points_badge_text')), findsNothing);
    });

    testWidgets('renders points balance text when notifier is provided', (tester) async {
      pointsNotifier.setPointsInfo(
        const CustomerPointsInfo(
          isEnabled: true,
          pointsPerCurrencyUnit: 0.10,
          balance: 250,
        ),
      );

      await tester.pumpWidget(buildTestWidget(explicitNotifier: pointsNotifier));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customer_points_badge')), findsOneWidget);
      expect(find.byKey(const Key('customer_points_badge_text')), findsOneWidget);
      expect(find.text('250 pts'), findsOneWidget);
      expect(find.byIcon(Icons.stars_rounded), findsOneWidget);
    });

    testWidgets('inherits PointsNotifier from CustomerScope ancestor', (tester) async {
      pointsNotifier.setPointsInfo(
        const CustomerPointsInfo(
          isEnabled: true,
          pointsPerCurrencyUnit: 0.10,
          balance: 180,
        ),
      );

      await tester.pumpWidget(
        buildTestWidget(
          explicitNotifier: null,
          wrapWithCustomerScope: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customer_points_badge')), findsOneWidget);
      expect(find.text('180 pts'), findsOneWidget);
    });

    testWidgets('shows loading spinner when isLoading is true and pointsInfo is null', (
      tester,
    ) async {
      final completer = Completer<Result<CustomerPointsInfo>>();
      mockOrderRepository.customGetStorePointsInfoHandler = (_) => completer.future;

      pointsNotifier.loadForStore('store-1');

      await tester.pumpWidget(buildTestWidget(explicitNotifier: pointsNotifier));
      await tester.pump(); // frame 1 while pending

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('customer_points_badge_text')), findsNothing);

      // Now complete
      completer.complete(
        Result.success(
          const CustomerPointsInfo(
            isEnabled: true,
            balance: 50,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('50 pts'), findsOneWidget);
    });

    testWidgets('tapping badge opens details dialog and Got It closes it', (tester) async {
      pointsNotifier.setPointsInfo(
        const CustomerPointsInfo(
          isEnabled: true,
          pointsPerCurrencyUnit: 0.10,
          balance: 250,
        ),
      );

      await tester.pumpWidget(
        buildTestWidget(
          explicitNotifier: pointsNotifier,
          currency: 'SAR',
        ),
      );
      await tester.pumpAndSettle();

      // Tap badge
      final badge = find.byKey(const Key('customer_points_badge'));
      expect(badge, findsOneWidget);
      await tester.tap(badge);
      await tester.pumpAndSettle();

      // Dialog is visible
      expect(find.byKey(const Key('customer_points_detail_dialog')), findsOneWidget);
      expect(find.text('Loyalty Points'), findsOneWidget);
      expect(find.byKey(const Key('dialog_points_balance_text')), findsOneWidget);
      expect(find.text('250 points'), findsOneWidget);
      expect(find.text('Worth 25.00 SAR (1 pt = 0.10 SAR)'), findsOneWidget);
      expect(
        find.text(
          'Earn points on eligible purchases and redeem them during checkout for an instant discount on your order payable total.',
        ),
        findsOneWidget,
      );

      // Close dialog
      final closeBtn = find.byKey(const Key('dialog_points_close_btn'));
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.byKey(const Key('customer_points_detail_dialog')), findsNothing);
    });

    testWidgets('renders gracefully with 0 points balance', (tester) async {
      pointsNotifier.setPointsInfo(
        const CustomerPointsInfo(
          isEnabled: true,
          pointsPerCurrencyUnit: 0.10,
          balance: 0,
        ),
      );

      await tester.pumpWidget(buildTestWidget(explicitNotifier: pointsNotifier));
      await tester.pumpAndSettle();

      expect(find.text('0 pts'), findsOneWidget);

      await tester.tap(find.byKey(const Key('customer_points_badge')));
      await tester.pumpAndSettle();

      expect(find.text('0 points'), findsOneWidget);
      // When balance is 0, monetary worth row is omitted
      expect(find.textContaining('Worth'), findsNothing);
    });

    testWidgets('renders without overflow on narrow 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      pointsNotifier.setPointsInfo(
        const CustomerPointsInfo(
          isEnabled: true,
          pointsPerCurrencyUnit: 0.10,
          balance: 9999,
        ),
      );

      await tester.pumpWidget(buildTestWidget(explicitNotifier: pointsNotifier));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('9999 pts'), findsOneWidget);
    });
  });
}
