import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/rider_order_model.dart';
import '../../domain/repositories/rider_repository.dart';

/// Screen displaying the rider's current active in-progress delivery.
///
/// Implements a Swiggy-inspired two-stage delivery workflow:
/// 1. Pickup Stage: Store details, directions, phone call, and item verification checklist.
/// 2. Dropoff Stage: Customer details, navigation, delivery notes, and delivery completion.
class RiderActiveOrderScreen extends StatefulWidget {
  final RiderRepository? riderRepository;
  final VoidCallback? onOrderCompleted;
  final VoidCallback? onBrowseAvailable;

  const RiderActiveOrderScreen({
    super.key,
    this.riderRepository,
    this.onOrderCompleted,
    this.onBrowseAvailable,
  });

  @override
  State<RiderActiveOrderScreen> createState() => _RiderActiveOrderScreenState();
}

class _RiderActiveOrderScreenState extends State<RiderActiveOrderScreen> {
  RiderOrderModel? _activeOrder;
  bool _isLoading = true;
  bool _isDelivering = false;
  AppFailure? _failure;
  Timer? _pollingTimer;

  // Track item verification checklist during store pickup
  final Set<String> _checkedItemIds = {};
  bool _isPickupConfirmed = false;

  RiderRepository get _repository {
    if (widget.riderRepository != null) return widget.riderRepository!;
    throw StateError('RiderRepository not provided');
  }

  @override
  void initState() {
    super.initState();
    _loadActiveOrder();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isDelivering) {
        _pollActiveOrder();
      }
    });
  }

  Future<void> _pollActiveOrder() async {
    final result = await _repository.getActiveOrder();
    if (!mounted) return;
    result.fold(
      onSuccess: (order) {
        if (_activeOrder?.id != order?.id) {
          setState(() {
            _activeOrder = order;
            _checkedItemIds.clear();
            _isPickupConfirmed = false;
          });
        }
      },
      onFailure: (_) {},
    );
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
          _checkedItemIds.clear();
          _isPickupConfirmed = false;
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Have you handed the order over to the customer at the dropoff address?',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer: ${_activeOrder!.customer.name ?? 'Valued Customer'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dropoff: ${_activeOrder!.deliveryAddress ?? 'Customer Address'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            key: const Key('rider_confirm_delivered_dialog_btn'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
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
            content: Row(
              children: [
                Icon(Icons.stars_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Delivery Completed! Excellent job.'),
              ],
            ),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 4),
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

  void _showActionToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Active Delivery',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
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
      bottomNavigationBar: _activeOrder != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    key: const Key('rider_mark_delivered_btn'),
                    onPressed: _isDelivering ? null : _handleMarkDelivered,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isDelivering
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.task_alt_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Mark as Delivered',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA580C)),
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
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.moped_rounded,
                  size: 42,
                  color: Color(0xFFEA580C),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Active Delivery',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Accept an available order to start a delivery.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('rider_view_available_btn'),
                  onPressed: () => widget.onBrowseAvailable?.call(),
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text(
                    'View Available Orders',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final order = _activeOrder!;

    return RefreshIndicator(
      onRefresh: _loadActiveOrder,
      color: const Color(0xFFEA580C),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Stage Progress Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'ORDER #${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Delivery In Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _isPickupConfirmed ? 'Step 2: Deliver to Customer' : 'Step 1: Pick up from Store',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isPickupConfirmed
                      ? 'Head to the dropoff address and deliver the order.'
                      : 'Go to ${order.store.name} and verify all items.',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 14),
                // Stepper bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _isPickupConfirmed ? const Color(0xFF059669) : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Pickup Card (Store Details)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isPickupConfirmed ? const Color(0xFFE2E8F0) : const Color(0xFFFED7AA),
                width: _isPickupConfirmed ? 1 : 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'STORE PICKUP',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (_isPickupConfirmed) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.store.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          if (order.store.address != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              order.store.address!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                // Action Buttons for Store
                Row(
                  children: [
                    if (order.store.phone != null && order.store.phone!.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('rider_call_pickup_from'),
                          onPressed: () => _showActionToast('Calling ${order.store.name} (${order.store.phone})'),
                          icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF2563EB)),
                          label: const Text('Call Store', style: TextStyle(fontSize: 13, color: Color(0xFF2563EB))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    if (order.store.phone != null && order.store.phone!.isNotEmpty)
                      const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('rider_navigate_store_btn'),
                        onPressed: () => _showActionToast('Directions to ${order.store.name}'),
                        icon: const Icon(Icons.directions_rounded, size: 16, color: Color(0xFF475569)),
                        label: const Text('Directions', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),

                // Items Checklist during pickup
                if (order.items.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ITEMS CHECKLIST',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${_checkedItemIds.length}/${order.items.length} verified',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...order.items.map((item) {
                    final isChecked = _checkedItemIds.contains(item.id);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isChecked) {
                            _checkedItemIds.remove(item.id);
                          } else {
                            _checkedItemIds.add(item.id);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          children: [
                            Icon(
                              isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                              color: isChecked ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.quantity}x',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isChecked ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                                  decoration: isChecked ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                // Confirm Pickup Step Button
                if (!_isPickupConfirmed) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      key: const Key('rider_confirm_pickup_btn'),
                      onPressed: () {
                        setState(() {
                          _isPickupConfirmed = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Store pickup confirmed! Now heading to customer.'),
                            backgroundColor: Color(0xFF2563EB),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Confirm Items & Start Delivery to Customer',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Dropoff Card (Customer Details)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isPickupConfirmed ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                width: _isPickupConfirmed ? 1.5 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DELIVER TO CUSTOMER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.customer.name ?? 'Customer',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.deliveryAddress ?? 'Customer Address',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                // Action Buttons for Customer
                Row(
                  children: [
                    if (order.customer.phone.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('rider_call_deliver_to'),
                          onPressed: () => _showActionToast('Calling Customer (${order.customer.phone})'),
                          icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF059669)),
                          label: const Text('Call Customer', style: TextStyle(fontSize: 13, color: Color(0xFF059669))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFA7F3D0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    if (order.customer.phone.isNotEmpty)
                      const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('rider_navigate_customer_btn'),
                        onPressed: () => _showActionToast('Opening Navigation to ${order.deliveryAddress ?? 'Customer'}'),
                        icon: const Icon(Icons.navigation_rounded, size: 16, color: Color(0xFFDC2626)),
                        label: const Text('Navigate', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),

                // Delivery Notes if any
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notes_rounded, size: 16, color: Color(0xFFB45309)),
                            SizedBox(width: 6),
                            Text(
                              'Customer Instructions',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.notes!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF78350F)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
