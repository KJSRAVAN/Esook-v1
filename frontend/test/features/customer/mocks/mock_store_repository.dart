import 'package:esouq/features/customer/domain/models/area_model.dart';
import 'package:esouq/features/customer/domain/models/store_model.dart';
import 'package:esouq/features/customer/domain/repositories/store_repository.dart';

class MockStoreRepository implements StoreRepository {
  Result<List<StoreModel>>? getStoresResult;
  Result<List<AreaModel>>? getAreasResult;
  Result<StoreModel>? getStoreByIdResult;

  int getStoresCallCount = 0;
  int getAreasCallCount = 0;
  int getStoreByIdCallCount = 0;

  String? lastGetStoreByIdParam;

  List<StoreModel> defaultStores = [
    const StoreModel(
      id: 'store-1',
      name: 'eSOuQ Olaya Flagship',
      area: 'Riyadh - Olaya',
      areaId: 'area-1',
      address: 'King Fahd Road, Olaya',
      phoneNumber: '+966112345678',
      isActive: true,
    ),
    const StoreModel(
      id: 'store-2',
      name: 'eSOuQ Al Malqa Fresh',
      area: 'Riyadh - Al Malqa',
      areaId: 'area-2',
      address: 'Anas Ibn Malik St',
      phoneNumber: '+966118765432',
      isActive: true,
    ),
  ];

  List<AreaModel> defaultAreas = [
    const AreaModel(
      id: 'area-1',
      name: 'Riyadh - Olaya',
    ),
    const AreaModel(
      id: 'area-2',
      name: 'Riyadh - Al Malqa',
    ),
  ];

  @override
  Future<Result<List<StoreModel>>> getStores() async {
    getStoresCallCount++;
    if (getStoresResult != null) return getStoresResult!;
    return Result.success(defaultStores);
  }

  @override
  Future<Result<List<AreaModel>>> getAreas() async {
    getAreasCallCount++;
    if (getAreasResult != null) return getAreasResult!;
    return Result.success(defaultAreas);
  }

  @override
  Future<Result<StoreModel>> getStoreById(String id) async {
    getStoreByIdCallCount++;
    lastGetStoreByIdParam = id;
    if (getStoreByIdResult != null) return getStoreByIdResult!;
    final match = defaultStores.firstWhere(
      (s) => s.id == id,
      orElse: () => defaultStores.first,
    );
    return Result.success(match);
  }
}
