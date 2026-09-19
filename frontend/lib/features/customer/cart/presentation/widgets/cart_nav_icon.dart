import 'package:esouq/core/theme/app_colors.dart';
import 'package:esouq/core/theme/app_text_styles.dart';
import 'package:esouq/features/customer/cart/application/cart_notifier.dart';
import 'package:flutter/material.dart';

/// Cart icon for bottom navigation that reactively shows the total item count badge.
class CartNavIcon extends StatelessWidget {
  final CartNotifier cartNotifier;
  final bool isSelected;

  const CartNavIcon({
    super.key,
    required this.cartNotifier,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.textTertiary;
    final iconData = isSelected
        ? Icons.shopping_cart_rounded
        : Icons.shopping_cart_outlined;

    return ListenableBuilder(
      listenable: cartNotifier,
      builder: (context, _) {
        final count = cartNotifier.itemCount;

        return Badge(
          isLabelVisible: count > 0,
          label: Text(
            count > 99 ? '99+' : count.toString(),
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white,
              fontSize: 10.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppColors.primary,
          child: Icon(iconData, color: color, size: 24.0),
        );
      },
    );
  }
}
