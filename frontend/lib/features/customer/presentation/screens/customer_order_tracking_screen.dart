import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';

/// Screen presenting real-time status-based order tracking and full order breakdown.
///
/// Features:
/// - Delivery vs Pickup timeline stepper.
/// - Active foreground polling every 10 seconds, safely stopped on terminal states or dispose.
/// - Terminal banners for Rejected (with reason) and Cancelled orders.
/// - Itemized order summary and fulfillment details.
/// - Manual refresh & pull-to-refresh.
class CustomerOrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final OrderModel? initialOrder;
  final OrderRepository orderRepository;
  final String currency;

  const CustomerOrderTrackingScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
    required this.orderRepository,
    this.currency = AppConstants.defaultCurrency,
  });

  @override
  State<CustomerOrderTrackingScreen> createState() =>
      _CustomerOrderTrackingScreenState();
}

class _CustomerOrderTrackingScreenState
    extends State<CustomerOrderTrackingScreen> {
  OrderModel? _order;
  bool _isLoading = false;
  bool _isPolling = false;
  bool _isFetching = false;
  String? _errorMessage;
  Timer? _pollTimer;

  bool get _isTerminalState =>
      _order?.status == OrderStatus.delivered ||
      _order?.status == OrderStatus.cancelled ||
      _order?.status == OrderStatus.rejected;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    if (_order == null) {
      _fetchOrder(initial: true);
    } else {
      _fetchOrder(initial: false);
      if (!_isTerminalState) {
        _startPolling();
      }
    }
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _startPolling() {
    _stopPolling();
    if (_isTerminalState) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchOrder(isBackgroundPoll: true);
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchOrder({
    bool initial = false,
    bool isBackgroundPoll = false,
  }) async {
    if (_isFetching) return;
    _isFetching = true;

    if (initial && _order == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (!isBackgroundPoll) {
      setState(() {
        _isPolling = true;
      });
    }

    final result = await widget.orderRepository.getOrderById(widget.orderId);
    _isFetching = false;

    if (!mounted) return;

    result.fold(
      onSuccess: (updatedOrder) {
        setState(() {
          _order = updatedOrder;
          _isLoading = false;
          _isPolling = false;
          _errorMessage = null;
        });

        if (_isTerminalState) {
          _stopPolling();
        } else if (_pollTimer == null) {
          _startPolling();
        }
      },
      onFailure: (failure) {
        setState(() {
          _isLoading = false;
          _isPolling = false;
          if (_order == null) {
            _errorMessage = failure.message;
          }
        });

        if (_order != null) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update tracking: ${failure.message}'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return AppColors.info;
      case OrderStatus.ready:
      case OrderStatus.outForDelivery:
        return const Color(0xFF7C3AED); // Purple
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Track Order'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (_order != null || _errorMessage != null)
            IconButton(
              key: const Key('tracking_refresh_button'),
              icon: _isPolling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              onPressed: _isLoading || _isPolling
                  ? null
                  : () => _fetchOrder(isBackgroundPoll: false),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _order == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null && _order == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'Unable to load order details',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              ElevatedButton.icon(
                key: const Key('tracking_retry_button'),
                onPressed: () => _fetchOrder(initial: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_order == null) {
      return const SizedBox.shrink();
    }

    final order = _order!;
    final displayId = order.orderNumber?.isNotEmpty == true
        ? order.orderNumber!
        : (order.id.length > 8 ? order.id.substring(0, 8) : order.id);

    return RefreshIndicator(
      onRefresh: () => _fetchOrder(isBackgroundPoll: false),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Order Overview Card
                _buildOverviewCard(order, displayId),
                const SizedBox(height: AppDimensions.spacingMd),

                // Terminal status banner if cancelled or rejected
                if (order.status == OrderStatus.rejected)
                  _buildRejectionBanner(order)
                else if (order.status == OrderStatus.cancelled)
                  _buildCancelledBanner(order),

                if (order.status == OrderStatus.rejected ||
                    order.status == OrderStatus.cancelled)
                  const SizedBox(height: AppDimensions.spacingMd),

                // Status Timeline
                _buildTimelineCard(order),
                const SizedBox(height: AppDimensions.spacingMd),

                // Fulfillment & Address Card
                _buildFulfillmentCard(order),
                const SizedBox(height: AppDimensions.spacingMd),

                // Order Items & Pricing Card
                _buildOrderItemsCard(order),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(OrderModel order, String displayId) {
    final statusColor = _getStatusColor(order.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #$displayId',
                        key: const Key('tracking_order_id'),
                        style: AppTextStyles.headlineSmall.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (order.storeName != null &&
                          order.storeName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          order.storeName!,
                          key: const Key('tracking_store_name'),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    order.status.displayName,
                    key: const Key('tracking_status_badge'),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: AppDimensions.spacingSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      order.fulfillment == FulfillmentType.delivery
                          ? Icons.delivery_dining_outlined
                          : Icons.storefront_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      order.fulfillment.displayName,
                      key: const Key('tracking_fulfillment_type'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (order.createdAt != null)
                  Text(
                    _formatDate(order.createdAt),
                    key: const Key('tracking_order_date'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionBanner(OrderModel order) {
    return Container(
      key: const Key('tracking_rejection_banner'),
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel_outlined, color: AppColors.error, size: 24),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Rejected',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.rejectedReason != null &&
                          order.rejectedReason!.trim().isNotEmpty
                      ? order.rejectedReason!
                      : 'The store was unable to accept this order.',
                  key: const Key('tracking_rejection_reason'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledBanner(OrderModel order) {
    return Container(
      key: const Key('tracking_cancelled_banner'),
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        children: [
          Icon(Icons.remove_circle_outline, color: Color(0xFFD97706), size: 24),
          SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Cancelled',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'This order has been cancelled and will not be fulfilled.',
                  style: TextStyle(fontSize: 13, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(OrderModel order) {
    final isDelivery = order.fulfillment == FulfillmentType.delivery;

    final steps = isDelivery
        ? const [
            _TimelineStepDef(
              status: OrderStatus.pending,
              title: 'Order Placed',
              description: 'We have received your order',
              icon: Icons.receipt_long_outlined,
            ),
            _TimelineStepDef(
              status: OrderStatus.accepted,
              title: 'Order Accepted',
              description: 'Store confirmed your order',
              icon: Icons.thumb_up_alt_outlined,
            ),
            _TimelineStepDef(
              status: OrderStatus.preparing,
              title: 'Preparing',
              description: 'Your items are being packed',
              icon: Icons.inventory_2_outlined,
            ),
            _TimelineStepDef(
              status: OrderStatus.ready,
              title: 'Ready for Driver',
              description: 'Packed and waiting for rider pickup',
              icon: Icons.shopping_bag_outlined,
            ),
            _TimelineStepDef(
              status: OrderStatus.outForDelivery,
              title: 'Out for Delivery',
              description: 'Rider is on the way to your address',
              icon: Icons.delivery_dining_outlined,
            ),
            _TimelineStepDef(
              status: OrderStatus.delivered,
              title: 'Delivered',
              description: 'Order successfully completed',
              icon: Icons.task_alt_outlined,
            ),
          ]
        : const [
            _TimelineStepDef(
              status: OrderStatus.pending,
              title: 'Order Placed',
              description: 'We have received your order',
              icon: Icons.receipt_long_outlined,
            ),
            _TimelineStepDef(
              status: OrderStatus.accepted,
              title: 'Order Accepted',
              description: 'Store confirmed your order',
              icon: Icons.thumb_up_alt_outlined,
            ),
            _TimelineStepDef(
              status: OrderStatus.preparing,
              title: 'Preparing',
              description: 'Your items are being prepared',
              icon: Icons.inventory_2_outlined,
            ),
            _TimelineStepDef(
              status: OrderStatus.ready,
              title: 'Ready for Pickup',
              description: 'Your order is ready at the store',
              icon: Icons.store_mall_directory_outlined,
            ),
            _TimelineStepDef(
              status: OrderStatus.delivered,
              title: 'Completed',
              description: 'Order picked up and completed',
              icon: Icons.task_alt_outlined,
            ),
          ];

    int activeIndex = _calculateStepIndex(order.status, isDelivery);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Order Progress', style: AppTextStyles.titleMedium),
                if (!_isTerminalState)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusFull,
                      ),
                    ),
                    child: const Text(
                      'Live Updates',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final step = steps[index];
                final isCompleted =
                    order.status != OrderStatus.rejected &&
                    order.status != OrderStatus.cancelled &&
                    index < activeIndex;
                final isCurrent =
                    order.status != OrderStatus.rejected &&
                    order.status != OrderStatus.cancelled &&
                    index == activeIndex;
                final isLast = index == steps.length - 1;

                return _buildTimelineTile(
                  step: step,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                  isLast: isLast,
                  order: order,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _calculateStepIndex(OrderStatus status, bool isDelivery) {
    if (isDelivery) {
      switch (status) {
        case OrderStatus.pending:
          return 0;
        case OrderStatus.accepted:
          return 1;
        case OrderStatus.preparing:
          return 2;
        case OrderStatus.ready:
          return 3;
        case OrderStatus.outForDelivery:
          return 4;
        case OrderStatus.delivered:
          return 5;
        case OrderStatus.rejected:
        case OrderStatus.cancelled:
          return -1;
      }
    } else {
      switch (status) {
        case OrderStatus.pending:
          return 0;
        case OrderStatus.accepted:
          return 1;
        case OrderStatus.preparing:
          return 2;
        case OrderStatus.ready:
          return 3;
        case OrderStatus.delivered:
          return 4;
        case OrderStatus.outForDelivery:
          return 3; // fallback for pickup
        case OrderStatus.rejected:
        case OrderStatus.cancelled:
          return -1;
      }
    }
  }

  Widget _buildTimelineTile({
    required _TimelineStepDef step,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
    required OrderModel order,
  }) {
    final Color circleColor;
    final Widget circleChild;

    if (isCompleted) {
      circleColor = AppColors.success;
      circleChild = const Icon(Icons.check, size: 16, color: Colors.white);
    } else if (isCurrent) {
      circleColor = AppColors.primary;
      circleChild = Icon(step.icon, size: 16, color: Colors.white);
    } else {
      circleColor = const Color(0xFFE2E8F0);
      circleChild = Icon(step.icon, size: 14, color: AppColors.textTertiary);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stepper column (circle + connecting line)
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(child: circleChild),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted
                    ? AppColors.success
                    : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: AppDimensions.spacingMd),

        // Title and description
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontWeight: isCurrent || isCompleted
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: 14,
                    color: isCurrent
                        ? AppColors.primary
                        : (isCompleted
                              ? AppColors.textPrimary
                              : AppColors.textTertiary),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrent
                        ? AppColors.textSecondary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFulfillmentCard(OrderModel order) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  order.fulfillment == FulfillmentType.delivery
                      ? Icons.local_shipping_outlined
                      : Icons.storefront_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  order.fulfillment == FulfillmentType.delivery
                      ? 'Delivery Details'
                      : 'Pickup Information',
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: AppDimensions.spacingSm),
            if (order.fulfillment == FulfillmentType.delivery) ...[
              if (order.deliveryAddress != null &&
                  order.deliveryAddress!.trim().isNotEmpty) ...[
                Text(
                  'Delivery Address',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.deliveryAddress!,
                  key: const Key('tracking_delivery_address'),
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
              ],
            ] else ...[
              Text(
                'Pickup Location',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                order.storeName ?? 'Selected Store',
                key: const Key('tracking_pickup_store'),
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
            ],
            if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
              Text(
                'Special Instructions / Notes',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                order.notes!,
                key: const Key('tracking_order_notes'),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemsCard(OrderModel order) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Items (${order.itemCount})',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: AppDimensions.spacingSm),
            if (order.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No item details available.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.quantity}x ${item.name}',
                          style: AppTextStyles.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${item.subtotal.toStringAsFixed(2)} ${widget.currency}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 16.0, color: AppColors.borderSubtle),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal', style: AppTextStyles.bodyMedium),
                Text(
                  '${order.subtotal.toStringAsFixed(2)} ${widget.currency}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (order.discount > 0) ...[
              const SizedBox(height: 4.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discount', style: AppTextStyles.bodyMedium),
                  Text(
                    '-${order.discount.toStringAsFixed(2)} ${widget.currency}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
            if (order.deliveryFee > 0) ...[
              const SizedBox(height: 4.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Delivery Fee', style: AppTextStyles.bodyMedium),
                  Text(
                    '${order.deliveryFee.toStringAsFixed(2)} ${widget.currency}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 16.0, color: AppColors.borderSubtle),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount', style: AppTextStyles.titleMedium),
                Text(
                  '${order.total.toStringAsFixed(2)} ${widget.currency}',
                  key: const Key('tracking_total_amount'),
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStepDef {
  final OrderStatus status;
  final String title;
  final String description;
  final IconData icon;

  const _TimelineStepDef({
    required this.status,
    required this.title,
    required this.description,
    required this.icon,
  });
}
