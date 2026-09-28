import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../domain/models/admin_store_model.dart';
import '../../domain/models/admin_user_model.dart';
import '../../domain/repositories/admin_users_repository.dart';
import '../widgets/admin_scope.dart';

/// Screen allowing Super Admin to view, create, edit, activate/deactivate,
/// and permanently delete STAFF and MANAGER accounts assigned to a specific store.
/// Integrates with:
/// - GET /users?role=STAFF & GET /users?role=MANAGER
/// - POST /users/staff
/// - PATCH /users/staff/:userId
/// - DELETE /users/staff/:userId
class AdminStoreStaffScreen extends StatefulWidget {
  final AdminStoreModel store;
  final AdminUsersRepository? usersRepository;

  const AdminStoreStaffScreen({
    super.key,
    required this.store,
    this.usersRepository,
  });

  @override
  State<AdminStoreStaffScreen> createState() => _AdminStoreStaffScreenState();
}

class _AdminStoreStaffScreenState extends State<AdminStoreStaffScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AdminUserModel> _staffList = const [];

  AdminUsersRepository get _repo =>
      widget.usersRepository ?? AdminScope.usersRepositoryOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Query both STAFF and MANAGER accounts
    final staffResult = await _repo.getUsers(role: 'STAFF');
    final managerResult = await _repo.getUsers(role: 'MANAGER');

    if (!mounted) return;

    if (staffResult.isSuccess || managerResult.isSuccess) {
      final allStaff = staffResult.dataOrNull?.users ?? [];
      final allManagers = managerResult.dataOrNull?.users ?? [];
      final combined = <AdminUserModel>[...allStaff, ...allManagers];

      // De-duplicate in case a user is in both lists
      final seenIds = <String>{};
      final uniqueUsers = <AdminUserModel>[];
      for (final u in combined) {
        if (seenIds.add(u.id)) {
          uniqueUsers.add(u);
        }
      }

      // Filter staff assigned to this specific store
      final storeStaff = uniqueUsers.where((u) {
        if (u.storeId == null) return false;
        return u.storeId == widget.store.id;
      }).toList();

      setState(() {
        _isLoading = false;
        _staffList = storeStaff;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            staffResult.failureOrNull?.message ??
            managerResult.failureOrNull?.message ??
            'Failed to load staff list';
      });
    }
  }

  Future<void> _openAddStaffDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _AddStaffDialog(
        store: widget.store,
        usersRepository: _repo,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff account created successfully.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
      _loadStaff();
    }
  }

  Future<void> _openEditStaffDialog(AdminUserModel staff) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _EditStaffDialog(
        staff: staff,
        store: widget.store,
        usersRepository: _repo,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff account updated successfully.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
      _loadStaff();
    }
  }

  Future<void> _toggleStaffActive(AdminUserModel staff) async {
    final newActiveState = !staff.isActive;
    final actionLabel = newActiveState ? 'activate' : 'deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${newActiveState ? 'Activate' : 'Deactivate'} Staff Account?',
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to $actionLabel the account for "${staff.name}"?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newActiveState ? AppColors.success : AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: Text(newActiveState ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await _repo.updateStaffAccount(
      userId: staff.id,
      isActive: newActiveState,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account for "${staff.name}" has been ${newActiveState ? 'activated' : 'deactivated'}.',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
      _loadStaff();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failureOrNull?.message ??
                'Failed to update staff active status.',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _confirmDeleteStaff(AdminUserModel staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('confirm_delete_staff_dialog'),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text(
              'Delete Staff Account',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete the account for "${staff.name}" (${staff.email ?? staff.phone ?? staff.id})?\n\nThis action cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            key: const Key('cancel_delete_staff_btn'),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_staff_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await _repo.deleteStaffAccount(staff.id);

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Staff member "${staff.name}" deleted permanently.'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
      _loadStaff();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failureOrNull?.message ?? 'Failed to delete staff account.',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeName = widget.store.name;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store Staff',
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              storeName,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('staff_refresh_btn'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadStaff,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_staff_member_fab'),
        heroTag: 'admin_store_staff_fab',
        onPressed: _openAddStaffDialog,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Staff'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStoreSummaryHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreSummaryHeader() {
    final managerCount =
        _staffList.where((u) => u.role == UserRole.storeManager).length;
    final staffCount =
        _staffList.where((u) => u.role == UserRole.storeStaff).length;
    final activeCount = _staffList.where((u) => u.isActive).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.spacingMd,
        AppDimensions.spacingMd,
        AppDimensions.spacingMd,
        0,
      ),
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.primaryDark,
              size: 24,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.store.name,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.store.areaName != null
                      ? 'Area: ${widget.store.areaName}'
                      : 'Store ID: ${widget.store.id}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            children: [
              _buildBadgeChip(
                label: '$managerCount Mgr',
                color: const Color(0xFF7C3AED),
                bg: const Color(0xFFEDE9FE),
              ),
              _buildBadgeChip(
                label: '$staffCount Staff',
                color: const Color(0xFF2563EB),
                bg: const Color(0xFFDBEAFE),
              ),
              _buildBadgeChip(
                label: '$activeCount Active',
                color: AppColors.success,
                bg: AppColors.success.withValues(alpha: 0.1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip({
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBody() {
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
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'Unable to Load Staff',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton.icon(
                key: const Key('staff_retry_btn'),
                onPressed: _loadStaff,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_staffList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  size: 36,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'No Staff Assigned',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                'No staff or manager accounts are currently associated with "${widget.store.name}".',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              ElevatedButton.icon(
                key: const Key('empty_add_staff_btn'),
                onPressed: _openAddStaffDialog,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Add Staff Member'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingMd,
        AppDimensions.spacingMd,
        AppDimensions.spacingMd,
        80, // Space for FAB
      ),
      itemCount: _staffList.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.spacingSm),
      itemBuilder: (context, index) {
        final staff = _staffList[index];
        return _buildStaffCard(staff);
      },
    );
  }

  Widget _buildStaffCard(AdminUserModel staff) {
    final isManager = staff.role == UserRole.storeManager;
    final roleName = isManager ? 'Manager' : 'Store Staff';
    final roleColor =
        isManager ? const Color(0xFF7C3AED) : const Color(0xFF2563EB);
    final roleBg =
        isManager ? const Color(0xFFEDE9FE) : const Color(0xFFDBEAFE);

    return Card(
      key: Key('staff_card_${staff.id}'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: roleBg,
                      child: Text(
                        staff.name.isNotEmpty
                            ? staff.name.substring(0, 1).toUpperCase()
                            : 'S',
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff.name,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'ID: ${staff.id}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: roleBg,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusFull,
                    ),
                  ),
                  child: Text(
                    roleName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            const Divider(height: 1),
            const SizedBox(height: AppDimensions.spacingSm),

            // Email and Phone
            if (staff.email != null && staff.email!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      staff.email!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            if (staff.phone != null && staff.phone!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      staff.phone!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 4),
            Row(
              children: [
                GestureDetector(
                  key: Key('toggle_active_btn_${staff.id}'),
                  onTap: () => _toggleStaffActive(staff),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: staff.isActive
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusFull,
                      ),
                      border: Border.all(
                        color: staff.isActive
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          staff.isActive
                              ? Icons.check_circle_outline_rounded
                              : Icons.block_rounded,
                          size: 12,
                          color: staff.isActive
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          staff.isActive ? 'Active' : 'Disabled',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: staff.isActive
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  key: Key('edit_staff_btn_${staff.id}'),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () => _openEditStaffDialog(staff),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: Key('delete_staff_btn_${staff.id}'),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                  tooltip: 'Delete Staff Account',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDeleteStaff(staff),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for entering staff credentials and submitting staff account provisioning.
class _AddStaffDialog extends StatefulWidget {
  final AdminStoreModel store;
  final AdminUsersRepository usersRepository;

  const _AddStaffDialog({
    required this.store,
    required this.usersRepository,
  });

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'STAFF';
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    final passwordToSubmit = _passwordController.text;

    final result = await widget.usersRepository.createStaffAccount(
      storeId: widget.store.id,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      role: _selectedRole,
      password: passwordToSubmit,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop(true);
    } else {
      // Clear password on error for safety
      _passwordController.clear();
      setState(() {
        _isSubmitting = false;
        _submissionError =
            result.failureOrNull?.message ??
            'Failed to create staff account. Please verify the information and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final dialogWidth =
        screenWidth < 560 ? (screenWidth - 32).clamp(280.0, 500.0) : 500.0;

    return Dialog(
      key: const Key('add_staff_dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Add Staff Member',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                Text(
                  'Assigning login credentials to: ${widget.store.name}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),

                if (_submissionError != null) ...[
                  Container(
                    key: const Key('staff_dialog_error_banner'),
                    padding: const EdgeInsets.all(AppDimensions.spacingSm),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _submissionError!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                ],

                // Full Name
                TextFormField(
                  key: const Key('staff_name_input'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. Tariq Al-Otaibi',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter staff full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingSm),

                // Email
                TextFormField(
                  key: const Key('staff_email_input'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    hintText: 'e.g. tariq@esook.store',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter email address';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingSm),

                // Phone
                TextFormField(
                  key: const Key('staff_phone_input'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. +966501234567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    if (value != null &&
                        value.trim().isNotEmpty &&
                        value.trim().length < 8) {
                      return 'Phone number must be at least 8 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingSm),

                // Role Selector
                DropdownButtonFormField<String>(
                  key: const Key('staff_role_dropdown'),
                  isExpanded: true,
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Staff Role *',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'STAFF',
                      child: Text('Store Staff'),
                    ),
                    DropdownMenuItem(
                      value: 'MANAGER',
                      child: Text('Store Manager'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedRole = val);
                    }
                  },
                ),
                const SizedBox(height: AppDimensions.spacingSm),

                // Password
                TextFormField(
                  key: const Key('staff_password_input'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Temporary Password *',
                    hintText: 'Minimum 8 characters',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a temporary password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingLg),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    ElevatedButton(
                      key: const Key('staff_submit_btn'),
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 40),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Create Account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog for editing staff details, updating role, activating/deactivating,
/// or resetting password.
class _EditStaffDialog extends StatefulWidget {
  final AdminUserModel staff;
  final AdminStoreModel store;
  final AdminUsersRepository usersRepository;

  const _EditStaffDialog({
    required this.staff,
    required this.store,
    required this.usersRepository,
  });

  @override
  State<_EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends State<_EditStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _passwordController = TextEditingController();

  late String _selectedRole;
  late bool _isActive;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staff.name);
    _emailController = TextEditingController(text: widget.staff.email ?? '');
    _phoneController = TextEditingController(text: widget.staff.phone ?? '');
    _selectedRole =
        widget.staff.role == UserRole.storeManager ? 'MANAGER' : 'STAFF';
    _isActive = widget.staff.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newPhone = _phoneController.text.trim();
    final newPassword = _passwordController.text;

    // Detect which permitted fields actually changed
    final nameToSend = newName != widget.staff.name ? newName : null;
    final emailToSend =
        newEmail != (widget.staff.email ?? '') ? newEmail : null;
    final phoneToSend =
        newPhone != (widget.staff.phone ?? '') ? newPhone : null;
    final originalRole =
        widget.staff.role == UserRole.storeManager ? 'MANAGER' : 'STAFF';
    final roleToSend = _selectedRole != originalRole ? _selectedRole : null;
    final activeToSend = _isActive != widget.staff.isActive ? _isActive : null;
    final passwordToSend = newPassword.isNotEmpty ? newPassword : null;

    if (nameToSend == null &&
        emailToSend == null &&
        phoneToSend == null &&
        roleToSend == null &&
        activeToSend == null &&
        passwordToSend == null) {
      // Nothing changed
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    final result = await widget.usersRepository.updateStaffAccount(
      userId: widget.staff.id,
      name: nameToSend,
      email: emailToSend,
      phone: phoneToSend,
      password: passwordToSend,
      role: roleToSend,
      isActive: activeToSend,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop(true);
    } else {
      _passwordController.clear();
      setState(() {
        _isSubmitting = false;
        _submissionError =
            result.failureOrNull?.message ?? 'Failed to update staff account.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final dialogWidth =
        screenWidth < 560 ? (screenWidth - 32).clamp(280.0, 500.0) : 500.0;

    return Dialog(
      key: const Key('edit_staff_dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Edit Staff Account',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                Text(
                  'Store: ${widget.store.name} • User ID: ${widget.staff.id}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),

                if (_submissionError != null) ...[
                  Container(
                    key: const Key('edit_staff_error_banner'),
                    padding: const EdgeInsets.all(AppDimensions.spacingSm),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _submissionError!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                ],

                // Full Name
                TextFormField(
                  key: const Key('edit_staff_name_input'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter staff full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingSm),

                // Email
                TextFormField(
                  key: const Key('edit_staff_email_input'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter email address';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingSm),

                // Phone
                TextFormField(
                  key: const Key('edit_staff_phone_input'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    if (value != null &&
                        value.trim().isNotEmpty &&
                        value.trim().length < 8) {
                      return 'Phone number must be at least 8 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingSm),

                // Role Selector
                DropdownButtonFormField<String>(
                  key: const Key('edit_staff_role_dropdown'),
                  isExpanded: true,
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Staff Role *',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'STAFF',
                      child: Text('Store Staff'),
                    ),
                    DropdownMenuItem(
                      value: 'MANAGER',
                      child: Text('Store Manager'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedRole = val);
                    }
                  },
                ),
                const SizedBox(height: AppDimensions.spacingSm),

                // Active Status Switch
                SwitchListTile(
                  key: const Key('edit_staff_active_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Account Active Status',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Staff member can log in and manage store operations'
                        : 'Account is deactivated; staff member cannot log in',
                    style: AppTextStyles.bodySmall,
                  ),
                  value: _isActive,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => _isActive = val);
                  },
                ),
                const SizedBox(height: AppDimensions.spacingSm),

                // Password (optional update, never pre-filled)
                TextFormField(
                  key: const Key('edit_staff_password_input'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Reset Password (Optional)',
                    hintText: 'Leave blank to keep current password',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spacingLg),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const Key('edit_staff_cancel_btn'),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    ElevatedButton(
                      key: const Key('edit_staff_submit_btn'),
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 40),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
