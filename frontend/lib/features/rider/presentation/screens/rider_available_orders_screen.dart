import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/rider_order_model.dart';
import '../../domain/repositories/rider_repository.dart';
import '../widgets/rider_order_card.dart';

/// Screen displaying available READY delivery orders for the rider to accept.
///
/// Features periodic auto-polling (every 8s), pull-to-refresh,
/// online/offline state handling, and 409 conflict mitigation.
class RiderAvailableOrdersScreen extends StatefulWidget {
  final RiderRepository? riderRepository;
  final VoidCallback? onOrderAccepted;
  final bool isOnline;
  final ValueChanged<bool>? onToggleOnline;

  const RiderAvailableOrdersScreen({
    super.key,
    this.riderRepository,
    this.onOrderAccepted,
    this.isOnline = true,
    this.onToggleOnline,
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
  Timer? _pollingTimer;

  RiderRepository get _repository {
    if (widget.riderRepository != null) return widget.riderRepository!;
    throw StateError('RiderRepository not provided');
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableOrders();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant RiderAvailableOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnline != widget.isOnline) {
      if (widget.isOnline) {
        _loadAvailableOrders();
        _startPolling();
      } else {
        _stopPolling();
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
    if (!widget.isOnline) return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && widget.isOnline && !_isAccepting) {
        _pollAvailableOrders();
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _pollAvailableOrders() async {
    final result = await _repository.getAvailableOrders();
    if (!mounted) return;
    result.fold(
      onSuccess: (orders) {
        setState(() {
          _orders = orders;
        });
      },
      onFailure: (_) {},
    );
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
          _orders.removeWhere((o) => o.id == orderId);
        });
        widget.onOrderAccepted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Order Accepted! Opening delivery details...'),
              ],
            ),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 3),
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
          if (message.toLowerCase().contains('offline')) {
            message = 'You are currently offline. Turn on online status first.';
          } else if (message.toLowerCase().contains('active delivery') ||
              message.toLowerCase().contains('busy')) {
            message =
                'You already have an active delivery. Complete it before accepting another.';
          } else {
            message = 'This order has already been claimed by another driver.';
            shouldRefresh = true;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
          ),
        );

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Available Orders',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
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
    // 1. If Driver is Offline
    if (!widget.isOnline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFECACA), width: 2),
                ),
                child: const Icon(
                  Icons.power_settings_new_rounded,
                  size: 42,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'You are Currently Offline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Go online to receive nearby store pickup requests and start delivering.',
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
                  key: const Key('rider_go_online_btn'),
                  onPressed: () => widget.onToggleOnline?.call(true),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Go Online Now',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
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
      return RefreshIndicator(
        onRefresh: _loadAvailableOrders,
        color: const Color(0xFFEA580C),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  size: 42,
                  color: Color(0xFFEA580C),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'No Orders Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'All delivery orders have been claimed.\nPull down to refresh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: OutlinedButton.icon(
                onPressed: _loadAvailableOrders,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh Orders'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAvailableOrders,
      color: const Color(0xFFEA580C),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${_orders.length} order${_orders.length == 1 ? '' : 's'} available',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Auto-refreshing (8s)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            );
          }

          final order = _orders[index - 1];
          final isThisAccepting = _isAccepting && _acceptingOrderId == order.id;

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
