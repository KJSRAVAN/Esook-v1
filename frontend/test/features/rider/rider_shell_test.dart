import 'package:esouq/core/error/failures.dart';
import 'package:esouq/features/auth/domain/models/user_model.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:esouq/features/auth/domain/repositories/auth_repository.dart';
import 'package:esouq/features/rider/domain/models/rider_order_model.dart';
import 'package:esouq/features/rider/domain/repositories/rider_repository.dart';
import 'package:esouq/features/rider/presentation/screens/rider_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repositories
// ---------------------------------------------------------------------------

class FakeAuthRepository implements AuthRepository {
  bool logoutCalled = false;
  UserModel? currentUser;

  @override
  Future<Result<UserModel>> getCurrentUser() async {
    if (currentUser != null) return Result.success(currentUser!);
    return Result.failure(const UnknownFailure(message: 'Not logged in'));
  }

  @override
  Future<Result<void>> logout() async {
    logoutCalled = true;
    return Result.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRiderRepository implements RiderRepository {
  List<RiderOrderModel> availableOrders = [];
  RiderOrderModel? activeOrder;
  bool acceptCalled = false;
  bool deliverCalled = false;
  AppFailure? acceptFailure;
  AppFailure? deliverFailure;

  @override
  Future<Result<List<RiderOrderModel>>> getAvailableOrders() async {
    return Result.success(availableOrders);
  }

  @override
  Future<Result<RiderOrderModel?>> getActiveOrder() async {
    return Result.success(activeOrder);
  }

  @override
  Future<Result<RiderOrderModel>> acceptOrder(String orderId) async {
    acceptCalled = true;
    if (acceptFailure != null) return Result.failure(acceptFailure!);
    final order = availableOrders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => availableOrders.first,
    );
    final accepted = order.copyWith(
      status: RiderOrderStatus.outForDelivery,
      driverId: 'driver-001',
    );
    availableOrders.removeWhere((o) => o.id == orderId);
    activeOrder = accepted;
    return Result.success(accepted);
  }

  @override
  Future<Result<RiderOrderModel>> markDelivered(String orderId) async {
    deliverCalled = true;
    if (deliverFailure != null) return Result.failure(deliverFailure!);
    final delivered = activeOrder!.copyWith(status: RiderOrderStatus.delivered);
    activeOrder = null;
    return Result.success(delivered);
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _testUser = UserModel(
  id: 'driver-001',
  phoneNumber: '+966501234567',
  fullName: 'Test Rider',
  role: UserRole.deliveryRider,
);

final _sampleAvailableOrder = RiderOrderModel(
  id: 'order-001',
  status: RiderOrderStatus.ready,
  fulfillment: 'DELIVERY',
  deliveryAddress: 'Villa 12, Riyadh',
  notes: 'Leave at gate',
  store: const RiderStoreInfo(
    id: 's1',
    name: 'Store A',
    address: 'Al Olaya, Riyadh',
    phone: '+9661',
  ),
  customer: const RiderCustomerInfo(phone: '+966509876543'),
  createdAt: DateTime(2026, 9, 17, 12, 0),
);

final _sampleActiveOrder = _sampleAvailableOrder.copyWith(
  status: RiderOrderStatus.outForDelivery,
  driverId: 'driver-001',
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget buildTestWidget({
  required FakeAuthRepository authRepository,
  required FakeRiderRepository riderRepository,
  int initialIndex = 0,
}) {
  return MaterialApp(
    home: RiderShell(
      initialIndex: initialIndex,
      authRepository: authRepository,
      riderRepository: riderRepository,
      initialUser: _testUser,
    ),
    routes: {
      '/auth/login': (_) => const Scaffold(body: Text('Login Screen')),
    },
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RiderShell', () {
    late FakeAuthRepository fakeAuth;
    late FakeRiderRepository fakeRider;

    setUp(() {
      fakeAuth = FakeAuthRepository()..currentUser = _testUser;
      fakeRider = FakeRiderRepository();
    });

    testWidgets('shows loading indicator while loading user', (tester) async {
      final slowAuth = FakeAuthRepository(); // currentUser is null, no initialUser

      await tester.pumpWidget(
        MaterialApp(
          home: RiderShell(
            authRepository: slowAuth,
            riderRepository: fakeRider,
            // intentionally no initialUser to trigger loading
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders mobile navigation with 3 tabs', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(
        authRepository: fakeAuth,
        riderRepository: fakeRider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
    });

    testWidgets('renders NavigationRail on wide screens', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(
        authRepository: fakeAuth,
        riderRepository: fakeRider,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('shows Active Delivery tab by default with empty state',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(
        authRepository: fakeAuth,
        riderRepository: fakeRider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('No Active Delivery'), findsOneWidget);
      expect(
        find.text('Accept an available order to start a delivery.'),
        findsOneWidget,
      );
    });

    testWidgets('shows active order when one exists', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeRider.activeOrder = _sampleActiveOrder;

      await tester.pumpWidget(buildTestWidget(
        authRepository: fakeAuth,
        riderRepository: fakeRider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Delivery In Progress'), findsOneWidget);
      expect(find.text('Store A'), findsOneWidget);
      expect(find.text('Mark as Delivered'), findsOneWidget);
    });

    testWidgets('navigates to Available Orders tab', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(
        authRepository: fakeAuth,
        riderRepository: fakeRider,
      ));
      await tester.pumpAndSettle();

      // Tap Available tab
      await tester.tap(find.text('Available'));
      await tester.pumpAndSettle();

      expect(find.text('Available Orders'), findsOneWidget);
    });

    testWidgets('shows available orders list', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeRider.availableOrders = [_sampleAvailableOrder];

      await tester.pumpWidget(buildTestWidget(
        authRepository: fakeAuth,
        riderRepository: fakeRider,
        initialIndex: 1,
      ));
      await tester.pumpAndSettle();

      expect(find.text('1 order available'), findsOneWidget);
      expect(find.text('Accept Delivery'), findsOneWidget);
    });

    testWidgets('shows empty state for available orders', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(
        authRepository: fakeAuth,
        riderRepository: fakeRider,
        initialIndex: 1,
      ));
      await tester.pumpAndSettle();

      expect(find.text('No Orders Available'), findsOneWidget);
    });

    testWidgets('navigates to Account tab and shows rider info',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(
        authRepository: fakeAuth,
        riderRepository: fakeRider,
        initialIndex: 2,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Test Rider'), findsOneWidget);
      expect(find.text('+966501234567'), findsWidgets);
      expect(find.text('Delivery Rider'), findsOneWidget);
    });

    testWidgets('Account logout triggers auth repository logout',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(
        authRepository: fakeAuth,
        riderRepository: fakeRider,
        initialIndex: 2,
      ));
      await tester.pumpAndSettle();

      // Find and tap logout
      final logoutButton = find.byKey(const Key('rider_logout_btn'));
      await tester.ensureVisible(logoutButton);
      await tester.pumpAndSettle();
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      // Confirm dialog
      await tester.tap(find.text('Sign Out').last);
      await tester.pumpAndSettle();

      expect(fakeAuth.logoutCalled, isTrue);
    });

    testWidgets('deliveryRider role is correctly identified', (tester) async {
      expect(_testUser.role, UserRole.deliveryRider);
      expect(_testUser.role.isDeliveryRider, isTrue);
      expect(_testUser.role.isCustomer, isFalse);
      expect(_testUser.role.isStoreStaff, isFalse);
      expect(_testUser.role.isSuperAdmin, isFalse);
    });

    testWidgets('mark delivered shows confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeRider.activeOrder = _sampleActiveOrder;

      await tester.pumpWidget(buildTestWidget(
        authRepository: fakeAuth,
        riderRepository: fakeRider,
      ));
      await tester.pumpAndSettle();

      // Tap Mark as Delivered
      final deliverBtn = find.byKey(const Key('rider_mark_delivered_btn'));
      await tester.ensureVisible(deliverBtn);
      await tester.pumpAndSettle();
      await tester.tap(deliverBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Confirm Delivery'), findsOneWidget);
      expect(find.text('Confirm Delivered'), findsOneWidget);
    });
  });
}
