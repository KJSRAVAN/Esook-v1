import 'package:esouq/core/theme/app_colors.dart';
import 'package:esouq/core/theme/app_dimensions.dart';
import 'package:esouq/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Warning banner displayed when one or more items in the cart are currently unavailable in the store.
class CartUnavailableBanner extends StatelessWidget {
  const CartUnavailableBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      padding: const EdgeInsets.all(AppDimensions.spacingSm + 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(25),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: AppColors.warning.withAlpha(120),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 22.0,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unavailable Items in Cart',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 13.0,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  'Some items are currently out of stock. Please remove them before proceeding.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
