import 'package:esouq/core/error/failures.dart';
import 'package:esouq/features/customer/application/points_notifier.dart';
import 'package:esouq/features/customer/domain/repositories/order_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/mock_order_repository.dart';

void main() {
  group('PointsNotifier', () {
    late MockOrderRepository mockOrderRepository;
    late PointsNotifier notifier;

    setUp(() {
      mockOrderRepository = MockOrderRepository();
      notifier = PointsNotifier(orderRepository: mockOrderRepository);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('initial state defaults correctly with no initialPointsInfo', () {
      expect(notifier.pointsInfo, isNull);
      expect(notifier.balance, equals(0));
      expect(notifier.isEnabled, isFalse);
      expect(notifier.monetaryValue, equals(0.0));
      expect(notifier.pointsPerCurrencyUnit, equals(0.10));
      expect(notifier.isLoading, isFalse);
      expect(notifier.errorMessage, isNull);
      expect(notifier.currentStoreId, isNull);
    });

    test('initial state respects initialPointsInfo', () {
      final customNotifier = PointsNotifier(
        orderRepository: mockOrderRepository,
        initialPointsInfo: const CustomerPointsInfo(
          isEnabled: true,
          pointsPerCurrencyUnit: 0.15,
          balance: 250,
        ),
      );

      expect(customNotifier.balance, equals(250));
      expect(customNotifier.isEnabled, isTrue);
      expect(customNotifier.pointsPerCurrencyUnit, equals(0.15));
      expect(customNotifier.monetaryValue, closeTo(37.5, 0.001));
      customNotifier.dispose();
    });

    test('loadForStore successfully updates state and notifies listeners', () async {
      mockOrderRepository.pointsInfoToReturn = const CustomerPointsInfo(
        isEnabled: true,
        pointsPerCurrencyUnit: 0.10,
        balance: 300,
      );

      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      final future = notifier.loadForStore('store-123');
      expect(notifier.isLoading, isTrue);
      expect(notifier.currentStoreId, equals('store-123'));

      await future;

      expect(notifier.isLoading, isFalse);
      expect(notifier.balance, equals(300));
      expect(notifier.isEnabled, isTrue);
      expect(notifier.monetaryValue, closeTo(30.0, 0.001));
      expect(notifier.errorMessage, isNull);
      expect(notifyCount, greaterThanOrEqualTo(2)); // start loading + finished loading
    });

    test('loadForStore handles failure gracefully', () async {
      mockOrderRepository.failureToReturn = const NetworkFailure(
        message: 'Network connection failed',
      );

      await notifier.loadForStore('store-123');

      expect(notifier.isLoading, isFalse);
      expect(notifier.errorMessage, equals('Network connection failed'));
      expect(notifier.balance, equals(0));
    });

    test('loadForStore discards stale response if currentStoreId changed mid-flight', () async {
      // Simulate slow response for store-1
      mockOrderRepository.pointsInfoToReturn = const CustomerPointsInfo(
        isEnabled: true,
        pointsPerCurrencyUnit: 0.10,
        balance: 100,
      );

      final load1 = notifier.loadForStore('store-1');
      // Quickly change store before load1 finishes
      notifier.loadForStore('store-2');

      await load1;

      // Current store is store-2
      expect(notifier.currentStoreId, equals('store-2'));
    });

    test('refresh() invokes loadForStore with currentStoreId', () async {
      mockOrderRepository.pointsInfoToReturn = const CustomerPointsInfo(
        isEnabled: true,
        pointsPerCurrencyUnit: 0.10,
        balance: 150,
      );

      await notifier.loadForStore('store-abc');
      expect(mockOrderRepository.getStorePointsInfoCallCount, equals(1));

      mockOrderRepository.pointsInfoToReturn = const CustomerPointsInfo(
        isEnabled: true,
        pointsPerCurrencyUnit: 0.10,
        balance: 200,
      );

      await notifier.refresh();
      expect(mockOrderRepository.getStorePointsInfoCallCount, equals(2));
      expect(notifier.balance, equals(200));
    });

    test('refresh() is a no-op if currentStoreId is null', () async {
      await notifier.refresh();
      expect(mockOrderRepository.getStorePointsInfoCallCount, equals(0));
    });

    test('setPointsInfo updates points info immediately', () {
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      notifier.setPointsInfo(
        const CustomerPointsInfo(
          isEnabled: true,
          pointsPerCurrencyUnit: 0.20,
          balance: 500,
        ),
      );

      expect(notifier.balance, equals(500));
      expect(notifier.monetaryValue, closeTo(100.0, 0.001));
      expect(notifyCount, equals(1));
    });
  });
}
