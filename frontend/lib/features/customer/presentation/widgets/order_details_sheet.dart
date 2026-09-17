import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../screens/customer_order_tracking_screen.dart';

/// Modal bottom sheet displaying granular order details and tracking status.
class OrderDetailsSheet extends StatefulWidget {
  final OrderModel initialOrder;
  final OrderRepository? orderRepository;
  final String currency;

  const OrderDetailsSheet({
    super.key,
    required this.initialOrder,
    this.orderRepository,
    this.currency = AppConstants.defaultCurrency,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    OrderRepository? orderRepository,
    String currency = AppConstants.defaultCurrency,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderDetailsSheet(
        initialOrder: order,
        orderRepository: orderRepository,
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
  String? _errorMessage;

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
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.85,
      ),
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
                        if (_order.storeName != null && _order.storeName!.isNotEmpty)
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
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
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
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 40.0, color: AppColors.error),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      _errorMessage!,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
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
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
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
                          const Text('Placed At', style: AppTextStyles.bodyMedium),
                          Text(
                            _formatDate(_order.createdAt),
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppDimensions.spacingLg),

                    // Fulfillment & Delivery Details
                    Text(
                      'Fulfillment Details',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingMd),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
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
                                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          if (_order.fulfillment == FulfillmentType.delivery &&
                              _order.deliveryAddress != null &&
                              _order.deliveryAddress!.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingXs),
                            Text(
                              _order.deliveryAddress!,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                          if (_order.notes != null && _order.notes!.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingSm),
                            Text(
                              'Notes: ${_order.notes}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (_order.rejectedReason != null && _order.rejectedReason!.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingSm),
                            Text(
                              'Rejection reason: ${_order.rejectedReason}',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),

                    // Items list
                    Text(
                      'Items (${_order.itemCount})',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingMd),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          if (_order.items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(AppDimensions.spacingSm),
                              child: Text(
                                'No item details available.',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                              ),
                            )
                          else
                            ..._order.items.map((item) => Padding(
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
                                )),
                          const Divider(height: 16.0, color: AppColors.borderSubtle),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal', style: AppTextStyles.bodyMedium),
                              Text(
                                '${_order.subtotal.toStringAsFixed(2)} ${widget.currency}',
                                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (_order.discount > 0) ...[
                            const SizedBox(height: 4.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Discount', style: AppTextStyles.bodyMedium),
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
                          if (_order.deliveryFee > 0) ...[
                            const SizedBox(height: 4.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Delivery Fee', style: AppTextStyles.bodyMedium),
                                Text(
                                  '${_order.deliveryFee.toStringAsFixed(2)} ${widget.currency}',
                                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 16.0, color: AppColors.borderSubtle),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total', style: AppTextStyles.titleMedium),
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
                                const Icon(Icons.stars_rounded,
                                    size: 16.0, color: AppColors.warning),
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
                child: SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton.icon(
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
                    icon: const Icon(Icons.timeline_rounded, size: 20),
                    label: const Text(
                      'Track Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSm),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
