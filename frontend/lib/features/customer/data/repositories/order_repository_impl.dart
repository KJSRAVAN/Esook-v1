import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/order_item_model.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';

/// Concrete [OrderRepository] communicating with backend /orders endpoints.
class OrderRepositoryImpl implements OrderRepository {
  final ApiClient _apiClient;

  const OrderRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<OrderModel>> createOrder({
    required String storeId,
    required FulfillmentType fulfillment,
    String? deliveryAddress,
    String? couponCode,
    String? notes,
    required List<OrderItemInput> items,
    String? idempotencyKey,
  }) async {
    try {
      final headers = <String, String>{
        if (idempotencyKey != null && idempotencyKey.isNotEmpty)
          'X-Idempotency-Key': idempotencyKey,
      };

      final body = <String, dynamic>{
        'store_id': storeId,
        'fulfillment_type': fulfillment == FulfillmentType.pickup ? 'pickup' : 'delivery',
        if (fulfillment == FulfillmentType.delivery &&
            deliveryAddress != null &&
            deliveryAddress.trim().isNotEmpty)
          'delivery_address': deliveryAddress.trim(),
        if (couponCode != null && couponCode.trim().isNotEmpty)
          'coupon_code': couponCode.trim(),
        if (notes != null && notes.trim().isNotEmpty)
          'notes': notes.trim(),
      };

      final response = await _apiClient.post<dynamic>(
        '/orders',
        body: body,
        headers: headers.isNotEmpty ? headers : null,
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
        rawOrder = {};
      }

      final order = OrderModel.fromJson(rawOrder);
      return Result.success(order);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to place order: $e'));
    }
  }

  @override
  Future<Result<List<OrderModel>>> getMyOrders({
    int? page,
    int? limit,
    OrderStatus? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (page != null) 'page': page,
        if (limit != null) 'limit': limit,
        if (status != null) 'status': status.toBackendString(),
      };

      final response = await _apiClient.get<dynamic>(
        '/orders',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final dynamic rawData = response.data;
      final List<dynamic> rawList;
      if (rawData is Map<String, dynamic>) {
        if (rawData['orders'] is List<dynamic>) {
          rawList = rawData['orders'] as List<dynamic>;
        } else if (rawData['data'] is List<dynamic>) {
          rawList = rawData['data'] as List<dynamic>;
        } else {
          rawList = const [];
        }
      } else if (rawData is List<dynamic>) {
        rawList = rawData;
      } else {
        rawList = const [];
      }

      final orders = rawList
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList();

      return Result.success(orders);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to retrieve orders: $e'));
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
        rawOrder = {};
      }

      final order = OrderModel.fromJson(rawOrder);
      return Result.success(order);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: 'Failed to retrieve order details: $e'));
    }
  }
}
