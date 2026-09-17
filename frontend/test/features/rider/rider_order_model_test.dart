import 'package:esouq/features/rider/domain/models/rider_order_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiderStoreInfo', () {
    test('fromJson parses store fields correctly', () {
      final json = {
        'id': 'store-1',
        'name': 'Store A',
        'address': '123 Main St',
        'phone': '+966501234567',
      };

      final store = RiderStoreInfo.fromJson(json);

      expect(store.id, 'store-1');
      expect(store.name, 'Store A');
      expect(store.address, '123 Main St');
      expect(store.phone, '+966501234567');
    });

    test('fromJson handles missing optional fields', () {
      final json = {'id': 'store-2', 'name': 'Store B'};
      final store = RiderStoreInfo.fromJson(json);

      expect(store.id, 'store-2');
      expect(store.name, 'Store B');
      expect(store.address, isNull);
      expect(store.phone, isNull);
    });

    test('toJson serializes correctly', () {
      const store = RiderStoreInfo(
        id: 'store-1',
        name: 'Store A',
        address: '123 Main St',
        phone: '+966501234567',
      );
      final json = store.toJson();

      expect(json['id'], 'store-1');
      expect(json['name'], 'Store A');
      expect(json['address'], '123 Main St');
      expect(json['phone'], '+966501234567');
    });

    test('equality works correctly', () {
      const s1 = RiderStoreInfo(id: 's1', name: 'A');
      const s2 = RiderStoreInfo(id: 's1', name: 'A');
      const s3 = RiderStoreInfo(id: 's2', name: 'B');

      expect(s1, equals(s2));
      expect(s1, isNot(equals(s3)));
    });
  });

  group('RiderCustomerInfo', () {
    test('fromJson parses phone correctly', () {
      final json = {'phone': '+966509876543'};
      final customer = RiderCustomerInfo.fromJson(json);

      expect(customer.phone, '+966509876543');
    });

    test('fromJson handles missing phone', () {
      final customer = RiderCustomerInfo.fromJson(const {});
      expect(customer.phone, '');
    });

    test('equality works correctly', () {
      const c1 = RiderCustomerInfo(phone: '+966501234567');
      const c2 = RiderCustomerInfo(phone: '+966501234567');
      const c3 = RiderCustomerInfo(phone: '+966509999999');

      expect(c1, equals(c2));
      expect(c1, isNot(equals(c3)));
    });
  });

  group('RiderOrderStatus', () {
    test('fromString parses READY', () {
      expect(RiderOrderStatus.fromString('READY'), RiderOrderStatus.ready);
    });

    test('fromString parses OUT_FOR_DELIVERY', () {
      expect(RiderOrderStatus.fromString('OUT_FOR_DELIVERY'),
          RiderOrderStatus.outForDelivery);
    });

    test('fromString parses DELIVERED', () {
      expect(
          RiderOrderStatus.fromString('DELIVERED'), RiderOrderStatus.delivered);
    });

    test('fromString defaults to ready for unknown', () {
      expect(RiderOrderStatus.fromString('UNKNOWN'), RiderOrderStatus.ready);
      expect(RiderOrderStatus.fromString(null), RiderOrderStatus.ready);
    });

    test('toBackendString returns correct strings', () {
      expect(RiderOrderStatus.ready.toBackendString(), 'READY');
      expect(
          RiderOrderStatus.outForDelivery.toBackendString(), 'OUT_FOR_DELIVERY');
      expect(RiderOrderStatus.delivered.toBackendString(), 'DELIVERED');
    });

    test('displayName returns human-readable names', () {
      expect(RiderOrderStatus.ready.displayName, 'Ready for Pickup');
      expect(
          RiderOrderStatus.outForDelivery.displayName, 'Out for Delivery');
      expect(RiderOrderStatus.delivered.displayName, 'Delivered');
    });
  });

  group('RiderOrderModel', () {
    final fullJson = {
      'id': 'order-001',
      'status': 'READY',
      'fulfillment': 'DELIVERY',
      'deliveryAddress': 'Villa 12, Riyadh',
      'notes': 'Leave at gate',
      'driverId': null,
      'createdAt': '2026-09-17T12:00:00Z',
      'store': {
        'id': 's1',
        'name': 'Store A',
        'address': 'Al Olaya, Riyadh',
        'phone': '+9661',
      },
      'customer': {
        'phone': '+966501234567',
      },
    };

    test('fromJson parses complete DriverOrder response', () {
      final order = RiderOrderModel.fromJson(fullJson);

      expect(order.id, 'order-001');
      expect(order.status, RiderOrderStatus.ready);
      expect(order.fulfillment, 'DELIVERY');
      expect(order.deliveryAddress, 'Villa 12, Riyadh');
      expect(order.notes, 'Leave at gate');
      expect(order.driverId, isNull);
      expect(order.createdAt, isNotNull);
      expect(order.store.id, 's1');
      expect(order.store.name, 'Store A');
      expect(order.store.address, 'Al Olaya, Riyadh');
      expect(order.store.phone, '+9661');
      expect(order.customer.phone, '+966501234567');
    });

    test('fromJson parses OUT_FOR_DELIVERY with driverId', () {
      final json = {
        ...fullJson,
        'status': 'OUT_FOR_DELIVERY',
        'driverId': 'driver-001',
      };
      final order = RiderOrderModel.fromJson(json);

      expect(order.status, RiderOrderStatus.outForDelivery);
      expect(order.driverId, 'driver-001');
    });

    test('fromJson parses DELIVERED status', () {
      final json = {
        ...fullJson,
        'status': 'DELIVERED',
        'driverId': 'driver-001',
      };
      final order = RiderOrderModel.fromJson(json);

      expect(order.status, RiderOrderStatus.delivered);
    });

    test('fromJson handles snake_case alternatives', () {
      final json = {
        'id': 'order-002',
        'status': 'READY',
        'delivery_address': 'Alt Address',
        'driver_id': 'driver-x',
        'created_at': '2026-09-17T15:00:00Z',
        'store': {'id': 's1', 'name': 'S'},
        'customer': {'phone': '+1234'},
      };

      final order = RiderOrderModel.fromJson(json);

      expect(order.deliveryAddress, 'Alt Address');
      expect(order.driverId, 'driver-x');
      expect(order.createdAt, isNotNull);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'order-003',
        'status': 'READY',
        'store': {'id': 's1', 'name': 'S'},
        'customer': {'phone': '+1'},
      };
      final order = RiderOrderModel.fromJson(json);

      expect(order.deliveryAddress, isNull);
      expect(order.notes, isNull);
      expect(order.driverId, isNull);
      expect(order.createdAt, isNull);
      expect(order.fulfillment, 'DELIVERY');
    });

    test('fromJson handles empty map gracefully', () {
      final order = RiderOrderModel.fromJson(const {});
      expect(order.id, '');
      expect(order.status, RiderOrderStatus.ready);
    });

    test('toJson serializes correctly', () {
      final order = RiderOrderModel.fromJson(fullJson);
      final json = order.toJson();

      expect(json['id'], 'order-001');
      expect(json['status'], 'READY');
      expect(json['fulfillment'], 'DELIVERY');
      expect(json['deliveryAddress'], 'Villa 12, Riyadh');
      expect(json['notes'], 'Leave at gate');
      expect(json['store'], isA<Map<String, dynamic>>());
      expect(json['customer'], isA<Map<String, dynamic>>());
    });

    test('copyWith creates modified copy', () {
      final order = RiderOrderModel.fromJson(fullJson);
      final delivered = order.copyWith(
        status: RiderOrderStatus.delivered,
        driverId: 'driver-001',
      );

      expect(delivered.status, RiderOrderStatus.delivered);
      expect(delivered.driverId, 'driver-001');
      expect(delivered.id, order.id);
      expect(delivered.store, order.store);
    });

    test('equality compares id, status, and driverId', () {
      final o1 = RiderOrderModel.fromJson(fullJson);
      final o2 = RiderOrderModel.fromJson(fullJson);

      expect(o1, equals(o2));
    });

    test('toString returns useful representation', () {
      final order = RiderOrderModel.fromJson(fullJson);
      expect(order.toString(), contains('order-001'));
      expect(order.toString(), contains('Store A'));
    });
  });
}
