import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/routing/role_routing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/auth_scope.dart';

/// Startup authentication gate verifying stored session against backend `/auth/me`.
class SessionBootstrapScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const SessionBootstrapScreen({
    super.key,
    this.authRepository,
  });

  @override
  State<SessionBootstrapScreen> createState() => _SessionBootstrapScreenState();
}

class _SessionBootstrapScreenState extends State<SessionBootstrapScreen> {
  bool _isLoading = true;
  AppFailure? _transientError;

  AuthRepository get _repository =>
      widget.authRepository ?? AuthScope.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    setState(() {
      _isLoading = true;
      _transientError = null;
    });

    final result = await _repository.checkSession();

    if (!mounted) return;

    if (result.isSuccess) {
      final user = result.dataOrNull;
      if (user != null) {
        // Valid active session -> route to assigned role home
        RoleRouting.navigateForRole(context, user.role, clearStack: true);
      } else {
        // No token or expired -> route to customer login
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    } else {
      final failure = result.failureOrNull;
      // If temporary network or server error, retain token and allow retry
      setState(() {
        _isLoading = false;
        _transientError = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand Logo Badge
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1400A86B),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shopping_bag_rounded,
                      color: AppColors.primary,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingLg),

                // Brand Name
                Text(
                  'eSOuQ',
                  style: AppTextStyles.displayMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  'Fresh Groceries Delivered',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing2xl),

                // Loading State or Error State
                if (_isLoading) ...[
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Text(
                    'Verifying session...',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ] else if (_transientError != null) ...[
                  // Error card for transient connection issue
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacingMd),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: AppColors.warning,
                          size: 36,
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          'Connection Issue',
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: AppDimensions.spacingXs),
                        Text(
                          'Could not verify your session with the server. Please check your connection.',
                          style: AppTextStyles.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _checkSession,
                            child: const Text('Try Again'),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                          },
                          child: const Text('Go to Login'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
