import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/admin/domain/models/admin_store_model.dart';
import 'package:esouq/features/admin/domain/models/store_delivery_area.dart';
import 'package:esouq/features/admin/domain/repositories/admin_stores_repository.dart';
import 'package:esouq/features/admin/presentation/widgets/create_store_dialog.dart';
import 'package:esouq/features/admin/presentation/widgets/edit_store_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAdminStoresRepository implements AdminStoresRepository {
  String? lastCreatedName;
  String? lastCreatedAreaId;
  String? lastCreatedAddress;
  String? lastCreatedPhone;

  String? lastUpdatedStoreId;
  String? lastUpdatedName;
  String? lastUpdatedAreaId;
  String? lastUpdatedAddress;
  String? lastUpdatedPhone;
  bool? lastUpdatedIsActive;

  Result<AdminStoreModel> createResult = Result.success(
    const AdminStoreModel(id: 'new-store-1', name: 'New Store'),
  );

  Result<AdminStoreModel> updateResult = Result.success(
    const AdminStoreModel(id: 'updated-store-1', name: 'Updated Store'),
  );

  @override
  Future<Result<AdminStoreModel>> createStore({
    required String name,
    String? area,
    String? areaId,
    String? address,
    String? phone,
    bool? isActive,
  }) async {
    lastCreatedName = name;
    lastCreatedAreaId = areaId;
    lastCreatedAddress = address;
    lastCreatedPhone = phone;
    return createResult;
  }

  @override
  Future<Result<AdminStoreModel>> updateStore({
    required String storeId,
    String? name,
    String? area,
    String? areaId,
    String? address,
    String? phone,
    bool? isActive,
  }) async {
    lastUpdatedStoreId = storeId;
    lastUpdatedName = name;
    lastUpdatedAreaId = areaId;
    lastUpdatedAddress = address;
    lastUpdatedPhone = phone;
    lastUpdatedIsActive = isActive;
    return updateResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeAdminStoresRepository repository;

  setUp(() {
    repository = FakeAdminStoresRepository();
  });

  void setupViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: child,
        ),
      ),
    );
  }

  group('CreateStoreDialog', () {
    testWidgets('shows Riyadh and Jeddah options in dropdown', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(
        buildTestableWidget(
          CreateStoreDialog(storesRepository: repository),
        ),
      );

      final dropdownFinder = find.byKey(const Key('store_area_dropdown'));
      expect(dropdownFinder, findsOneWidget);

      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      expect(find.text('Riyadh').hitTestable(), findsOneWidget);
      expect(find.text('Jeddah').hitTestable(), findsOneWidget);
    });

    testWidgets('requires delivery area selection', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(
        buildTestableWidget(
          CreateStoreDialog(storesRepository: repository),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('store_name_field')),
        'My Test Store',
      );

      await tester.tap(find.byKey(const Key('submit_store_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please select a delivery area'), findsOneWidget);
      expect(repository.lastCreatedName, isNull);
    });

    testWidgets('selecting Riyadh sends exact Riyadh areaId CUID', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(
        buildTestableWidget(
          CreateStoreDialog(storesRepository: repository),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('store_name_field')),
        'Fresh Mart Riyadh',
      );

      await tester.tap(find.byKey(const Key('store_area_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riyadh').hitTestable());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('submit_store_button')));
      await tester.pumpAndSettle();

      expect(repository.lastCreatedName, 'Fresh Mart Riyadh');
      expect(repository.lastCreatedAreaId, StoreDeliveryArea.riyadhId);
      expect(repository.lastCreatedAreaId, 'cmu5u0i810000vy8ilejcv1rz');
      expect(repository.lastCreatedAreaId, isNot('Riyadh'));
    });

    testWidgets('selecting Jeddah sends exact Jeddah areaId CUID', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(
        buildTestableWidget(
          CreateStoreDialog(storesRepository: repository),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('store_name_field')),
        'Fresh Mart Jeddah',
      );

      await tester.tap(find.byKey(const Key('store_area_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jeddah').hitTestable());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('submit_store_button')));
      await tester.pumpAndSettle();

      expect(repository.lastCreatedName, 'Fresh Mart Jeddah');
      expect(repository.lastCreatedAreaId, StoreDeliveryArea.jeddahId);
      expect(repository.lastCreatedAreaId, 'cmu5u0ink0001vy8i7hu36wkg');
      expect(repository.lastCreatedAreaId, isNot('Jeddah'));
    });

    testWidgets('accepts valid Saudi landline with spaces and normalizes it', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(
        buildTestableWidget(
          CreateStoreDialog(storesRepository: repository),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('store_name_field')),
        'Riyadh Landline Store',
      );

      await tester.tap(find.byKey(const Key('store_area_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riyadh').hitTestable());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('store_phone_field')),
        '011 234 5678',
      );

      await tester.tap(find.byKey(const Key('submit_store_button')));
      await tester.pumpAndSettle();

      expect(repository.lastCreatedPhone, '+966112345678');
    });

    testWidgets('accepts valid Saudi mobile number and normalizes it', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(
        buildTestableWidget(
          CreateStoreDialog(storesRepository: repository),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('store_name_field')),
        'Mobile Store',
      );

      await tester.tap(find.byKey(const Key('store_area_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jeddah').hitTestable());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('store_phone_field')),
        '051 234 5678',
      );

      await tester.tap(find.byKey(const Key('submit_store_button')));
      await tester.pumpAndSettle();

      expect(repository.lastCreatedPhone, '+966512345678');
    });

    testWidgets('rejects phone exceeding 20 characters with validation error', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(
        buildTestableWidget(
          CreateStoreDialog(storesRepository: repository),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('store_name_field')),
        'Long Phone Store',
      );

      await tester.tap(find.byKey(const Key('store_area_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riyadh').hitTestable());
      await tester.pumpAndSettle();

      // 21 characters normalized
      await tester.enterText(
        find.byKey(const Key('store_phone_field')),
        '+96611234567890123456',
      );

      await tester.tap(find.byKey(const Key('submit_store_button')));
      await tester.pumpAndSettle();

      expect(find.text('Phone number cannot exceed 20 characters'), findsOneWidget);
      expect(repository.lastCreatedPhone, isNull);
    });

    testWidgets('rejects invalid phone containing letters', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(
        buildTestableWidget(
          CreateStoreDialog(storesRepository: repository),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('store_name_field')),
        'Bad Phone Store',
      );

      await tester.tap(find.byKey(const Key('store_area_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riyadh').hitTestable());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('store_phone_field')),
        '011234bad',
      );

      await tester.tap(find.byKey(const Key('submit_store_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid contact phone number'), findsOneWidget);
      expect(repository.lastCreatedPhone, isNull);
    });
  });

  group('EditStoreDialog', () {
    testWidgets('preselects Riyadh for store with area Riyadh', (tester) async {
      setupViewport(tester);
      const existingRiyadhStore = AdminStoreModel(
        id: 'store-1',
        name: 'Riyadh Branch',
        area: 'Riyadh',
        areaId: StoreDeliveryArea.riyadhId,
        phone: '+966112345678',
        isActive: true,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          EditStoreDialog(
            store: existingRiyadhStore,
            storesRepository: repository,
          ),
        ),
      );

      expect(find.text('Riyadh'), findsOneWidget);
    });

    testWidgets('preselects Jeddah for store with area Jeddah', (tester) async {
      setupViewport(tester);
      const existingJeddahStore = AdminStoreModel(
        id: 'store-2',
        name: 'Jeddah Branch',
        area: 'Jeddah',
        areaId: StoreDeliveryArea.jeddahId,
        phone: '+966126543210',
        isActive: true,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          EditStoreDialog(
            store: existingJeddahStore,
            storesRepository: repository,
          ),
        ),
      );

      expect(find.text('Jeddah'), findsOneWidget);
    });

    testWidgets('changing Riyadh -> Jeddah sends Jeddah CUID', (tester) async {
      setupViewport(tester);
      const existingStore = AdminStoreModel(
        id: 'store-1',
        name: 'Branch 1',
        area: 'Riyadh',
        areaId: StoreDeliveryArea.riyadhId,
        isActive: true,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          EditStoreDialog(
            store: existingStore,
            storesRepository: repository,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('edit_store_area_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jeddah').hitTestable());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('submit_edit_store_button')));
      await tester.pumpAndSettle();

      expect(repository.lastUpdatedStoreId, 'store-1');
      expect(repository.lastUpdatedAreaId, StoreDeliveryArea.jeddahId);
      expect(repository.lastUpdatedAreaId, 'cmu5u0ink0001vy8i7hu36wkg');
      expect(repository.lastUpdatedAreaId, isNot('Jeddah'));
    });

    testWidgets('changing Jeddah -> Riyadh sends Riyadh CUID', (tester) async {
      setupViewport(tester);
      const existingStore = AdminStoreModel(
        id: 'store-2',
        name: 'Branch 2',
        area: 'Jeddah',
        areaId: StoreDeliveryArea.jeddahId,
        isActive: true,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          EditStoreDialog(
            store: existingStore,
            storesRepository: repository,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('edit_store_area_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riyadh').hitTestable());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('submit_edit_store_button')));
      await tester.pumpAndSettle();

      expect(repository.lastUpdatedStoreId, 'store-2');
      expect(repository.lastUpdatedAreaId, StoreDeliveryArea.riyadhId);
      expect(repository.lastUpdatedAreaId, 'cmu5u0i810000vy8ilejcv1rz');
      expect(repository.lastUpdatedAreaId, isNot('Riyadh'));
    });

    testWidgets('normalizes updated phone in EditStoreDialog', (tester) async {
      setupViewport(tester);
      const existingStore = AdminStoreModel(
        id: 'store-1',
        name: 'Branch 1',
        area: 'Riyadh',
        areaId: StoreDeliveryArea.riyadhId,
        phone: '+966112345678',
        isActive: true,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          EditStoreDialog(
            store: existingStore,
            storesRepository: repository,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('edit_store_phone_field')),
        '012 987 6543',
      );

      await tester.tap(find.byKey(const Key('submit_edit_store_button')));
      await tester.pumpAndSettle();

      expect(repository.lastUpdatedPhone, '+966129876543');
    });

    testWidgets('rejects phone exceeding 20 characters in EditStoreDialog', (tester) async {
      setupViewport(tester);
      const existingStore = AdminStoreModel(
        id: 'store-1',
        name: 'Branch 1',
        area: 'Riyadh',
        areaId: StoreDeliveryArea.riyadhId,
        phone: '+966112345678',
        isActive: true,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          EditStoreDialog(
            store: existingStore,
            storesRepository: repository,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('edit_store_phone_field')),
        '+96611234567890123456',
      );

      await tester.tap(find.byKey(const Key('submit_edit_store_button')));
      await tester.pumpAndSettle();

      expect(find.text('Phone number cannot exceed 20 characters'), findsOneWidget);
      expect(repository.lastUpdatedPhone, isNull);
    });
  });
}
