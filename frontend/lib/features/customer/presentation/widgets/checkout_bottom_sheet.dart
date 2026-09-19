import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/uuid_helper.dart';
import '../../cart/domain/cart_model.dart';
import '../../domain/models/order_item_model.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';

/// Interactive checkout bottom sheet allowing customers to review their cart,
/// select fulfillment, provide delivery details, and place their order.
class CheckoutBottomSheet extends StatefulWidget {
  final CartModel cart;
  final String? storeName;
  final OrderRepository orderRepository;
  final String currency;
  final ValueChanged<OrderModel>? onOrderSuccess;

  const CheckoutBottomSheet({
    super.key,
    required this.cart,
    this.storeName,
    required this.orderRepository,
    this.currency = AppConstants.defaultCurrency,
    this.onOrderSuccess,
  });

  static Future<OrderModel?> show(
    BuildContext context, {
    required CartModel cart,
    String? storeName,
    required OrderRepository orderRepository,
    String currency = AppConstants.defaultCurrency,
    ValueChanged<OrderModel>? onOrderSuccess,
  }) {
    return showModalBottomSheet<OrderModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CheckoutBottomSheet(
        cart: cart,
        storeName: storeName,
        orderRepository: orderRepository,
        currency: currency,
        onOrderSuccess: onOrderSuccess,
      ),
    );
  }

  @override
  State<CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends State<CheckoutBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _couponController = TextEditingController();

  FulfillmentType _fulfillment = FulfillmentType.delivery;
  bool _isSubmitting = false;
  String? _errorMessage;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = UuidHelper.generateV4();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_isSubmitting) return;

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final targetStoreId = widget.cart.storeId ?? widget.cart.store.id;
    final itemsInput = widget.cart.items
        .map(
          (item) =>
              OrderItemInput(itemId: item.itemId, quantity: item.quantity),
        )
        .toList();

    final result = await widget.orderRepository.createOrder(
      storeId: targetStoreId,
      fulfillment: _fulfillment,
      deliveryAddress: _fulfillment == FulfillmentType.delivery
          ? _addressController.text.trim()
          : null,
      couponCode: _couponController.text.trim().isNotEmpty
          ? _couponController.text.trim()
          : null,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      items: itemsInput,
      idempotencyKey: _idempotencyKey,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (order) {
        setState(() {
          _isSubmitting = false;
        });
        widget.onOrderSuccess?.call(order);
        Navigator.of(context).pop(order);
      },
      onFailure: (failure) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = failure.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final storeDisplayName = widget.storeName ?? widget.cart.store.name;

    return Container(
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.9),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
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

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingLg,
                  vertical: AppDimensions.spacingSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Checkout',
                          style: AppTextStyles.headlineSmall,
                        ),
                        if (storeDisplayName.isNotEmpty)
                          Text(
                            storeDisplayName,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1.0, color: AppColors.borderSubtle),

              // Scrollable content
              Flexible(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(AppDimensions.spacingLg),
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          key: const Key('checkout_error_banner'),
                          padding: const EdgeInsets.all(
                            AppDimensions.spacingMd,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 20.0,
                              ),
                              const SizedBox(width: AppDimensions.spacingSm),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                      ],

                      // Fulfillment Selector
                      Text(
                        'Fulfillment Method',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      Row(
                        children: [
                          Expanded(
                            child: _FulfillmentOptionCard(
                              key: const Key('fulfillment_delivery_option'),
                              title: 'Delivery',
                              subtitle: 'To your doorstep',
                              icon: Icons.delivery_dining_outlined,
                              isSelected:
                                  _fulfillment == FulfillmentType.delivery,
                              onTap: _isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _fulfillment = FulfillmentType.delivery;
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingMd),
                          Expanded(
                            child: _FulfillmentOptionCard(
                              key: const Key('fulfillment_pickup_option'),
                              title: 'Pickup',
                              subtitle: 'At the store',
                              icon: Icons.storefront_outlined,
                              isSelected:
                                  _fulfillment == FulfillmentType.pickup,
                              onTap: _isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _fulfillment = FulfillmentType.pickup;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingLg),

                      // Delivery Address Field (Required for delivery)
                      if (_fulfillment == FulfillmentType.delivery) ...[
                        Text(
                          'Delivery Address',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingXs),
                        TextFormField(
                          key: const Key('checkout_delivery_address_input'),
                          controller: _addressController,
                          enabled: !_isSubmitting,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Building 4B, King Fahd Rd, Riyadh',
                            prefixIcon: Icon(
                              Icons.location_on_outlined,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          validator: (value) {
                            if (_fulfillment == FulfillmentType.delivery) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Delivery address is required for delivery orders';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),
                      ],

                      // Optional Notes
                      Text(
                        'Order Notes (Optional)',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      TextFormField(
                        key: const Key('checkout_notes_input'),
                        controller: _notesController,
                        enabled: !_isSubmitting,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Please leave package at front door',
                          prefixIcon: Icon(
                            Icons.notes_outlined,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingLg),

                      // Optional Coupon Code
                      Text(
                        'Coupon Code (Optional)',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      TextFormField(
                        key: const Key('checkout_coupon_input'),
                        controller: _couponController,
                        enabled: !_isSubmitting,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'e.g. WELCOME10',
                          prefixIcon: Icon(
                            Icons.local_offer_outlined,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingLg),

                      // Order Items Summary
                      Text(
                        'Order Summary (${widget.cart.itemCount} ${widget.cart.itemCount == 1 ? 'item' : 'items'})',
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
                            ...widget.cart.items.map(
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
                                      '${item.itemSubtotal.toStringAsFixed(2)} ${widget.currency}',
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
                                  '${widget.cart.subtotal.toStringAsFixed(2)} ${widget.currency}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Delivery Fee',
                                  style: AppTextStyles.bodyMedium,
                                ),
                                Text(
                                  _fulfillment == FulfillmentType.delivery
                                      ? 'Free'
                                      : '0.00 ${widget.currency}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        _fulfillment == FulfillmentType.delivery
                                        ? AppColors.success
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
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
                                  '${widget.cart.subtotal.toStringAsFixed(2)} ${widget.currency}',
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
                    ],
                  ),
                ),
              ),

              // Bottom Place Order CTA
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('checkout_place_order_button'),
                    onPressed: _isSubmitting ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.borderSubtle,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20.0,
                            width: 20.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Place Order • ${widget.cart.subtotal.toStringAsFixed(2)} ${widget.currency}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FulfillmentOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _FulfillmentOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primaryDark
                  : AppColors.textSecondary,
              size: 24.0,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AppColors.primaryDark
                    : AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
                fontSize: 11.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
