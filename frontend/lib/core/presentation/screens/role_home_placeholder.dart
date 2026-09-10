import 'package:flutter/material.dart';

import '../../../features/auth/domain/models/user_role.dart';
import '../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../features/auth/presentation/widgets/auth_scope.dart';
import '../../routing/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_text_styles.dart';

/// Temporary isolated placeholder shell for authenticated role destinations.
///
/// Features logout capability to cleanly test token invalidation and session bootstrap flows.
class RoleHomePlaceholderScreen extends StatelessWidget {
  final String title;
  final UserRole role;
  final AuthRepository? authRepository;

  const RoleHomePlaceholderScreen({
    super.key,
    required this.title,
    required this.role,
    this.authRepository,
  });

  @override
  Widget build(BuildContext context) {
    final repository = authRepository ?? AuthScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await repository.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.login,
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: Icon(
                  _getRoleIcon(role),
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                title,
                style: AppTextStyles.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingSm + 4,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  'Role: ${role.value}',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              Text(
                'Authenticated shell initialized.\nFeature domain screens will be loaded in subsequent phases.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              OutlinedButton.icon(
                onPressed: () async {
                  await repository.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.login,
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    return switch (role) {
      UserRole.customer => Icons.shopping_bag_outlined,
      UserRole.storeStaff || UserRole.storeManager => Icons.storefront_outlined,
      UserRole.deliveryRider => Icons.delivery_dining_outlined,
      UserRole.superAdmin => Icons.admin_panel_settings_outlined,
      UserRole.unknown => Icons.person_outline,
    };
  }
}
