import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/domain/models/order_item_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:esouq/features/store/domain/repositories/store_orders_repository.dart';
import 'package:esouq/features/store/presentation/widgets/store_order_card.dart';
import 'package:esouq/features/store/presentation/widgets/store_order_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockStoreOrdersRepository implements StoreOrdersRepository {
  List<OrderModel> orders = [];
  String? lastUpdatedOrderId;
  OrderStatus? lastUpdatedStatus;
  String? lastRejectedReason;

  @override
  Future<Result<List<OrderModel>>> getStoreOrders({
    required String storeId,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    return Result.success(orders);
  }

  @override
  Future<Result<OrderModel>> getOrderById(String orderId) async {
    final order = orders.firstWhere((o) => o.id == orderId);
    return Result.success(order);
  }

  @override
  Future<Result<OrderModel>> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    String? rejectedReason,
  }) async {
    lastUpdatedOrderId = orderId;
    lastUpdatedStatus = status;
    lastRejectedReason = rejectedReason;
    final order = orders.firstWhere((o) => o.id == orderId);
    final updated = OrderModel(
      id: order.id,
      orderNumber: order.orderNumber,
      customerId: order.customerId,
      storeId: order.storeId,
      storeName: order.storeName,
      status: status,
      fulfillment: order.fulfillment,
      deliveryAddress: order.deliveryAddress,
      couponCode: order.couponCode,
      notes: order.notes,
      subtotal: order.subtotal,
      discount: order.discount,
      deliveryFee: order.deliveryFee,
      total: order.total,
      items: order.items,
      createdAt: order.createdAt,
      updatedAt: DateTime.now(),
      rejectedReason: rejectedReason ?? order.rejectedReason,
    );
    return Result.success(updated);
  }
}

OrderModel createTestOrder({
  required String id,
  required OrderStatus status,
  required FulfillmentType fulfillment,
  String? deliveryAddress,
}) {
  return OrderModel(
    id: id,
    orderNumber: 'ESK-$id',
    customerId: 'cust-1',
    storeId: 'store-1',
    status: status,
    fulfillment: fulfillment,
    deliveryAddress: deliveryAddress ?? (fulfillment == FulfillmentType.delivery ? 'King Fahd Rd, Riyadh' : null),
    subtotal: 50.0,
    total: 50.0,
    items: const [
      OrderItemModel(
        itemId: 'item-1',
        itemName: 'Milk 1L',
        itemPrice: 10.0,
        quantity: 2,
        subtotal: 20.0,
      ),
    ],
  );
}

void main() {
  group('StoreOrderDetailsSheet Fulfillment-Specific Transitions', () {
    late MockStoreOrdersRepository mockRepo;

    setUp(() {
      mockRepo = MockStoreOrdersRepository();
    });

    testWidgets(
      'Delivery order in PREPARING shows Mark Ready for Driver and does NOT allow Out for Delivery jump',
      (tester) async {
        final order = createTestOrder(
          id: 'ord-del-prep',
          status: OrderStatus.preparing,
          fulfillment: FulfillmentType.delivery,
        );
        mockRepo.orders = [order];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderDetailsSheet(
                order: order,
                ordersRepository: mockRepo,
              ),
            ),
          ),
        );

        // Verification: Must NOT show 'Out for Delivery' button to staff
        expect(find.byKey(const Key('details_out_for_delivery_btn')), findsNothing);
        expect(find.text('Out for Delivery'), findsNothing);

        // Verification: Must show 'Mark Ready for Driver'
        final readyBtn = find.byKey(const Key('details_ready_delivery_btn'));
        expect(readyBtn, findsOneWidget);
        expect(find.text('Mark Ready for Driver'), findsOneWidget);

        // Tap button
        await tester.tap(readyBtn);
        await tester.pumpAndSettle();

        // Must transition to READY
        expect(mockRepo.lastUpdatedOrderId, 'ord-del-prep');
        expect(mockRepo.lastUpdatedStatus, OrderStatus.ready);
      },
    );

    testWidgets(
      'Pickup order in PREPARING shows Ready for Pickup and transitions to READY',
      (tester) async {
        final order = createTestOrder(
          id: 'ord-pick-prep',
          status: OrderStatus.preparing,
          fulfillment: FulfillmentType.pickup,
        );
        mockRepo.orders = [order];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderDetailsSheet(
                order: order,
                ordersRepository: mockRepo,
              ),
            ),
          ),
        );

        final readyBtn = find.byKey(const Key('details_ready_pickup_btn'));
        expect(readyBtn, findsOneWidget);
        expect(find.text('Ready for Pickup'), findsOneWidget);

        await tester.tap(readyBtn);
        await tester.pumpAndSettle();

        expect(mockRepo.lastUpdatedOrderId, 'ord-pick-prep');
        expect(mockRepo.lastUpdatedStatus, OrderStatus.ready);
      },
    );

    testWidgets(
      'Pickup order in READY shows Complete Pickup and transitions to DELIVERED',
      (tester) async {
        final order = createTestOrder(
          id: 'ord-pick-ready',
          status: OrderStatus.ready,
          fulfillment: FulfillmentType.pickup,
        );
        mockRepo.orders = [order];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderDetailsSheet(
                order: order,
                ordersRepository: mockRepo,
              ),
            ),
          ),
        );

        final completeBtn = find.byKey(const Key('details_complete_pickup_btn'));
        expect(completeBtn, findsOneWidget);
        expect(find.text('Complete Pickup'), findsOneWidget);

        await tester.tap(completeBtn);
        await tester.pumpAndSettle();

        expect(mockRepo.lastUpdatedOrderId, 'ord-pick-ready');
        expect(mockRepo.lastUpdatedStatus, OrderStatus.delivered);
      },
    );

    testWidgets(
      'Delivery order in READY displays Awaiting Driver status without staff complete button',
      (tester) async {
        final order = createTestOrder(
          id: 'ord-del-ready',
          status: OrderStatus.ready,
          fulfillment: FulfillmentType.delivery,
        );
        mockRepo.orders = [order];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderDetailsSheet(
                order: order,
                ordersRepository: mockRepo,
              ),
            ),
          ),
        );

        // Informational banner should be present
        expect(find.text('Ready for Driver Pickup (Awaiting Driver)'), findsOneWidget);

        // Staff cannot complete delivery orders directly
        expect(find.byKey(const Key('details_complete_btn')), findsNothing);
        expect(find.byKey(const Key('details_complete_pickup_btn')), findsNothing);
      },
    );
  });

  group('StoreOrderCard Quick Actions Fulfillment Separation', () {
    testWidgets(
      'Delivery PREPARING shows Mark Ready quick action',
      (tester) async {
        OrderStatus? selectedStatus;
        final order = createTestOrder(
          id: 'card-del-prep',
          status: OrderStatus.preparing,
          fulfillment: FulfillmentType.delivery,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderCard(
                order: order,
                onQuickStatusChange: (status) => selectedStatus = status,
              ),
            ),
          ),
        );

        final btn = find.byKey(Key('order_ready_delivery_btn_${order.id}'));
        expect(btn, findsOneWidget);
        expect(find.text('Mark Ready'), findsOneWidget);
        expect(find.text('Out for Delivery'), findsNothing);

        await tester.tap(btn);
        expect(selectedStatus, OrderStatus.ready);
      },
    );

    testWidgets(
      'Pickup PREPARING shows Ready for Pickup quick action',
      (tester) async {
        OrderStatus? selectedStatus;
        final order = createTestOrder(
          id: 'card-pick-prep',
          status: OrderStatus.preparing,
          fulfillment: FulfillmentType.pickup,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderCard(
                order: order,
                onQuickStatusChange: (status) => selectedStatus = status,
              ),
            ),
          ),
        );

        final btn = find.byKey(Key('order_ready_pickup_btn_${order.id}'));
        expect(btn, findsOneWidget);
        expect(find.text('Ready for Pickup'), findsOneWidget);

        await tester.tap(btn);
        expect(selectedStatus, OrderStatus.ready);
      },
    );

    testWidgets(
      'Pickup READY shows Complete Pickup quick action',
      (tester) async {
        OrderStatus? selectedStatus;
        final order = createTestOrder(
          id: 'card-pick-ready',
          status: OrderStatus.ready,
          fulfillment: FulfillmentType.pickup,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderCard(
                order: order,
                onQuickStatusChange: (status) => selectedStatus = status,
              ),
            ),
          ),
        );

        final btn = find.byKey(Key('order_complete_pickup_btn_${order.id}'));
        expect(btn, findsOneWidget);
        expect(find.text('Complete Pickup'), findsOneWidget);

        await tester.tap(btn);
        expect(selectedStatus, OrderStatus.delivered);
      },
    );

    testWidgets(
      'Delivery READY does not show quick completion button',
      (tester) async {
        final order = createTestOrder(
          id: 'card-del-ready',
          status: OrderStatus.ready,
          fulfillment: FulfillmentType.delivery,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderCard(
                order: order,
                onQuickStatusChange: (_) {},
              ),
            ),
          ),
        );

        expect(find.byType(ElevatedButton), findsNothing);
      },
    );

    testWidgets(
      'Displays payment method badge in StoreOrderDetailsSheet and StoreOrderCard',
      (tester) async {
        final mockRepo = MockStoreOrdersRepository();
        final cardOrder = createTestOrder(
          id: 'card-payment-test',
          status: OrderStatus.pending,
          fulfillment: FulfillmentType.delivery,
        ).copyWith(paymentMethod: PaymentMethod.card);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderCard(
                order: cardOrder,
                onQuickStatusChange: (_) {},
              ),
            ),
          ),
        );

        // Check StoreOrderCard displays Card badge
        expect(find.text('Card'), findsOneWidget);

        // Check StoreOrderDetailsSheet displays Card badge
        mockRepo.orders = [cardOrder];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderDetailsSheet(
                order: cardOrder,
                ordersRepository: mockRepo,
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('store_order_payment_badge')), findsOneWidget);
        expect(find.text('Card'), findsWidgets);
      },
    );

    testWidgets(
      'Displays customer notes in StoreOrderDetailsSheet when notes are non-empty',
      (tester) async {
        final mockRepo = MockStoreOrdersRepository();
        final orderWithNotes = createTestOrder(
          id: 'order-with-notes',
          status: OrderStatus.pending,
          fulfillment: FulfillmentType.delivery,
        ).copyWith(notes: 'Please double-bag frozen items');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderDetailsSheet(
                order: orderWithNotes,
                ordersRepository: mockRepo,
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('store_order_notes_card')), findsOneWidget);
        expect(find.text('Customer Notes'), findsOneWidget);
        expect(find.text('Please double-bag frozen items'), findsOneWidget);
      },
    );

    testWidgets(
      'Hides customer notes in StoreOrderDetailsSheet when notes are null, empty, or whitespace',
      (tester) async {
        final mockRepo = MockStoreOrdersRepository();

        // 1. null notes
        final orderNullNotes = createTestOrder(
          id: 'order-null-notes',
          status: OrderStatus.pending,
          fulfillment: FulfillmentType.delivery,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderDetailsSheet(
                order: orderNullNotes,
                ordersRepository: mockRepo,
              ),
            ),
          ),
        );
        expect(find.byKey(const Key('store_order_notes_card')), findsNothing);

        // 2. whitespace notes
        final orderWhitespaceNotes = orderNullNotes.copyWith(notes: '   ');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderDetailsSheet(
                order: orderWhitespaceNotes,
                ordersRepository: mockRepo,
              ),
            ),
          ),
        );
        expect(find.byKey(const Key('store_order_notes_card')), findsNothing);
      },
    );

    testWidgets(
      'renders Points Discount row in store order details sheet when pointsDiscount > 0',
      (tester) async {
        final mockRepo = MockStoreOrdersRepository();
        final orderWithPoints = createTestOrder(
          id: 'order-pts-store',
          status: OrderStatus.accepted,
          fulfillment: FulfillmentType.delivery,
        ).copyWith(
          pointsDiscount: 15.0,
          redeemedPoints: 1500,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreOrderDetailsSheet(
                order: orderWithPoints,
                ordersRepository: mockRepo,
              ),
            ),
          ),
        );

        expect(find.text('Points Discount (1500 pts)'), findsOneWidget);
        expect(find.text('-15.00 AED'), findsOneWidget);
      },
    );
  });
}
