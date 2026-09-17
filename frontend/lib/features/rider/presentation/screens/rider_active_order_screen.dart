import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/rider_order_model.dart';
import '../../domain/repositories/rider_repository.dart';

/// Screen displaying the rider's current active in-progress delivery.
///
/// Shows store pickup info, customer dropoff address, delivery notes,
/// and a prominent "Mark as Delivered" action with confirmation dialog.
class RiderActiveOrderScreen extends StatefulWidget {
  final RiderRepository? riderRepository;
  final VoidCallback? onOrderCompleted;

  const RiderActiveOrderScreen({
    super.key,
    this.riderRepository,
    this.onOrderCompleted,
  });

  @override
  State<RiderActiveOrderScreen> createState() => _RiderActiveOrderScreenState();
}

class _RiderActiveOrderScreenState extends State<RiderActiveOrderScreen> {
  RiderOrderModel? _activeOrder;
  bool _isLoading = true;
  bool _isDelivering = false;
  AppFailure? _failure;

  RiderRepository get _repository {
    if (widget.riderRepository != null) return widget.riderRepository!;
    throw StateError('RiderRepository not provided');
  }

  @override
  void initState() {
    super.initState();
    _loadActiveOrder();
  }

  Future<void> _loadActiveOrder() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });

    final result = await _repository.getActiveOrder();

    if (!mounted) return;

    result.fold(
      onSuccess: (order) {
        setState(() {
          _activeOrder = order;
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

  Future<void> _handleMarkDelivered() async {
    if (_activeOrder == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: Text(
          'Mark this order as delivered?\n\n'
          'Dropoff: ${_activeOrder!.deliveryAddress ?? 'N/A'}\n'
          'Store: ${_activeOrder!.store.name}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Delivered'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDelivering = true);

    final result = await _repository.markDelivered(_activeOrder!.id);

    if (!mounted) return;

    result.fold(
      onSuccess: (_) {
        setState(() {
          _activeOrder = null;
          _isDelivering = false;
        });
        widget.onOrderCompleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery completed successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      },
      onFailure: (failure) {
        setState(() => _isDelivering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Active Delivery'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('rider_active_refresh_btn'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadActiveOrder,
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
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                _failure!.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              OutlinedButton.icon(
                onPressed: _loadActiveOrder,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_activeOrder == null) {
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
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              Text(
                'No Active Delivery',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'Accept an available order to start a delivery.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              OutlinedButton.icon(
                onPressed: _loadActiveOrder,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    // Active order display
    return RefreshIndicator(
      onRefresh: _loadActiveOrder,
      color: AppColors.primary,
      child: ListView(
        padding: AppDimensions.paddingScreen,
        children: [
          // Active delivery banner
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 32),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery In Progress',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _activeOrder!.status.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.spacingMd),

          // Store pickup card
          _buildContactCard(
            theme,
            icon: Icons.storefront_rounded,
            iconColor: AppColors.primary,
            title: 'Pickup From',
            name: _activeOrder!.store.name,
            address: _activeOrder!.store.address,
            phone: _activeOrder!.store.phone,
          ),

          const SizedBox(height: AppDimensions.spacingSm),

          // Customer dropoff card
          _buildContactCard(
            theme,
            icon: Icons.location_on_rounded,
            iconColor: AppColors.error,
            title: 'Deliver To',
            name: 'Customer',
            address: _activeOrder!.deliveryAddress,
            phone: _activeOrder!.customer.phone,
          ),

          // Notes
          if (_activeOrder!.notes != null && _activeOrder!.notes!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Container(
              width: double.infinity,
              padding: AppDimensions.paddingCard,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notes_rounded, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: AppDimensions.spacingSm),
                      Text(
                        'Delivery Notes',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    _activeOrder!.notes!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppDimensions.spacingLg),

          // Mark as Delivered button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              key: const Key('rider_mark_delivered_btn'),
              onPressed: _isDelivering ? null : _handleMarkDelivered,
              icon: _isDelivering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                _isDelivering ? 'Completing…' : 'Mark as Delivered',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.spacingMd),
        ],
      ),
    );
  }

  Widget _buildContactCard(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String name,
    String? address,
    String? phone,
  }) {
    return Container(
      padding: AppDimensions.paddingCard,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacing2xs),
            Text(
              address,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            InkWell(
              key: Key('rider_call_${title.toLowerCase().replaceAll(' ', '_')}'),
              onTap: () {
                // Simple tel: URI launch — does not require external dependencies
                // on most platforms the OS handles tel: links natively
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Call $phone'),
                    backgroundColor: AppColors.info,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_outlined, size: 16, color: AppColors.info),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Text(
                      phone,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
