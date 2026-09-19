import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/admin_area_model.dart';
import '../../domain/models/admin_store_model.dart';
import '../../domain/repositories/admin_stores_repository.dart';

/// Concrete [AdminStoresRepository] communicating with `/stores` endpoints.
class AdminStoresRepositoryImpl implements AdminStoresRepository {
  final ApiClient _apiClient;

  const AdminStoresRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<Result<List<AdminStoreModel>>> getStores() async {
    try {
      final response = await _apiClient.get<dynamic>('/stores');

      final dynamic rawData = response.data;
      final List<dynamic> rawList;

      if (rawData is List) {
        rawList = rawData;
      } else if (rawData is Map<String, dynamic>) {
        rawList =
            (rawData['stores'] ?? rawData['data']) as List<dynamic>? ??
            const [];
      } else {
        rawList = const [];
      }

      final stores = rawList
          .whereType<Map<String, dynamic>>()
          .map(AdminStoreModel.fromJson)
          .toList();

      return Result.success(stores);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to fetch stores: $e'),
      );
    }
  }

  @override
  Future<Result<List<AdminAreaModel>>> getAreas() async {
    try {
      final response = await _apiClient.get<dynamic>('/stores/areas');

      final dynamic rawData = response.data;
      final List<dynamic> rawList;

      if (rawData is List) {
        rawList = rawData;
      } else if (rawData is Map<String, dynamic>) {
        rawList =
            (rawData['areas'] ?? rawData['data']) as List<dynamic>? ?? const [];
      } else {
        rawList = const [];
      }

      final areas = rawList
          .whereType<Map<String, dynamic>>()
          .map(AdminAreaModel.fromJson)
          .toList();

      return Result.success(areas);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to fetch areas: $e'),
      );
    }
  }

  @override
  Future<Result<AdminStoreModel>> createStore({
    required String name,
    String? area,
    String? areaId,
    String? address,
    String? phone,
    bool? isActive,
  }) async {
    try {
      final effectiveAreaId = (areaId ?? area ?? '').trim();
      final body = <String, dynamic>{
        'name': name.trim(),
        'areaId': effectiveAreaId,
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      };

      final response = await _apiClient.post<dynamic>('/stores', body: body);

      final dynamic rawData = response.data;
      final Map<String, dynamic> rawStore;
      if (rawData is Map<String, dynamic>) {
        if (rawData['store'] is Map<String, dynamic>) {
          rawStore = rawData['store'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawStore = rawData['data'] as Map<String, dynamic>;
        } else {
          rawStore = rawData;
        }
      } else {
        rawStore = const {};
      }

      final store = AdminStoreModel.fromJson(rawStore);
      return Result.success(store);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to create store: $e'),
      );
    }
  }

  @override
  Future<Result<AdminStoreModel>> updateStore({
    required String storeId,
    String? name,
    String? area,
    String? address,
    String? phone,
    bool? isActive,
  }) async {
    try {
      final body = <String, dynamic>{
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (area != null && area.trim().isNotEmpty) 'areaId': area.trim(),
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (isActive != null) 'isActive': isActive,
      };

      final response = await _apiClient.patch<dynamic>(
        '/stores/$storeId',
        body: body,
      );

      final dynamic rawData = response.data;
      final Map<String, dynamic> rawStore;
      if (rawData is Map<String, dynamic>) {
        if (rawData['store'] is Map<String, dynamic>) {
          rawStore = rawData['store'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawStore = rawData['data'] as Map<String, dynamic>;
        } else {
          rawStore = rawData;
        }
      } else {
        rawStore = const {};
      }

      final store = AdminStoreModel.fromJson(rawStore);
      return Result.success(store);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to update store $storeId: $e'),
      );
    }
  }
}
