import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/rider_order_model.dart';
import '../../domain/repositories/rider_repository.dart';

/// Production implementation of [RiderRepository].
///
/// Communicates with origin/Prod_Backend driver endpoints:
/// - GET  /drivers/orders/available
/// - GET  /drivers/orders/active
/// - POST /drivers/orders/:orderId/accept
/// - PATCH /drivers/orders/:orderId/status
class RiderRepositoryImpl implements RiderRepository {
  final ApiClient _apiClient;

  RiderRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<List<RiderOrderModel>>> getAvailableOrders() async {
    try {
      final response = await _apiClient.get<dynamic>('/drivers/orders/available');

      final List<RiderOrderModel> orders;
      if (response.data is List) {
        orders = (response.data as List)
            .whereType<Map<String, dynamic>>()
            .map(RiderOrderModel.fromJson)
            .toList();
      } else {
        orders = const [];
      }

      return Result.success(orders);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to load available orders: $e'),
      );
    }
  }

  @override
  Future<Result<RiderOrderModel?>> getActiveOrder() async {
    try {
      final response = await _apiClient.get<dynamic>('/drivers/orders/active');

      if (response.data == null || (response.data is String && (response.data as String).isEmpty)) {
        return Result.success(null);
      }

      if (response.data is Map<String, dynamic>) {
        final orderJson = response.data as Map<String, dynamic>;
        if (orderJson.isEmpty || orderJson['id'] == null) {
          return Result.success(null);
        }
        return Result.success(RiderOrderModel.fromJson(orderJson));
      }

      return Result.success(null);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to load active order: $e'),
      );
    }
  }

  @override
  Future<Result<RiderOrderModel>> acceptOrder(String orderId) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/drivers/orders/$orderId/accept',
      );

      return Result.success(RiderOrderModel.fromJson(response.data));
    } on ConflictException catch (e) {
      // 409: DRIVER_BUSY or ORDER_UNAVAILABLE
      return Result.failure(ConflictFailure(message: e.message));
    } on NotFoundException catch (e) {
      return Result.failure(NotFoundFailure(message: e.message));
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to accept order: $e'),
      );
    }
  }

  @override
  Future<Result<RiderOrderModel>> markDelivered(String orderId) async {
    try {
      final response = await _apiClient.patch<Map<String, dynamic>>(
        '/drivers/orders/$orderId/status',
        body: {'status': 'DELIVERED'},
      );

      return Result.success(RiderOrderModel.fromJson(response.data));
    } on ForbiddenException catch (e) {
      // 403: order assigned to a different driver
      return Result.failure(ForbiddenFailure(message: e.message));
    } on NotFoundException catch (e) {
      return Result.failure(NotFoundFailure(message: e.message));
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to mark order as delivered: $e'),
      );
    }
  }
}
