import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/area_model.dart';
import '../../domain/models/store_model.dart';
import '../../domain/repositories/store_repository.dart';

/// Concrete [StoreRepository] implementation communicating with backend store endpoints.
class StoreRepositoryImpl implements StoreRepository {
  final ApiClient _apiClient;

  const StoreRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<Result<List<StoreModel>>> getStores() async {
    try {
      final response = await _apiClient.get<dynamic>('/stores');
      final dynamic rawData = response.data;
      final List<dynamic> rawList;
      if (rawData is List) {
        rawList = rawData;
      } else if (rawData is Map<String, dynamic>) {
        rawList =
            (rawData['stores'] ?? rawData['data']) as List<dynamic>? ?? [];
      } else {
        rawList = [];
      }

      final stores = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => StoreModel.fromJson(item))
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
  Future<Result<List<AreaModel>>> getAreas() async {
    try {
      final response = await _apiClient.get<dynamic>('/stores/areas');
      final dynamic rawData = response.data;
      final List<dynamic> rawList;
      if (rawData is List) {
        rawList = rawData;
      } else if (rawData is Map<String, dynamic>) {
        rawList = (rawData['areas'] ?? rawData['data']) as List<dynamic>? ?? [];
      } else {
        rawList = [];
      }

      final areas = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => AreaModel.fromJson(item))
          .toList();
      return Result.success(areas);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to fetch delivery areas: $e'),
      );
    }
  }

  @override
  Future<Result<StoreModel>> getStoreById(String id) async {
    try {
      final response = await _apiClient.get<dynamic>('/stores/$id');
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
        rawStore = {};
      }

      final store = StoreModel.fromJson(rawStore);
      return Result.success(store);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to fetch store $id: $e'),
      );
    }
  }
}
