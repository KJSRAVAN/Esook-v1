import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/store_model.dart';
import '../../domain/repositories/store_repository.dart';

/// Concrete [StoreRepository] implementation communicating with eSOuQ backend store endpoints.
class StoreRepositoryImpl implements StoreRepository {
  final ApiClient _apiClient;

  const StoreRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<List<StoreModel>>> getStores() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/stores');
      final rawList = response.data['stores'] as List<dynamic>? ?? [];
      final stores = rawList
          .map((item) => StoreModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return Result.success(stores);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to fetch stores: $e'));
    }
  }

  @override
  Future<Result<StoreModel>> getStoreById(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/stores/$id');
      final rawStore = response.data['store'] as Map<String, dynamic>? ?? {};
      final store = StoreModel.fromJson(rawStore);
      return Result.success(store);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to fetch store $id: $e'));
    }
  }

  @override
  Future<Result<StoreModel>> getStoreByArea(String area) async {
    try {
      final encodedArea = Uri.encodeComponent(area);
      final response = await _apiClient.get<Map<String, dynamic>>('/stores/area/$encodedArea');
      final rawStore = response.data['store'] as Map<String, dynamic>? ?? {};
      final store = StoreModel.fromJson(rawStore);
      return Result.success(store);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to fetch store for area $area: $e'));
    }
  }
}
