import 'package:esouq/core/utils/result.dart';
import 'package:esouq/features/customer/domain/models/store_model.dart';
import 'package:esouq/features/customer/domain/repositories/store_repository.dart';

class MockStoreRepository implements StoreRepository {
  Result<List<StoreModel>>? getStoresResult;
  Result<StoreModel>? getStoreByIdResult;
  Result<StoreModel>? getStoreByAreaResult;

  int getStoresCallCount = 0;
  int getStoreByIdCallCount = 0;
  int getStoreByAreaCallCount = 0;

  String? lastGetStoreByIdParam;
  String? lastGetStoreByAreaParam;

  List<StoreModel> defaultStores = [
    const StoreModel(
      id: 'store-1',
      name: 'eSOuQ Olaya Flagship',
      area: 'Riyadh - Olaya',
      address: 'King Fahd Road, Olaya',
      phoneNumber: '+966112345678',
      isActive: true,
    ),
    const StoreModel(
      id: 'store-2',
      name: 'eSOuQ Al Malqa Fresh',
      area: 'Riyadh - Al Malqa',
      address: 'Anas Ibn Malik St',
      phoneNumber: '+966118765432',
      isActive: true,
    ),
  ];

  @override
  Future<Result<List<StoreModel>>> getStores() async {
    getStoresCallCount++;
    if (getStoresResult != null) return getStoresResult!;
    return Result.success(defaultStores);
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

  @override
  Future<Result<StoreModel>> getStoreByArea(String area) async {
    getStoreByAreaCallCount++;
    lastGetStoreByAreaParam = area;
    if (getStoreByAreaResult != null) return getStoreByAreaResult!;
    final match = defaultStores.firstWhere(
      (s) => s.area.toLowerCase() == area.toLowerCase(),
      orElse: () => defaultStores.first,
    );
    return Result.success(match);
  }
}
