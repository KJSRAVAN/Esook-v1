import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../customer/domain/models/order_model.dart';
import '../../domain/repositories/store_orders_repository.dart';
import 'store_scope.dart';

/// Modal bottom sheet displaying full order details and handling staff status actions.
class StoreOrderDetailsSheet extends StatefulWidget {
  final OrderModel order;
  final StoreOrdersRepository? ordersRepository;
  final ValueChanged<OrderModel>? onOrderUpdated;

  const StoreOrderDetailsSheet({
    super.key,
    required this.order,
    this.ordersRepository,
    this.onOrderUpdated,
  });

  static Future<OrderModel?> show(
    BuildContext context, {
    required OrderModel order,
    StoreOrdersRepository? ordersRepository,
  }) {
    return showModalBottomSheet<OrderModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StoreOrderDetailsSheet(
        order: order,
        ordersRepository: ordersRepository,
      ),
    );
  }

  @override
  State<StoreOrderDetailsSheet> createState() => _StoreOrderDetailsSheetState();
}

class _StoreOrderDetailsSheetState extends State<StoreOrderDetailsSheet> {
  late OrderModel _currentOrder;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  StoreOrdersRepository get _ordersRepo =>
      widget.ordersRepository ?? StoreScope.ordersRepositoryOf(context);

  Future<void> _updateStatus(OrderStatus newStatus, {String? rejectedReason}) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await _ordersRepo.updateOrderStatus(
      orderId: _currentOrder.id,
      status: newStatus,
      rejectedReason: rejectedReason,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final updated = result.dataOrNull!;
      setState(() {
        _currentOrder = updated;
        _isSubmitting = false;
      });
      widget.onOrderUpdated?.call(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to ${updated.status.displayName}'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final error = result.failureOrNull?.message ?? 'Failed to update order status';
      setState(() {
        _isSubmitting = false;
        _errorMessage = error;
      });
    }
  }

  void _promptRejectDialog() {
    final reasonController = TextEditingController();
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Reject Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please provide a reason for rejecting this order:'),
              const SizedBox(height: 12),
              TextField(
                key: const Key('reject_reason_input'),
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Store closing or item out of stock',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('confirm_reject_btn'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Confirm Reject'),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        _updateStatus(OrderStatus.rejected, rejectedReason: reasonController.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPickup = _currentOrder.fulfillment == FulfillmentType.pickup;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Top title & close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _currentOrder.orderNumber ?? 'Order Details',
                      style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(_currentOrder),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.spacingSm),
                        margin: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Status & Fulfillment Banner
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Status',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentOrder.status.displayName,
                              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPickup ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          ),
                          child: Text(
                            isPickup ? 'Pickup Order' : 'Delivery Order',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: isPickup ? const Color(0xFF334155) : const Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),

                    // Delivery Address if Delivery
                    if (!isPickup && _currentOrder.deliveryAddress != null) ...[
                      Card(
                        color: const Color(0xFFF8FAFC),
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.spacingMd),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Delivery Address', style: AppTextStyles.labelLarge),
                                    const SizedBox(height: 2),
                                    Text(
                                      _currentOrder.deliveryAddress!,
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingMd),
                    ],

                    // Order Items
                    Text(
                      'Items (${_currentOrder.itemCount})',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _currentOrder.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _currentOrder.items[index];
                          return ListTile(
                            dense: true,
                            title: Text(item.itemName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                            subtitle: Text('${item.quantity} × ${item.unitPrice.toStringAsFixed(2)} AED'),
                            trailing: Text(
                              '${item.subtotal.toStringAsFixed(2)} AED',
                              style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),

                    // Totals Breakdown
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.spacingMd),
                        child: Column(
                          children: [
                            _buildPriceRow('Subtotal', '${_currentOrder.subtotal.toStringAsFixed(2)} AED'),
                            if (_currentOrder.deliveryFee > 0)
                              _buildPriceRow('Delivery Fee', '${_currentOrder.deliveryFee.toStringAsFixed(2)} AED'),
                            if (_currentOrder.discount > 0)
                              _buildPriceRow('Discount', '-${_currentOrder.discount.toStringAsFixed(2)} AED', isDiscount: true),
                            const Divider(height: 16),
                            _buildPriceRow(
                              'Total Amount',
                              '${_currentOrder.total.toStringAsFixed(2)} AED',
                              isBold: true,
                              textColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: _isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : _buildActionButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false, bool isDiscount = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)
                : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: isBold
                ? AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700, color: textColor)
                : AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDiscount ? AppColors.success : textColor,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (_currentOrder.status) {
      case OrderStatus.pending:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('details_reject_btn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: _promptRejectDialog,
                child: const Text('Reject Order'),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: ElevatedButton(
                key: const Key('details_accept_btn'),
                onPressed: () => _updateStatus(OrderStatus.accepted),
                child: const Text('Accept Order'),
              ),
            ),
          ],
        );
      case OrderStatus.accepted:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                key: const Key('details_prepare_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _updateStatus(OrderStatus.preparing),
                child: const Text('Start Preparing'),
              ),
            ),
          ],
        );
      case OrderStatus.preparing:
        final isPickup = _currentOrder.fulfillment == FulfillmentType.pickup;
        return Row(
          children: [
            if (!isPickup) ...[
              Expanded(
                child: ElevatedButton(
                  key: const Key('details_out_for_delivery_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _updateStatus(OrderStatus.outForDelivery),
                  child: const Text('Out for Delivery'),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
            ],
            Expanded(
              child: ElevatedButton(
                key: const Key('details_complete_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _updateStatus(OrderStatus.delivered),
                child: const Text('Complete Order'),
              ),
            ),
          ],
        );
      case OrderStatus.ready:
      case OrderStatus.outForDelivery:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                key: const Key('details_complete_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _updateStatus(OrderStatus.delivered),
                child: const Text('Complete Order'),
              ),
            ),
          ],
        );
      case OrderStatus.delivered:
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return Center(
          child: Text(
            'Order is in terminal state (${_currentOrder.status.displayName})',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
          ),
        );
    }
  }
}
