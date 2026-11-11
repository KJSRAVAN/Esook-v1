import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../cart/application/cart_notifier.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../screens/customer_order_tracking_screen.dart';
import 'customer_scope.dart';

/// Modal bottom sheet displaying granular order details and tracking status.
class OrderDetailsSheet extends StatefulWidget {
  final OrderModel initialOrder;
  final OrderRepository? orderRepository;
  final CartNotifier? cartNotifier;
  final String currency;

  const OrderDetailsSheet({
    super.key,
    required this.initialOrder,
    this.orderRepository,
    this.cartNotifier,
    this.currency = AppConstants.defaultCurrency,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    OrderRepository? orderRepository,
    CartNotifier? cartNotifier,
    String currency = AppConstants.defaultCurrency,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderDetailsSheet(
        initialOrder: order,
        orderRepository: orderRepository,
        cartNotifier: cartNotifier,
        currency: currency,
      ),
    );
  }

  @override
  State<OrderDetailsSheet> createState() => _OrderDetailsSheetState();
}

class _OrderDetailsSheetState extends State<OrderDetailsSheet> {
  late OrderModel _order;
  bool _isLoading = false;
  bool _isCancelling = false;
  bool _isReordering = false;
  String? _errorMessage;

  bool get _isCancellable =>
      _order.status == OrderStatus.pending ||
      _order.status == OrderStatus.accepted;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    if (widget.orderRepository != null && _order.items.isEmpty) {
      _refreshOrder();
    }
  }

  Future<void> _refreshOrder() async {
    if (widget.orderRepository == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.orderRepository!.getOrderById(_order.id);
    if (!mounted) return;

    result.fold(
      onSuccess: (updated) {
        setState(() {
          _order = updated;
          _isLoading = false;
        });
      },
      onFailure: (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
    );
  }

  Future<void> _promptCancelOrderDialog() async {
    if (_isCancelling || !_isCancellable || widget.orderRepository == null) {
      return;
    }

    final reasonController = TextEditingController();
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          key: const Key('details_cancel_order_dialog'),
          title: const Text('Cancel Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to cancel this order?'),
              const SizedBox(height: AppDimensions.spacingMd),
              TextField(
                key: const Key('details_cancel_order_reason_input'),
                controller: reasonController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Reason for cancellation (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Keep Order'),
            ),
            ElevatedButton(
              key: const Key('details_confirm_cancel_order_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Cancel Order'),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true && mounted) {
      final reason = reasonController.text.trim();
      setState(() {
        _isCancelling = true;
      });

      final result = await widget.orderRepository!.cancelOrder(
        orderId: _order.id,
        cancelReason: reason.isNotEmpty ? reason : null,
      );

      if (!mounted) return;

      result.fold(
        onSuccess: (updatedOrder) {
          setState(() {
            _order = updatedOrder;
            _isCancelling = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order cancelled successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        },
        onFailure: (failure) {
          setState(() {
            _isCancelling = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: AppColors.error,
            ),
          );
          _refreshOrder();
        },
      );
    }
  }

  Future<void> _handleReorder() async {
    if (_isReordering) return;

    final notifier =
        widget.cartNotifier ?? CustomerScope.maybeOf(context)?.cartNotifier;
    if (notifier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart service is not available.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isReordering = true;
    });

    try {
      OrderModel orderToUse = _order;
      if (orderToUse.items.isEmpty && widget.orderRepository != null) {
        final result = await widget.orderRepository!.getOrderById(_order.id);
        if (result.isSuccess && result.dataOrNull != null) {
          orderToUse = result.dataOrNull!;
          if (mounted) {
            setState(() {
              _order = orderToUse;
            });
          }
        }
      }

      if (orderToUse.items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No item details available to reorder.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      await notifier.loadForStore(orderToUse.storeId);

      int addedCount = 0;
      for (final item in orderToUse.items) {
        await notifier.addItem(item.itemId, item.quantity);
        addedCount++;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$addedCount item(s) added to cart from Order #${orderToUse.orderNumber ?? orderToUse.id}. Review your cart to proceed.',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reorder items: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isReordering = false;
        });
      }
    }
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
        return const Color(0xFF7C3AED);
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return AppColors.error;
    }
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final statusColor = _getStatusColor(_order.status);
    final displayId = _order.orderNumber?.isNotEmpty == true
        ? _order.orderNumber!
        : (_order.id.length > 8 ? _order.id.substring(0, 8) : _order.id);

    return Container(
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                width: 40.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingLg,
                vertical: AppDimensions.spacingSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #$displayId',
                          style: AppTextStyles.headlineSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_order.storeName != null &&
                            _order.storeName!.isNotEmpty)
                          Text(
                            _order.storeName!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1.0, color: AppColors.borderSubtle),

            // Body
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(AppDimensions.spacingXl),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 40.0,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      _errorMessage!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    ElevatedButton(
                      onPressed: _refreshOrder,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.all(AppDimensions.spacingLg),
                  children: [
                    // Status row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status', style: AppTextStyles.titleMedium),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacingSm,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSm,
                            ),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _order.status.displayName,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_order.createdAt != null) ...[
                      const SizedBox(height: AppDimensions.spacingSm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Placed At',
                            style: AppTextStyles.bodyMedium,
                          ),
                          Text(
                            _formatDate(_order.createdAt),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppDimensions.spacingLg),

                    // Fulfillment & Delivery Details
                    Text(
                      'Fulfillment Details',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingMd),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _order.fulfillment == FulfillmentType.delivery
                                    ? Icons.delivery_dining_outlined
                                    : Icons.storefront_outlined,
                                size: 20.0,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppDimensions.spacingSm),
                              Text(
                                _order.fulfillment.displayName,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (_order.fulfillment == FulfillmentType.delivery &&
                              _order.deliveryAddress != null &&
                              _order.deliveryAddress!.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingXs),
                            Text(
                              _order.deliveryAddress!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (_order.notes != null &&
                              _order.notes!.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingSm),
                            Text(
                              'Notes: ${_order.notes}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (_order.rejectedReason != null &&
                              _order.rejectedReason!.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingSm),
                            Text(
                              'Rejection reason: ${_order.rejectedReason}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppDimensions.spacingSm),
                          const Divider(height: 1.0, color: AppColors.borderSubtle),
                          const SizedBox(height: AppDimensions.spacingSm),
                          Row(
                            children: [
                              Icon(
                                _order.paymentMethod == PaymentMethod.card
                                    ? Icons.credit_card_rounded
                                    : Icons.payments_outlined,
                                size: 18.0,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppDimensions.spacingSm),
                              Text(
                                'Payment Method: ',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _order.paymentMethod.displayName,
                                key: const Key('order_details_payment_method'),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),

                    // Items list
                    Text(
                      'Items (${_order.itemCount})',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingMd),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          if (_order.items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(
                                AppDimensions.spacingSm,
                              ),
                              child: Text(
                                'No item details available.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            )
                          else
                            ..._order.items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                          const Divider(
                            height: 16.0,
                            color: AppColors.borderSubtle,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Subtotal',
                                style: AppTextStyles.bodyMedium,
                              ),
                              Text(
                                '${_order.subtotal.toStringAsFixed(2)} ${widget.currency}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (_order.discount > 0) ...[
                            const SizedBox(height: 4.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Discount',
                                  style: AppTextStyles.bodyMedium,
                                ),
                                Text(
                                  '-${_order.discount.toStringAsFixed(2)} ${widget.currency}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_order.pointsDiscount > 0) ...[
                            const SizedBox(height: 4.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _order.redeemedPoints > 0
                                      ? 'Points Discount (${_order.redeemedPoints} pts)'
                                      : 'Points Discount',
                                  style: AppTextStyles.bodyMedium,
                                ),
                                Text(
                                  '-${_order.pointsDiscount.toStringAsFixed(2)} ${widget.currency}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_order.deliveryFee > 0) ...[
                            const SizedBox(height: 4.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Delivery Fee',
                                  style: AppTextStyles.bodyMedium,
                                ),
                                Text(
                                  '${_order.deliveryFee.toStringAsFixed(2)} ${widget.currency}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Divider(
                            height: 16.0,
                            color: AppColors.borderSubtle,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: AppTextStyles.titleMedium,
                              ),
                              Text(
                                '${_order.total.toStringAsFixed(2)} ${widget.currency}',
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                          if (_order.pointsEarned > 0) ...[
                            const SizedBox(height: AppDimensions.spacingSm),
                            Row(
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  size: 16.0,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  '+${_order.pointsEarned} loyalty points earned',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (!_isLoading &&
                _errorMessage == null &&
                widget.orderRepository != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingLg,
                  vertical: AppDimensions.spacingSm,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                child: Row(
                  children: [
                    if (_isCancellable) ...[
                      Expanded(
                        child: SizedBox(
                          height: AppDimensions.buttonHeight,
                          child: OutlinedButton.icon(
                            key: const Key('order_details_cancel_order_button'),
                            onPressed: _isCancelling ? null : _promptCancelOrderDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusSm,
                                ),
                              ),
                            ),
                            icon: _isCancelling
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.error,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.cancel_outlined, size: 18),
                            label: Text(
                              _isCancelling ? 'Cancelling…' : 'Cancel Order',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: AppDimensions.buttonHeight,
                        child: OutlinedButton.icon(
                          key: const Key('order_details_track_order_button'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CustomerOrderTrackingScreen(
                                  orderId: _order.id,
                                  initialOrder: _order,
                                  orderRepository: widget.orderRepository!,
                                  currency: widget.currency,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.timeline_rounded, size: 18),
                          label: const Text(
                            'Track',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSm,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: SizedBox(
                        height: AppDimensions.buttonHeight,
                        child: ElevatedButton.icon(
                          key: const Key('order_details_reorder_button'),
                          onPressed: _isReordering ? null : _handleReorder,
                          icon: _isReordering
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.replay_rounded, size: 18),
                          label: Text(
                            _isReordering ? 'Adding…' : 'Reorder',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSm,
                              ),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
