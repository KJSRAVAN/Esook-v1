import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../cart/application/cart_notifier.dart';
import '../../cart/presentation/widgets/cart_nav_icon.dart';

/// Navigation item definition for the customer bottom navigation bar.
class CustomerNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Key? key;

  const CustomerNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.key,
  });
}

/// Centralized bottom navigation bar for the customer application shell.
class CustomerBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final CartNotifier? cartNotifier;

  static const List<CustomerNavItem> items = [
    CustomerNavItem(
      label: 'Market',
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront_rounded,
      key: Key('customer_nav_market'),
    ),
    CustomerNavItem(
      label: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      key: Key('customer_nav_chat'),
    ),
    CustomerNavItem(
      label: 'Cart',
      icon: Icons.shopping_cart_outlined,
      activeIcon: Icons.shopping_cart_rounded,
      key: Key('customer_nav_cart'),
    ),
    CustomerNavItem(
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      key: Key('customer_nav_orders'),
    ),
    CustomerNavItem(
      label: 'Account',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      key: Key('customer_nav_account'),
    ),
  ];

  const CustomerBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.cartNotifier,
  });

  @override
  Widget build(BuildContext context) {
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
        child: SizedBox(
          height: 64.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;
              return Expanded(
                child: _NavBarItemWidget(
                  item: item,
                  isSelected: isSelected,
                  isCart: index == 2,
                  cartNotifier: cartNotifier,
                  onTap: () => onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavBarItemWidget extends StatelessWidget {
  final CustomerNavItem item;
  final bool isSelected;
  final bool isCart;
  final CartNotifier? cartNotifier;
  final VoidCallback onTap;

  const _NavBarItemWidget({
    required this.item,
    required this.isSelected,
    this.isCart = false,
    this.cartNotifier,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.textTertiary;

    return Semantics(
      selected: isSelected,
      label: item.label,
      button: true,
      child: InkWell(
        key: item.key,
        onTap: onTap,
        splashColor: AppColors.primaryLight,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCart && cartNotifier != null)
              CartNavIcon(
                cartNotifier: cartNotifier!,
                isSelected: isSelected,
              )
            else
              Icon(
                isSelected ? item.activeIcon : item.icon,
                color: color,
                size: 24.0,
              ),
            const SizedBox(height: AppDimensions.spacing2xs),
            Text(
              item.label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 11.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
