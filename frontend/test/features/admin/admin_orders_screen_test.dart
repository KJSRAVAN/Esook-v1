import 'package:esouq/core/constants/app_constants.dart';
import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/admin/domain/models/admin_store_model.dart';
import 'package:esouq/features/admin/domain/repositories/admin_stores_repository.dart';
import 'package:esouq/features/admin/presentation/screens/admin_orders_screen.dart';
import 'package:esouq/features/customer/domain/models/order_item_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/customer/presentation/widgets/order_details_sheet.dart';
import 'package:esouq/features/store/domain/repositories/store_orders_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAdminStoresRepository implements AdminStoresRepository {
  List<AdminStoreModel> stores = const [
    AdminStoreModel(
      id: 'store-1',
      name: 'Fresh Mart Riyadh',
      areaId: 'area-1',
      area: 'Riyadh',
      address: 'King Fahd Rd',
      isActive: true,
    ),
    AdminStoreModel(
      id: 'store-2',
      name: 'Fresh Mart Jeddah',
      areaId: 'area-2',
      area: 'Jeddah',
      address: 'Corniche Rd',
      isActive: true,
    ),
  ];

  @override
  Future<Result<List<AdminStoreModel>>> getStores() async {
    return Result.success(stores);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStoreOrdersRepository implements StoreOrdersRepository {
  int getStoreOrdersCallCount = 0;
  String? lastStoreId;
  Result<List<OrderModel>>? overrideResult;

  Map<String, List<OrderModel>> ordersByStore = {
    'store-1': [
      OrderModel(
        id: 'ord-101',
        orderNumber: 'ORD-101',
        customerId: 'cust-1',
        storeId: 'store-1',
        status: OrderStatus.pending,
        fulfillment: FulfillmentType.delivery,
        subtotal: 45.0,
        total: 50.0,
        createdAt: DateTime(2026, 9, 19, 14, 30),
        items: const [
          OrderItemModel(
            id: 'item-1',
            orderId: 'ord-101',
            itemId: 'prod-1',
            itemName: 'Fresh Whole Milk 1L',
            quantity: 2,
            itemPrice: 15.0,
          ),
          OrderItemModel(
            id: 'item-2',
            orderId: 'ord-101',
            itemId: 'prod-2',
            itemName: 'Organic Bananas 1kg',
            quantity: 1,
            itemPrice: 15.0,
          ),
        ],
      ),
    ],
    'store-2': [
      OrderModel(
        id: 'ord-201',
        orderNumber: 'ORD-201',
        customerId: 'cust-2',
        storeId: 'store-2',
        status: OrderStatus.delivered,
        fulfillment: FulfillmentType.pickup,
        subtotal: 80.0,
        total: 80.0,
        createdAt: DateTime(2026, 9, 19, 12, 0),
        items: const [
          OrderItemModel(
            id: 'item-3',
            orderId: 'ord-201',
            itemId: 'prod-3',
            itemName: 'Greek Yogurt 500g',
            quantity: 4,
            itemPrice: 20.0,
          ),
        ],
      ),
    ],
  };

  @override
  Future<Result<List<OrderModel>>> getStoreOrders({
    required String storeId,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    getStoreOrdersCallCount++;
    lastStoreId = storeId;
    if (overrideResult != null) return overrideResult!;
    return Result.success(ordersByStore[storeId] ?? []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeAdminStoresRepository fakeStoresRepo;
  late FakeStoreOrdersRepository fakeOrdersRepo;

  setUp(() {
    fakeStoresRepo = FakeAdminStoresRepository();
    fakeOrdersRepo = FakeStoreOrdersRepository();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: AdminOrdersScreen(
        storesRepository: fakeStoresRepo,
        ordersRepository: fakeOrdersRepo,
      ),
    );
  }

  group('AdminOrdersScreen Tests', () {
    testWidgets(
      'initially loads stores, shows store dropdown, and queries first store orders',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Orders Oversight'), findsOneWidget);
        expect(find.text('Select Store for Order Stream'), findsOneWidget);
        expect(
          find.byKey(const Key('admin_orders_store_dropdown')),
          findsOneWidget,
        );

        // First store is selected and orders queried
        expect(fakeOrdersRepo.getStoreOrdersCallCount, equals(1));
        expect(fakeOrdersRepo.lastStoreId, equals('store-1'));

        // Orders feed header and order card rendered
        expect(find.text('Orders Feed'), findsOneWidget);
        expect(find.text('Fresh Mart Riyadh'), findsWidgets);
        expect(
          find.byKey(const Key('admin_order_card_ord-101')),
          findsOneWidget,
        );
        expect(find.text('Order #ORD-101'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(find.text('DELIVERY'), findsOneWidget);
        expect(
          find.text('50.00 ${AppConstants.defaultCurrency}'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows empty state when store has no orders', (tester) async {
      fakeOrdersRepo.ordersByStore['store-1'] = [];

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('admin_orders_empty_state')),
        findsOneWidget,
      );
      expect(find.text('No Orders Found'), findsOneWidget);
      expect(
        find.text('This store does not have any orders recorded yet.'),
        findsOneWidget,
      );
    });

    testWidgets('shows error state on failure and allows retry', (tester) async {
      fakeOrdersRepo.overrideResult = Result.failure(
        const ServerFailure(message: 'Connection timeout'),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('admin_orders_error_card')),
        findsOneWidget,
      );
      expect(find.text('Failed to Load Orders'), findsOneWidget);
      expect(find.text('Connection timeout'), findsOneWidget);
      expect(
        find.byKey(const Key('admin_orders_retry_button')),
        findsOneWidget,
      );

      // Now clear failure and tap retry
      fakeOrdersRepo.overrideResult = null;
      await tester.tap(find.byKey(const Key('admin_orders_retry_button')));
      await tester.pumpAndSettle();

      expect(fakeOrdersRepo.getStoreOrdersCallCount, equals(2));
      expect(
        find.byKey(const Key('admin_orders_error_card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('admin_order_card_ord-101')),
        findsOneWidget,
      );
    });

    testWidgets('changing stores in dropdown reloads orders for the new store', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('admin_order_card_ord-101')),
        findsOneWidget,
      );

      // Open dropdown and select second store
      await tester.tap(find.byKey(const Key('admin_orders_store_dropdown')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fresh Mart Jeddah').last);
      await tester.pumpAndSettle();

      expect(fakeOrdersRepo.getStoreOrdersCallCount, equals(2));
      expect(fakeOrdersRepo.lastStoreId, equals('store-2'));

      // Now store-2 order is displayed
      expect(
        find.byKey(const Key('admin_order_card_ord-201')),
        findsOneWidget,
      );
      expect(find.text('Order #ORD-201'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('PICKUP'), findsOneWidget);
    });

    testWidgets(
      'refresh button reloads orders for currently selected store',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(fakeOrdersRepo.getStoreOrdersCallCount, equals(1));

        await tester.tap(find.byKey(const Key('admin_orders_refresh_button')));
        await tester.pumpAndSettle();

        expect(fakeOrdersRepo.getStoreOrdersCallCount, equals(2));
        expect(fakeOrdersRepo.lastStoreId, equals('store-1'));
      },
    );

    testWidgets('does not issue duplicate requests on ordinary rebuilds', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(fakeOrdersRepo.getStoreOrdersCallCount, equals(1));

      // Trigger standard rebuild
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(fakeOrdersRepo.getStoreOrdersCallCount, equals(1));
    });

    testWidgets('tapping order card opens order details sheet', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin_order_card_ord-101')));
      await tester.pumpAndSettle();

      // Order details sheet opened
      expect(find.byType(OrderDetailsSheet), findsOneWidget);
      expect(find.text('Order #ORD-101'), findsWidgets);
      expect(find.textContaining('Fresh Whole Milk 1L'), findsWidgets);
    });
  });
}
