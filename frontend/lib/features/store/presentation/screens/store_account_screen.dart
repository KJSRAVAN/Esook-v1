import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../widgets/store_scope.dart';

/// Account and profile screen for Store Staff and Managers.
class StoreAccountScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const StoreAccountScreen({super.key, this.authRepository});

  @override
  State<StoreAccountScreen> createState() => _StoreAccountScreenState();
}

class _StoreAccountScreenState extends State<StoreAccountScreen> {
  bool _isLoggingOut = false;
  UserModel? _currentUser;
  bool _isLoadingUser = true;

  AuthRepository get _authRepo =>
      widget.authRepository ?? StoreScope.authRepositoryOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final scopedUser = StoreScope.currentUserOf(context);
    if (scopedUser != null) {
      setState(() {
        _currentUser = scopedUser;
        _isLoadingUser = false;
      });
      return;
    }

    final result = await _authRepo.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = result.dataOrNull;
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of the store portal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('store_account_confirm_signout_btn'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);

    await _authRepo.logout();

    if (mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Staff Account')),
      body: SafeArea(
        child: _isLoadingUser
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Column(
                  children: [
                    // Profile Header Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.spacingLg),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                _getInitials(_currentUser?.fullName ?? 'Staff'),
                                style: AppTextStyles.headlineSmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingSm),
                            Text(
                              _currentUser?.fullName ?? 'Store Staff',
                              style: AppTextStyles.headlineSmall.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusFull,
                                ),
                              ),
                              child: Text(
                                _currentUser?.role.isStoreManager == true
                                    ? 'Store Manager'
                                    : 'Store Staff',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: const Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),

                    // Details Card
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.phone_outlined,
                              color: AppColors.textSecondary,
                            ),
                            title: const Text('Phone Number'),
                            subtitle: Text(_currentUser?.phoneNumber ?? 'N/A'),
                          ),
                          if (_currentUser?.email != null &&
                              _currentUser!.email!.isNotEmpty) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.email_outlined,
                                color: AppColors.textSecondary,
                              ),
                              title: const Text('Email Address'),
                              subtitle: Text(_currentUser!.email!),
                            ),
                          ],
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.storefront_outlined,
                              color: AppColors.textSecondary,
                            ),
                            title: const Text('Assigned Store ID'),
                            subtitle: Text(_currentUser?.storeId ?? 'None'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),

                    // Sign Out Button
                    ElevatedButton.icon(
                      key: const Key('store_account_signout_btn'),
                      onPressed: _isLoggingOut ? null : _handleLogout,
                      icon: _isLoggingOut
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return 'S';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
