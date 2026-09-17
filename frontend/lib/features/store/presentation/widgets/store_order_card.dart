import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../customer/domain/models/order_model.dart';

/// Card widget displaying store order item summary for operations roster.
class StoreOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;
  final ValueChanged<OrderStatus>? onQuickStatusChange;

  const StoreOrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onQuickStatusChange,
  });

  Color _getStatusBgColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFEF3C7);
      case OrderStatus.accepted:
        return const Color(0xFFEFF6FF);
      case OrderStatus.preparing:
        return const Color(0xFFF5F3FF);
      case OrderStatus.ready:
        return const Color(0xFFFAF5FF);
      case OrderStatus.outForDelivery:
        return const Color(0xFFFFF7ED);
      case OrderStatus.delivered:
        return const Color(0xFFDCFCE7);
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return const Color(0xFFFEE2E2);
    }
  }

  Color _getStatusTextColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFB45309);
      case OrderStatus.accepted:
        return const Color(0xFF1D4ED8);
      case OrderStatus.preparing:
        return const Color(0xFF6D28D9);
      case OrderStatus.ready:
        return const Color(0xFF7E22CE);
      case OrderStatus.outForDelivery:
        return const Color(0xFFC2410C);
      case OrderStatus.delivered:
        return const Color(0xFF15803D);
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return const Color(0xFFB91C1C);
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final statusBg = _getStatusBgColor(order.status);
    final statusColor = _getStatusTextColor(order.status);
    final isPickup = order.fulfillment == FulfillmentType.pickup;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order Number + Status Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber ?? 'Order #${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length)}',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    ),
                    child: Text(
                      order.status.displayName,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSm),

              // Fulfillment & Time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPickup ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPickup ? Icons.shopping_bag_outlined : Icons.delivery_dining_outlined,
                          size: 14,
                          color: isPickup ? const Color(0xFF475569) : const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPickup ? 'Pickup' : 'Delivery',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isPickup ? const Color(0xFF475569) : const Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (order.createdAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(order.createdAt),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSm),

              // Items summary & Total price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  Text(
                    '${order.total.toStringAsFixed(2)} AED',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),

              // Quick action buttons if applicable
              if (_hasQuickAction(order.status)) ...[
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildQuickActionButton(context),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _hasQuickAction(OrderStatus status) {
    return status == OrderStatus.pending ||
        status == OrderStatus.accepted ||
        status == OrderStatus.preparing ||
        status == OrderStatus.ready;
  }

  Widget _buildQuickActionButton(BuildContext context) {
    switch (order.status) {
      case OrderStatus.pending:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              key: Key('order_reject_btn_${order.id}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => onQuickStatusChange?.call(OrderStatus.rejected),
              child: const Text('Reject'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              key: Key('order_accept_btn_${order.id}'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => onQuickStatusChange?.call(OrderStatus.accepted),
              child: const Text('Accept Order'),
            ),
          ],
        );
      case OrderStatus.accepted:
        return ElevatedButton(
          key: Key('order_prepare_btn_${order.id}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6D28D9),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => onQuickStatusChange?.call(OrderStatus.preparing),
          child: const Text('Start Preparing'),
        );
      case OrderStatus.preparing:
        return ElevatedButton(
          key: Key('order_ready_btn_${order.id}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7E22CE),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => onQuickStatusChange?.call(OrderStatus.ready),
          child: const Text('Mark Ready'),
        );
      case OrderStatus.ready:
        return ElevatedButton(
          key: Key('order_deliver_btn_${order.id}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => onQuickStatusChange?.call(OrderStatus.delivered),
          child: const Text('Complete'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
