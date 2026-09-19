import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Reusable responsive layout scaffold for authentication screens.
///
/// Features:
/// - Centers content within a responsive card constraint (max 440px on mobile/customer/rider, 480px for staff/admin).
/// - Automatically dismisses software keyboard when tapping background.
/// - Standardized eSOuQ brand header, badge icon, title, and subtitle hierarchy.
/// - Scrollable to prevent overflow on small screens or when soft keyboard appears.
class AuthScaffold extends StatelessWidget {
  final Widget child;
  final String title;
  final String? subtitle;
  final Widget? headerBadge;
  final Widget? bottomNavigation;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final double maxWidth;

  const AuthScaffold({
    super.key,
    required this.child,
    required this.title,
    this.subtitle,
    this.headerBadge,
    this.bottomNavigation,
    this.showBackButton = false,
    this.onBackPressed,
    this.maxWidth = 440.0,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: showBackButton
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed:
                      onBackPressed ?? () => Navigator.of(context).maybePop(),
                  tooltip: 'Back',
                ),
              )
            : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingMd,
                vertical: AppDimensions.spacingLg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Container(
                  padding: isDesktop
                      ? const EdgeInsets.all(AppDimensions.spacingXl)
                      : const EdgeInsets.all(AppDimensions.spacingLg),
                  decoration: isDesktop
                      ? BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusLg,
                          ),
                          border: Border.all(color: AppColors.borderSubtle),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 20,
                              offset: Offset(0, 4),
                            ),
                          ],
                        )
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Brand / Badge Icon
                      if (headerBadge != null) ...[
                        Center(child: headerBadge!),
                        const SizedBox(height: AppDimensions.spacingLg),
                      ] else ...[
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd,
                              ),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: AppColors.primaryDark,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),
                      ],

                      // Title
                      Text(
                        title,
                        style: AppTextStyles.headlineLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // Subtitle
                      if (subtitle != null) ...[
                        const SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          subtitle!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: AppDimensions.spacingXl),

                      // Form Body Content
                      child,

                      // Bottom Navigation (e.g. Switch account / Sign up link)
                      if (bottomNavigation != null) ...[
                        const SizedBox(height: AppDimensions.spacingLg),
                        bottomNavigation!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
