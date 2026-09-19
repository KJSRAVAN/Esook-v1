import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/rider_order_model.dart';
import '../../domain/repositories/rider_repository.dart';

/// Production implementation of [RiderRepository].
///
/// Communicates with production backend order endpoints:
/// - GET   /orders
/// - PATCH /orders/:id/status
class RiderRepositoryImpl implements RiderRepository {
  final ApiClient _apiClient;

  RiderRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<List<RiderOrderModel>>> getAvailableOrders() async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/drivers/orders/available',
      );

      final dynamic rawData = response.data;
      final List<dynamic> rawList;

      if (rawData is List) {
        rawList = rawData;
      } else if (rawData is Map<String, dynamic>) {
        if (rawData['data'] is List) {
          rawList = rawData['data'] as List;
        } else if (rawData['orders'] is List) {
          rawList = rawData['orders'] as List;
        } else {
          rawList = const [];
        }
      } else {
        rawList = const [];
      }

      final orders = rawList
          .whereType<Map<String, dynamic>>()
          .map(RiderOrderModel.fromJson)
          .toList();

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

      final dynamic rawData = response.data;
      if (rawData == null) {
        return Result.success(null);
      }

      final Map<String, dynamic> rawOrder;
      if (rawData is Map<String, dynamic>) {
        if (rawData.isEmpty) {
          return Result.success(null);
        }
        if (rawData['order'] is Map<String, dynamic>) {
          rawOrder = rawData['order'] as Map<String, dynamic>;
        } else if (rawData['data'] is Map<String, dynamic>) {
          rawOrder = rawData['data'] as Map<String, dynamic>;
        } else {
          rawOrder = rawData;
        }
      } else {
        return Result.success(null);
      }

      return Result.success(RiderOrderModel.fromJson(rawOrder));
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
      final response = await _apiClient.post<dynamic>(
        '/drivers/orders/$orderId/accept',
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

      return Result.success(RiderOrderModel.fromJson(rawOrder));
    } on ConflictException catch (e) {
      return Result.failure(ConflictFailure(message: e.message));
    } on NotFoundException catch (e) {
      return Result.failure(NotFoundFailure(message: e.message));
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to start delivery: $e'),
      );
    }
  }

  @override
  Future<Result<RiderOrderModel>> markDelivered(String orderId) async {
    try {
      final response = await _apiClient.patch<dynamic>(
        '/drivers/orders/$orderId/status',
        body: {'status': 'DELIVERED'},
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

      return Result.success(RiderOrderModel.fromJson(rawOrder));
    } on ForbiddenException catch (e) {
      return Result.failure(ForbiddenFailure(message: e.message));
    } on NotFoundException catch (e) {
      return Result.failure(NotFoundFailure(message: e.message));
    } on AppException catch (e) {
      return Result.failure(AppFailure.fromException(e));
    } catch (e) {
      return Result.failure(
        UnknownFailure(message: 'Failed to complete delivery: $e'),
      );
    }
  }
}
