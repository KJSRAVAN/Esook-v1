import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/rider_order_model.dart';
import '../../domain/repositories/rider_repository.dart';
import '../widgets/rider_order_card.dart';

/// Screen displaying available READY delivery orders for the rider to accept.
///
/// Features pull-to-refresh, loading/error/empty states, and handles
/// 409 DRIVER_BUSY and ORDER_UNAVAILABLE error responses.
class RiderAvailableOrdersScreen extends StatefulWidget {
  final RiderRepository? riderRepository;
  final VoidCallback? onOrderAccepted;

  const RiderAvailableOrdersScreen({
    super.key,
    this.riderRepository,
    this.onOrderAccepted,
  });

  @override
  State<RiderAvailableOrdersScreen> createState() =>
      _RiderAvailableOrdersScreenState();
}

class _RiderAvailableOrdersScreenState
    extends State<RiderAvailableOrdersScreen> {
  List<RiderOrderModel> _orders = [];
  bool _isLoading = true;
  bool _isAccepting = false;
  String? _acceptingOrderId;
  AppFailure? _failure;

  RiderRepository get _repository {
    if (widget.riderRepository != null) return widget.riderRepository!;
    throw StateError('RiderRepository not provided');
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableOrders();
  }

  Future<void> _loadAvailableOrders() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });

    final result = await _repository.getAvailableOrders();

    if (!mounted) return;

    result.fold(
      onSuccess: (orders) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      },
      onFailure: (failure) {
        setState(() {
          _failure = failure;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _handleAcceptOrder(String orderId) async {
    setState(() {
      _isAccepting = true;
      _acceptingOrderId = orderId;
    });

    final result = await _repository.acceptOrder(orderId);

    if (!mounted) return;

    result.fold(
      onSuccess: (_) {
        setState(() {
          _isAccepting = false;
          _acceptingOrderId = null;
          // Remove the accepted order from the list
          _orders.removeWhere((o) => o.id == orderId);
        });
        widget.onOrderAccepted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted! Check Active Delivery tab.'),
            backgroundColor: AppColors.success,
          ),
        );
      },
      onFailure: (failure) {
        setState(() {
          _isAccepting = false;
          _acceptingOrderId = null;
        });

        String message = failure.message;
        bool shouldRefresh = false;

        if (failure is ConflictFailure) {
          // 409: Could be DRIVER_BUSY or ORDER_UNAVAILABLE
          if (message.toLowerCase().contains('active delivery') ||
              message.toLowerCase().contains('busy')) {
            message =
                'You already have an active delivery. Complete it before accepting another.';
          } else {
            message = 'This order is no longer available.';
            shouldRefresh = true;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
          ),
        );

        // Refresh the list if the order was unavailable
        if (shouldRefresh) {
          _loadAvailableOrders();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Available Orders'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('rider_available_refresh_btn'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadAvailableOrders,
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_failure != null) {
      return Center(
        child: Padding(
          padding: AppDimensions.paddingScreen,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                _failure!.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              OutlinedButton.icon(
                onPressed: _loadAvailableOrders,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Padding(
          padding: AppDimensions.paddingScreen,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusXl),
                ),
                child: const Icon(
                  Icons.inbox_rounded,
                  size: 40,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              Text(
                'No Orders Available',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'All delivery orders have been claimed.\nPull down to refresh.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              OutlinedButton.icon(
                onPressed: _loadAvailableOrders,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAvailableOrders,
      color: AppColors.primary,
      child: ListView.builder(
        padding: AppDimensions.paddingScreen,
        itemCount: _orders.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
              child: Text(
                '${_orders.length} order${_orders.length == 1 ? '' : 's'} available',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          final order = _orders[index - 1];
          final isThisAccepting =
              _isAccepting && _acceptingOrderId == order.id;

          return RiderOrderCard(
            key: Key('rider_available_card_${order.id}'),
            order: order,
            actionLabel: 'Accept Delivery',
            onAction: _isAccepting ? null : () => _handleAcceptOrder(order.id),
            isActionLoading: isThisAccepting,
          );
        },
      ),
    );
  }
}
