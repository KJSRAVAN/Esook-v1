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

  const OrderRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<Result<OrderModel>> createOrder({
    required String storeId,
    required FulfillmentType fulfillment,
    required PaymentMethod paymentMethod,
    String? deliveryAddress,
    String? couponCode,
    int? redeemPoints,
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
        'storeId': storeId,
        'fulfillment': fulfillment == FulfillmentType.pickup
            ? 'PICKUP'
            : 'DELIVERY',
        'paymentMethod': paymentMethod.toBackendString(),
        if (fulfillment == FulfillmentType.delivery &&
            deliveryAddress != null &&
            deliveryAddress.trim().isNotEmpty)
          'deliveryAddress': deliveryAddress.trim(),
        if (couponCode != null && couponCode.trim().isNotEmpty)
          'couponCode': couponCode.trim(),
        if (redeemPoints != null && redeemPoints > 0)
          'redeemPoints': redeemPoints,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'items': items.map((i) => i.toJson()).toList(),
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
      return Result.failure(
        UnknownFailure(message: 'Failed to place order: $e'),
      );
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
        '/orders/my',
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
      return Result.failure(
        UnknownFailure(message: 'Failed to retrieve orders: $e'),
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
        rawOrder = {};
      }

      final order = OrderModel.fromJson(rawOrder);
      return Result.success(order);
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to retrieve order details: $e'),
      );
    }
  }

  @override
  Future<Result<OrderModel>> cancelOrder({
    required String orderId,
    String? cancelReason,
  }) async {
    try {
      final body = <String, dynamic>{
        if (cancelReason != null && cancelReason.trim().isNotEmpty)
          'cancelReason': cancelReason.trim(),
      };

      final response = await _apiClient.post<dynamic>(
        '/orders/$orderId/cancel',
        body: body.isNotEmpty ? body : null,
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
      return Result.failure(
        UnknownFailure(message: 'Failed to cancel order: $e'),
      );
    }
  }

  @override
  Future<Result<CustomerPointsInfo>> getStorePointsInfo(String storeId) async {
    try {
      final cleanStoreId = storeId.trim();
      if (cleanStoreId.isEmpty) {
        return Result.success(const CustomerPointsInfo(isEnabled: false));
      }

      bool isEnabled = false;
      double rate = 0.10;
      int balance = 0;
      int minPoints = 0;
      double maxDiscount = 100.0;
      int? maxPoints;
      double earnedRate = 1.0;

      double parseDouble(dynamic val, double fallback) {
        if (val is num) return val.toDouble();
        if (val != null) return double.tryParse(val.toString()) ?? fallback;
        return fallback;
      }

      int parseInt(dynamic val, int fallback) {
        if (val is num) return val.toInt();
        if (val != null) return int.tryParse(val.toString()) ?? fallback;
        return fallback;
      }

      int? parseNullableInt(dynamic val) {
        if (val is num) return val.toInt();
        if (val != null) return int.tryParse(val.toString());
        return null;
      }

      try {
        final configRes = await _apiClient.get<dynamic>(
          '/stores/$cleanStoreId/points/config',
        );
        if (configRes.data is Map<String, dynamic>) {
          final data = configRes.data as Map<String, dynamic>;
          final rawEnabled = data['isEnabled'];
          if (rawEnabled is bool) {
            isEnabled = rawEnabled;
          } else if (rawEnabled != null) {
            isEnabled = rawEnabled.toString().toLowerCase() == 'true';
          } else {
            isEnabled = true;
          }

          rate = parseDouble(data['pointsPerCurrencyUnit'], 0.10);
          earnedRate = parseDouble(data['pointsEarnedPerCurrency'], 1.0);
          minPoints = parseInt(data['minPointsToRedeem'], 0);
          maxDiscount = parseDouble(data['maxDiscountPercent'], 100.0);
          maxPoints = parseNullableInt(data['maxPointsPerOrder']);
        }
      } catch (_) {
        // Points config may be null if unconfigured
      }

      try {
        final balRes = await _apiClient.get<dynamic>(
          '/stores/$cleanStoreId/points/my-balance',
        );
        if (balRes.data is Map<String, dynamic>) {
          final data = balRes.data as Map<String, dynamic>;
          balance = parseInt(data['balance'], 0);
        }
      } catch (_) {
        // User may have no balance record yet
      }

      return Result.success(
        CustomerPointsInfo(
          isEnabled: isEnabled,
          pointsPerCurrencyUnit: rate,
          balance: balance,
          minPointsToRedeem: minPoints,
          maxDiscountPercent: maxDiscount,
          maxPointsPerOrder: maxPoints,
          pointsEarnedPerCurrency: earnedRate,
        ),
      );
    } catch (e) {
      return Result.success(const CustomerPointsInfo());
    }
  }
}
