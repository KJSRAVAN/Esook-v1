import 'package:esouq/features/customer/domain/models/order_item_model.dart';
import 'package:esouq/features/customer/domain/models/order_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderModel & Enums', () {
    test('OrderStatus display names and conversions', () {
      expect(OrderStatus.pending.displayName, equals('Pending'));
      expect(OrderStatus.accepted.displayName, equals('Accepted'));
      expect(OrderStatus.rejected.displayName, equals('Rejected'));
      expect(OrderStatus.preparing.displayName, equals('Preparing'));
      expect(OrderStatus.ready.displayName, equals('Ready'));
      expect(OrderStatus.outForDelivery.displayName, equals('Out for Delivery'));
      expect(OrderStatus.delivered.displayName, equals('Delivered'));
      expect(OrderStatus.cancelled.displayName, equals('Cancelled'));

      expect(OrderStatus.pending.toBackendString(), equals('PENDING'));
      expect(OrderStatus.outForDelivery.toBackendString(), equals('OUT_FOR_DELIVERY'));

      expect(OrderStatus.fromString('PENDING'), equals(OrderStatus.pending));
      expect(OrderStatus.fromString('accepted'), equals(OrderStatus.accepted));
      expect(OrderStatus.fromString('out_for_delivery'), equals(OrderStatus.outForDelivery));
      expect(OrderStatus.fromString('completed'), equals(OrderStatus.delivered));
      expect(OrderStatus.fromString('delivered'), equals(OrderStatus.delivered));
      expect(OrderStatus.fromString('cancelled'), equals(OrderStatus.cancelled));
      expect(OrderStatus.fromString('unknown'), equals(OrderStatus.pending));
    });

    test('FulfillmentType display names and conversions', () {
      expect(FulfillmentType.pickup.displayName, equals('Pickup'));
      expect(FulfillmentType.delivery.displayName, equals('Delivery'));

      expect(FulfillmentType.pickup.toBackendString(), equals('PICKUP'));
      expect(FulfillmentType.delivery.toBackendString(), equals('DELIVERY'));

      expect(FulfillmentType.fromString('PICKUP'), equals(FulfillmentType.pickup));
      expect(FulfillmentType.fromString('pickup'), equals(FulfillmentType.pickup));
      expect(FulfillmentType.fromString('DELIVERY'), equals(FulfillmentType.delivery));
      expect(FulfillmentType.fromString('delivery'), equals(FulfillmentType.delivery));
      expect(FulfillmentType.fromString(null), equals(FulfillmentType.delivery));
    });

    test('OrderModel parses standard backend JSON format', () {
      final json = {
        'id': 'ord-123',
        'orderNumber': 'ESK-2026-001',
        'customerId': 'usr-1',
        'storeId': 'store-1',
        'storeName': 'eSOuQ Olaya Flagship',
        'status': 'PENDING',
        'fulfillment': 'DELIVERY',
        'deliveryAddress': 'Building 4B, King Fahd Rd, Riyadh',
        'couponCode': 'WELCOME10',
        'notes': 'Ring the bell',
        'subtotal': 15.50,
        'discount': 1.55,
        'deliveryFee': 2.00,
        'total': 15.95,
        'pointsEarned': 15,
        'items': [
          {
            'id': 'line-1',
            'itemId': 'prod-1',
            'itemName': 'Fresh Milk',
            'itemPrice': 1.25,
            'quantity': 2,
            'subtotal': 2.50,
          },
        ],
        'createdAt': '2026-09-15T10:00:00.000Z',
        'updatedAt': '2026-09-15T10:05:00.000Z',
      };

      final order = OrderModel.fromJson(json);

      expect(order.id, equals('ord-123'));
      expect(order.orderNumber, equals('ESK-2026-001'));
      expect(order.customerId, equals('usr-1'));
      expect(order.storeId, equals('store-1'));
      expect(order.storeName, equals('eSOuQ Olaya Flagship'));
      expect(order.status, equals(OrderStatus.pending));
      expect(order.fulfillment, equals(FulfillmentType.delivery));
      expect(order.deliveryAddress, equals('Building 4B, King Fahd Rd, Riyadh'));
      expect(order.couponCode, equals('WELCOME10'));
      expect(order.notes, equals('Ring the bell'));
      expect(order.subtotal, equals(15.50));
      expect(order.discount, equals(1.55));
      expect(order.deliveryFee, equals(2.00));
      expect(order.total, equals(15.95));
      expect(order.pointsEarned, equals(15));
      expect(order.items.length, equals(1));
      expect(order.itemCount, equals(2));
      expect(order.createdAt, isNotNull);
      expect(order.updatedAt, isNotNull);
    });

    test('OrderModel parses snake_case and nested store format gracefully', () {
      final json = {
        'id': 'ord-456',
        'order_number': 'ESK-2026-002',
        'user_id': 'usr-2',
        'store_id': 'store-2',
        'store': {
          'id': 'store-2',
          'name': 'eSOuQ Al Malqa',
        },
        'status': 'out_for_delivery',
        'fulfillment_type': 'pickup',
        'subtotal': '20.00',
        'total_amount': '20.00',
        'points_earned': '20',
        'rejected_reason': 'Out of stock',
        'created_at': '2026-09-15T11:00:00.000Z',
      };

      final order = OrderModel.fromJson(json);

      expect(order.id, equals('ord-456'));
      expect(order.orderNumber, equals('ESK-2026-002'));
      expect(order.customerId, equals('usr-2'));
      expect(order.storeId, equals('store-2'));
      expect(order.storeName, equals('eSOuQ Al Malqa'));
      expect(order.status, equals(OrderStatus.outForDelivery));
      expect(order.fulfillment, equals(FulfillmentType.pickup));
      expect(order.subtotal, equals(20.00));
      expect(order.total, equals(20.00));
      expect(order.pointsEarned, equals(20));
      expect(order.rejectedReason, equals('Out of stock'));
    });

    test('OrderModel serializes to JSON correctly', () {
      final order = OrderModel(
        id: 'ord-789',
        orderNumber: 'ESK-2026-003',
        customerId: 'usr-3',
        storeId: 'store-1',
        storeName: 'Olaya Store',
        status: OrderStatus.accepted,
        fulfillment: FulfillmentType.delivery,
        deliveryAddress: 'Main St 12',
        couponCode: 'SALE',
        notes: 'Call before delivery',
        subtotal: 10.0,
        discount: 2.0,
        deliveryFee: 1.0,
        total: 9.0,
        pointsEarned: 5,
        items: const [
          OrderItemModel(
            itemId: 'prod-1',
            itemName: 'Milk',
            itemPrice: 1.25,
            quantity: 2,
          ),
        ],
        createdAt: DateTime.parse('2026-09-15T12:00:00.000Z'),
      );

      final json = order.toJson();

      expect(json['id'], equals('ord-789'));
      expect(json['orderNumber'], equals('ESK-2026-003'));
      expect(json['customerId'], equals('usr-3'));
      expect(json['storeId'], equals('store-1'));
      expect(json['storeName'], equals('Olaya Store'));
      expect(json['status'], equals('ACCEPTED'));
      expect(json['fulfillment'], equals('DELIVERY'));
      expect(json['deliveryAddress'], equals('Main St 12'));
      expect(json['couponCode'], equals('SALE'));
      expect(json['notes'], equals('Call before delivery'));
      expect(json['subtotal'], equals(10.0));
      expect(json['discount'], equals(2.0));
      expect(json['deliveryFee'], equals(1.0));
      expect(json['total'], equals(9.0));
      expect(json['pointsEarned'], equals(5));
      expect((json['items'] as List).length, equals(1));
    });

    test('OrderModel copyWith updates properties', () {
      const order = OrderModel(
        id: 'ord-1',
        customerId: 'usr-1',
        storeId: 'store-1',
        status: OrderStatus.pending,
        fulfillment: FulfillmentType.delivery,
        subtotal: 10.0,
        total: 10.0,
      );

      final updated = order.copyWith(status: OrderStatus.delivered);

      expect(updated.status, equals(OrderStatus.delivered));
      expect(updated.id, equals('ord-1'));
      expect(updated.total, equals(10.0));
    });
  });
}
