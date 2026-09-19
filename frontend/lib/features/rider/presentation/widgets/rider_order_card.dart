import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/rider_order_model.dart';

/// Reusable card displaying a driver order with store info, dropoff address, and action.
class RiderOrderCard extends StatelessWidget {
  final RiderOrderModel order;
  final VoidCallback? onAction;
  final String? actionLabel;
  final bool isActionLoading;

  const RiderOrderCard({
    super.key,
    required this.order,
    this.onAction,
    this.actionLabel,
    this.isActionLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: AppDimensions.paddingCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: order ID + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order ${order.id.length > 8 ? order.id.substring(0, 8) : order.id}…',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(status: order.status),
              ],
            ),

            const SizedBox(height: AppDimensions.spacingSm),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: AppDimensions.spacingSm),

            // Store info
            _InfoRow(
              icon: Icons.storefront_rounded,
              iconColor: AppColors.primary,
              label: order.store.name,
              subtitle: order.store.address,
            ),

            const SizedBox(height: AppDimensions.spacingSm),

            // Delivery address
            if (order.deliveryAddress != null &&
                order.deliveryAddress!.isNotEmpty)
              _InfoRow(
                icon: Icons.location_on_outlined,
                iconColor: AppColors.error,
                label: 'Dropoff',
                subtitle: order.deliveryAddress,
              ),

            // Notes
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              _InfoRow(
                icon: Icons.notes_rounded,
                iconColor: AppColors.textSecondary,
                label: 'Notes',
                subtitle: order.notes,
              ),
            ],

            // Timestamp
            if (order.createdAt != null) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    _formatTimestamp(order.createdAt!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],

            // Action button
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              SizedBox(
                width: double.infinity,
                height: AppDimensions.buttonHeight,
                child: ElevatedButton(
                  onPressed: isActionLoading ? null : onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _actionColor(order.status),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: isActionLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          actionLabel!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _actionColor(RiderOrderStatus status) {
    switch (status) {
      case RiderOrderStatus.ready:
        return AppColors.primary;
      case RiderOrderStatus.outForDelivery:
        return AppColors.success;
      case RiderOrderStatus.delivered:
        return AppColors.textSecondary;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final RiderOrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      RiderOrderStatus.ready => (
        const Color(0xFFFEF3C7),
        const Color(0xFFD97706),
      ),
      RiderOrderStatus.outForDelivery => (
        const Color(0xFFDBEAFE),
        const Color(0xFF2563EB),
      ),
      RiderOrderStatus.delivered => (
        const Color(0xFFD1FAE5),
        const Color(0xFF059669),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
