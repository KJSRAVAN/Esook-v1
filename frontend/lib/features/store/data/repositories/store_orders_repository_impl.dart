import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../../customer/domain/models/order_model.dart';
import '../../domain/repositories/store_orders_repository.dart';

/// Concrete implementation of [StoreOrdersRepository] interacting with `/orders` and `/orders/:orderId/status`.
class StoreOrdersRepositoryImpl implements StoreOrdersRepository {
  final ApiClient _apiClient;

  const StoreOrdersRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<Result<List<OrderModel>>> getStoreOrders({
    required String storeId,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (status != null &&
            status.isNotEmpty &&
            status.toUpperCase() != 'ALL')
          'status': OrderStatus.fromString(status).toBackendString(),
      };

      final response = await _apiClient.get<dynamic>(
        '/orders/store/$storeId',
        queryParameters: queryParams,
      );

      final dynamic rawData = response.data;
      final List<dynamic> rawList;

      if (rawData is Map<String, dynamic>) {
        if (rawData['orders'] is List) {
          rawList = rawData['orders'] as List;
        } else if (rawData['data'] is List) {
          rawList = rawData['data'] as List;
        } else {
          rawList = const [];
        }
      } else if (rawData is List) {
        rawList = rawData;
      } else {
        rawList = const [];
      }

      var orders = rawList
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList();

      if (status != null &&
          status.isNotEmpty &&
          status.toUpperCase() != 'ALL') {
        final targetStatus = OrderStatus.fromString(status);
        orders = orders.where((o) => o.status == targetStatus).toList();
      }

      return Result.success(orders);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to fetch store orders: $e'),
      );
    }
  }

  @override
  Future<Result<OrderModel>> getOrderById(String orderId) async {
    try {
      final response = await _apiClient.get<dynamic>('/orders/$orderId');
      final dynamic rawData = response.data;
      final Map<String, dynamic> rawOrder;

      if (rawData is Map<String, dynamic>) {
        if (rawData['order'] is Map<String, dynamic>) {
          rawOrder = rawData['order'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawOrder = rawData['data'] as Map<String, dynamic>;
        } else {
          rawOrder = rawData;
        }
      } else {
        rawOrder = const {};
      }

      final order = OrderModel.fromJson(rawOrder);
      return Result.success(order);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to fetch order: $e'),
      );
    }
  }

  @override
  Future<Result<OrderModel>> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    String? rejectedReason,
  }) async {
    try {
      final body = <String, dynamic>{
        'status': status.toBackendString(),
        if (rejectedReason != null && rejectedReason.trim().isNotEmpty)
          'rejectedReason': rejectedReason.trim(),
      };

      final response = await _apiClient.patch<dynamic>(
        '/orders/$orderId/status',
        body: body,
      );

      final dynamic rawData = response.data;
      final Map<String, dynamic> rawOrder;

      if (rawData is Map<String, dynamic>) {
        if (rawData['order'] is Map<String, dynamic>) {
          rawOrder = rawData['order'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawOrder = rawData['data'] as Map<String, dynamic>;
        } else {
          rawOrder = rawData;
        }
      } else {
        rawOrder = const {};
      }

      final order = OrderModel.fromJson(rawOrder);
      return Result.success(order);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to update order status: $e'),
      );
    }
  }
}
