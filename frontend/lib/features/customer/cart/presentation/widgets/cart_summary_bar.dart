import 'package:esouq/core/constants/app_constants.dart';
import 'package:esouq/core/theme/app_colors.dart';
import 'package:esouq/core/theme/app_dimensions.dart';
import 'package:esouq/core/theme/app_text_styles.dart';
import 'package:esouq/features/customer/cart/domain/cart_model.dart';
import 'package:flutter/material.dart';

/// Summary bar docked at the bottom of the Cart screen showing server-provided totals and checkout action.
class CartSummaryBar extends StatelessWidget {
  final CartModel cart;
  final String currency;
  final VoidCallback? onProceed;

  const CartSummaryBar({
    super.key,
    required this.cart,
    this.currency = AppConstants.defaultCurrency,
    this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnavailable = cart.hasUnavailableItems;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.borderSubtle,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm + 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Subtotal & Points row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subtotal (${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'})',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (cart.totalLoyaltyPoints > 0)
                        Row(
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              size: 14.0,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 3.0),
                            Text(
                              '+${cart.totalLoyaltyPoints} loyalty pts',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.0,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Text(
                    '${cart.subtotal.toStringAsFixed(2)} $currency',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontSize: 18.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSm),

              // Proceed / Checkout CTA
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('cart_checkout_button'),
                  onPressed: hasUnavailable ? null : onProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.borderSubtle,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: AppColors.textTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    hasUnavailable ? 'Remove Unavailable Items' : 'Proceed to Checkout',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hasUnavailable ? AppColors.textTertiary : Colors.white,
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
