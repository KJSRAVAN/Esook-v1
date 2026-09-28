import 'package:esouq/core/error/failures.dart';
import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/admin/domain/models/admin_user_model.dart';
import 'package:esouq/features/admin/domain/repositories/admin_drivers_repository.dart';
import 'package:esouq/features/admin/presentation/screens/admin_drivers_screen.dart';
import 'package:esouq/features/auth/domain/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAdminDriversRepository implements AdminDriversRepository {
  List<AdminUserModel> drivers = [
    const AdminUserModel(
      id: 'driver-1',
      name: 'Ahmed Driver',
      phone: '+966501234567',
      role: UserRole.deliveryRider,
      isActive: true,
    ),
    const AdminUserModel(
      id: 'driver-2',
      name: 'Khalid Driver',
      phone: '+966509876543',
      role: UserRole.deliveryRider,
      isActive: false,
    ),
  ];

  String? lastUpdatedDriverId;
  bool? lastUpdatedStatus;
  String? lastDeletedDriverId;
  bool shouldFailUpdate = false;
  bool shouldFailDelete = false;

  @override
  Future<Result<List<AdminUserModel>>> getDrivers({int page = 1, int limit = 50}) async {
    return Result.success(List.from(drivers));
  }

  @override
  Future<Result<AdminUserModel>> registerDriver({
    required String name,
    required String phone,
    required String password,
    String? storeId,
  }) async {
    final newDriver = AdminUserModel(
      id: 'driver-${drivers.length + 1}',
      name: name,
      phone: phone,
      role: UserRole.deliveryRider,
      isActive: true,
    );
    drivers.add(newDriver);
    return Result.success(newDriver);
  }

  @override
  Future<Result<AdminUserModel>> updateDriverStatus({
    required String driverId,
    required bool isActive,
  }) async {
    lastUpdatedDriverId = driverId;
    lastUpdatedStatus = isActive;

    if (shouldFailUpdate) {
      return Result.failure(const ServerFailure(message: 'Failed to update driver status'));
    }

    final index = drivers.indexWhere((d) => d.id == driverId);
    if (index >= 0) {
      final updated = drivers[index].copyWith(isActive: isActive);
      drivers[index] = updated;
      return Result.success(updated);
    }
    return Result.failure(const ServerFailure(message: 'Driver not found'));
  }

  @override
  Future<Result<void>> deleteDriver(String driverId) async {
    lastDeletedDriverId = driverId;

    if (shouldFailDelete) {
      return Result.failure(const ServerFailure(message: 'Failed to delete driver'));
    }

    drivers.removeWhere((d) => d.id == driverId);
    return Result.success(null);
  }
}

void main() {
  late MockAdminDriversRepository mockRepo;

  setUp(() {
    mockRepo = MockAdminDriversRepository();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: AdminDriversScreen(driversRepository: mockRepo),
    );
  }

  testWidgets('renders list of drivers with active and disabled badges', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Ahmed Driver'), findsOneWidget);
    expect(find.text('+966501234567'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);

    expect(find.text('Khalid Driver'), findsOneWidget);
    expect(find.text('+966509876543'), findsOneWidget);
    expect(find.text('Disabled'), findsOneWidget);
  });

  testWidgets('toggling driver login status updates driver and shows snackbar', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Find the toggle for driver-1 (currently active)
    final toggle = find.byKey(const Key('driver_toggle_driver-1'));
    expect(toggle, findsOneWidget);

    // Tap to disable login
    await tester.tap(toggle);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(mockRepo.lastUpdatedDriverId, 'driver-1');
    expect(mockRepo.lastUpdatedStatus, isFalse);
    expect(find.text('Driver "Ahmed Driver" login disabled'), findsOneWidget);
    expect(find.text('Disabled'), findsNWidgets(2)); // Both driver-1 and driver-2 are now disabled
  });

  testWidgets('delete driver shows confirmation dialog and cancels when canceled', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final deleteBtn = find.byKey(const Key('driver_delete_btn_driver-1'));
    expect(deleteBtn, findsOneWidget);

    // Tap delete button
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();

    // Confirmation dialog should be visible
    expect(find.byKey(const Key('delete_driver_dialog')), findsOneWidget);
    expect(
      find.text('Are you sure you want to permanently delete driver "Ahmed Driver"? This action cannot be undone.'),
      findsOneWidget,
    );

    // Tap Cancel
    await tester.tap(find.byKey(const Key('delete_driver_cancel_btn')));
    await tester.pumpAndSettle();

    // Dialog dismissed and driver not deleted
    expect(find.byKey(const Key('delete_driver_dialog')), findsNothing);
    expect(mockRepo.lastDeletedDriverId, isNull);
    expect(find.text('Ahmed Driver'), findsOneWidget);
  });

  testWidgets('delete driver confirms deletion, removes card, and shows snackbar', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final deleteBtn = find.byKey(const Key('driver_delete_btn_driver-1'));
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();

    // Confirm deletion
    await tester.tap(find.byKey(const Key('confirm_delete_driver_btn')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(mockRepo.lastDeletedDriverId, 'driver-1');
    expect(find.text('Driver "Ahmed Driver" deleted successfully'), findsOneWidget);
    expect(find.text('Ahmed Driver'), findsNothing);
    expect(find.text('Khalid Driver'), findsOneWidget);
  });

  testWidgets('shows error snackbar when delete fails', (tester) async {
    mockRepo.shouldFailDelete = true;

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('driver_delete_btn_driver-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm_delete_driver_btn')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Failed to delete driver'), findsOneWidget);
    expect(find.text('Ahmed Driver'), findsOneWidget); // Driver remains in list
  });
}
