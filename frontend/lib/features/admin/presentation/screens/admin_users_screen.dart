import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../domain/models/admin_user_model.dart';
import '../../domain/repositories/admin_users_repository.dart';
import '../widgets/admin_scope.dart';

/// User directory screen for Super Admin with role filtering and pagination.
class AdminUsersScreen extends StatefulWidget {
  final AdminUsersRepository? usersRepository;

  const AdminUsersScreen({
    super.key,
    this.usersRepository,
  });

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<AdminUserModel> _users = const [];
  int _totalUsers = 0;
  int _currentPage = 1;
  static const int _pageSize = 20;
  String _selectedRole = 'ALL';

  static const List<String> _roleFilters = [
    'ALL',
    'CUSTOMER',
    'STAFF',
    'MANAGER',
    'DRIVER',
    'SUPER_ADMIN',
  ];

  AdminUsersRepository get _repo =>
      widget.usersRepository ?? AdminScope.usersRepositoryOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUsers();
  }

  Future<void> _loadUsers({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = page;
    });

    final result = await _repo.getUsers(
      page: page,
      limit: _pageSize,
      role: _selectedRole == 'ALL' ? null : _selectedRole,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final data = result.dataOrNull!;
      setState(() {
        _users = data.users;
        _totalUsers = data.total;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.failureOrNull?.message ?? 'Failed to load user directory';
      });
    }
  }

  void _onRoleFilterChanged(String role) {
    if (_selectedRole != role) {
      setState(() {
        _selectedRole = role;
      });
      _loadUsers(page: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Directory'),
        actions: [
          IconButton(
            key: const Key('users_refresh_button'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : () => _loadUsers(page: _currentPage),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar
            _buildFilterBar(),

            // Content
            Expanded(child: _buildContent()),

            // Pagination Controls
            if (!_isLoading && _errorMessage == null && _totalUsers > _pageSize)
              _buildPaginationBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _roleFilters.map((role) {
            final isSelected = _selectedRole == role;
            return Padding(
              padding: const EdgeInsets.only(right: AppDimensions.spacingSm),
              child: ChoiceChip(
                label: Text(
                  _formatRoleLabel(role),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.background,
                onSelected: (_) => _onRoleFilterChanged(role),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'Unable to Load Users',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton.icon(
                key: const Key('users_retry_button'),
                onPressed: () => _loadUsers(page: _currentPage),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline_rounded, color: AppColors.textTertiary, size: 48),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'No Users Found',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                'No registered accounts match the selected role filter.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.spacingSm),
      itemBuilder: (context, index) {
        final user = _users[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(AdminUserModel user) {
    final roleColor = _getRoleBadgeColor(user.role);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: roleColor.withValues(alpha: 0.15),
              foregroundColor: roleColor,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          user.rawRole ?? user.role.value,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (user.isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          border: Border.all(
                            color: (user.isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          user.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: user.isActive ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (user.phone != null && user.phone!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          user.phone!,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  if (user.email != null && user.email!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            user.email!,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (user.storeId != null && user.storeId!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Store: ${user.storeId}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar() {
    final totalPages = (_totalUsers / _pageSize).ceil();

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page $_currentPage of $totalPages ($_totalUsers total)',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _currentPage > 1 ? () => _loadUsers(page: _currentPage - 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _currentPage < totalPages ? () => _loadUsers(page: _currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRoleLabel(String role) {
    return switch (role) {
      'ALL' => 'All Users',
      'CUSTOMER' => 'Customers',
      'STAFF' => 'Staff',
      'MANAGER' => 'Managers',
      'DRIVER' => 'Drivers',
      'SUPER_ADMIN' => 'Admins',
      _ => role,
    };
  }

  Color _getRoleBadgeColor(UserRole role) {
    return switch (role) {
      UserRole.customer => AppColors.primary,
      UserRole.storeStaff || UserRole.storeManager => const Color(0xFF2563EB),
      UserRole.deliveryRider => const Color(0xFFEA580C),
      UserRole.superAdmin => const Color(0xFF7C3AED),
      UserRole.unknown => AppColors.textSecondary,
    };
  }
}
