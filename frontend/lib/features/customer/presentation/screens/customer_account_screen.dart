import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/storage/flutter_secure_storage_impl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/widgets/auth_scope.dart';
import 'customer_edit_profile_screen.dart';

/// Customer Account screen displaying the authenticated user profile and settings.
///
/// Features:
/// - Real authenticated profile display (name, phone, email, customer role badge, active status).
/// - "Edit Profile" action navigating to [CustomerEditProfileScreen].
/// - "Sign Out" action delegating to [AuthRepository.logout].
class CustomerAccountScreen extends StatefulWidget {
  final AuthRepository? authRepository;
  final UserModel? initialUser;

  const CustomerAccountScreen({
    super.key,
    this.authRepository,
    this.initialUser,
  });

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isLoggingOut = false;

  AuthRepository get _repository {
    if (widget.authRepository != null) return widget.authRepository!;
    final fromScope = AuthScope.maybeOf(context);
    if (fromScope != null) return fromScope;
    final config = AppConfig.fromEnvironment();
    final secureStorage = const FlutterSecureStorageImpl();
    final apiClient = DefaultApiClient(
      baseUrl: config.apiBaseUrl,
      tokenProvider: () => secureStorage.read(key: StorageKeys.authToken),
      timeout: config.connectTimeout,
    );
    return AuthRepositoryImpl(
      apiClient: apiClient,
      secureStorage: secureStorage,
    );
  }

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUser != null) {
      _currentUser = widget.initialUser;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      if (_currentUser == null) {
        _loadUser();
      }
    }
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);

    final result = await _repository.getCurrentUser();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _currentUser = result.dataOrNull;
      }
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    await _repository.logout();
    if (context.mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  Future<void> _navigateToEditProfile() async {
    if (_currentUser == null) return;

    final updated = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(
        builder: (_) => CustomerEditProfileScreen(
          authRepository: _repository,
          currentUser: _currentUser!,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _currentUser = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('account_refresh_button'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadUser,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading && _currentUser == null
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadUser,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingMd,
                    vertical: AppDimensions.spacingSm,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Main Profile Card
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd,
                              ),
                              side: const BorderSide(
                                color: AppColors.borderSubtle,
                              ),
                            ),
                            color: AppColors.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(
                                AppDimensions.spacingMd,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Section Heading
                                  Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            AppDimensions.radiusMd,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_outline_rounded,
                                          size: 26,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: AppDimensions.spacingSm,
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Customer Account',
                                              style: AppTextStyles.titleMedium,
                                            ),
                                            Text(
                                              _currentUser
                                                          ?.fullName
                                                          .isNotEmpty ==
                                                      true
                                                  ? _currentUser!.fullName
                                                  : 'eSOuQ Customer',
                                              key: const Key(
                                                'account_user_name',
                                              ),
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (_currentUser
                                                    ?.phoneNumber
                                                    .isNotEmpty ==
                                                true)
                                              Text(
                                                _currentUser!.phoneNumber,
                                                key: const Key(
                                                  'account_user_phone',
                                                ),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryLight,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppDimensions.radiusFull,
                                                  ),
                                            ),
                                            child: const Text(
                                              'Customer',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  (_currentUser?.isActive ??
                                                      true)
                                                  ? const Color(0xFFD1FAE5)
                                                  : const Color(0xFFFEE2E2),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppDimensions.radiusFull,
                                                  ),
                                            ),
                                            child: Text(
                                              (_currentUser?.isActive ?? true)
                                                  ? 'Active'
                                                  : 'Inactive',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    (_currentUser?.isActive ??
                                                        true)
                                                    ? const Color(0xFF059669)
                                                    : AppColors.error,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(
                                    height: AppDimensions.spacingSm,
                                  ),
                                  const Divider(height: 1),

                                  // Edit Profile Action Tile
                                  ListTile(
                                    key: const Key('account_edit_profile_tile'),
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.edit_outlined,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    title: const Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Update your name and email address',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: AppColors.textTertiary,
                                    ),
                                    onTap: _navigateToEditProfile,
                                  ),

                                  const Divider(height: 1),

                                  // Email row
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6.0,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.email_outlined,
                                          size: 16,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Email: ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textTertiary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            _currentUser?.email != null &&
                                                    _currentUser!
                                                        .email!
                                                        .isNotEmpty
                                                ? _currentUser!.email!
                                                : 'Not set',
                                            key: const Key(
                                              'account_user_email',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppDimensions.spacingMd),

                          // Sign Out Button
                          SizedBox(
                            height: AppDimensions.buttonHeight,
                            child: OutlinedButton.icon(
                              key: const Key('account_signout_button'),
                              onPressed: _isLoggingOut
                                  ? null
                                  : () => _handleLogout(context),
                              icon: _isLoggingOut
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.logout_rounded, size: 20),
                              label: Text(
                                _isLoggingOut ? 'Signing out...' : 'Sign Out',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSm,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
