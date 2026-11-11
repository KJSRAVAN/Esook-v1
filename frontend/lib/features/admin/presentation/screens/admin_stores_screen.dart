import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/admin_store_model.dart';
import '../../domain/repositories/admin_stores_repository.dart';
import '../widgets/admin_scope.dart';
import '../widgets/create_store_dialog.dart';
import '../widgets/edit_store_dialog.dart';
import '../widgets/store_loyalty_dialog.dart';
import 'admin_store_catalog_screen.dart';
import 'admin_store_staff_screen.dart';

/// Store management screen for Super Admin to onboard and configure supermarket locations.
class AdminStoresScreen extends StatefulWidget {
  final AdminStoresRepository? storesRepository;

  const AdminStoresScreen({super.key, this.storesRepository});

  @override
  State<AdminStoresScreen> createState() => _AdminStoresScreenState();
}

class _AdminStoresScreenState extends State<AdminStoresScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AdminStoreModel> _stores = const [];

  AdminStoresRepository get _repo =>
      widget.storesRepository ?? AdminScope.storesRepositoryOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repo.getStores();

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _stores = result.dataOrNull ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            result.failureOrNull?.message ?? 'Failed to load stores';
      });
    }
  }

  Future<void> _openCreateStoreDialog() async {
    final createdStore = await CreateStoreDialog.show(
      context,
      storesRepository: _repo,
    );

    if (createdStore != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Store "${createdStore.name}" created successfully!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
      _loadStores();
      await _showStaffSetupPrompt(createdStore);
    }
  }

  Future<void> _showStaffSetupPrompt(AdminStoreModel store) async {
    final setupStaff = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        key: const Key('post_create_staff_prompt_dialog'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                color: AppColors.primaryDark,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Configure Staff Accounts?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Store "${store.name}" was successfully onboarded. Would you like to configure staff login accounts for this store now? You can also skip and manage staff anytime from the store card.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            key: const Key('skip_staff_setup_btn'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Skip for Now'),
          ),
          ElevatedButton.icon(
            key: const Key('setup_staff_now_btn'),
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Configure Staff'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (setupStaff == true && mounted) {
      _navigateToStaffScreen(store);
    }
  }

  void _navigateToStaffScreen(AdminStoreModel store) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminStoreStaffScreen(
          store: store,
          usersRepository: AdminScope.usersRepositoryOf(context),
        ),
      ),
    );
  }


  Future<void> _openEditStoreDialog(AdminStoreModel store) async {
    final updatedStore = await EditStoreDialog.show(
      context,
      store: store,
      storesRepository: _repo,
    );

    if (updatedStore != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Store "${updatedStore.name}" updated successfully!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
      _loadStores();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Management'),
        actions: [
          IconButton(
            key: const Key('stores_refresh_button'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadStores,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_store_fab'),
        heroTag: 'admin_stores_fab',
        onPressed: _openCreateStoreDialog,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add Store'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: _buildBody()),
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
                'Unable to Load Stores',
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
                key: const Key('stores_retry_button'),
                onPressed: _loadStores,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_stores.isEmpty) {
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
                  Icons.storefront_rounded,
                  size: 36,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'No Stores Registered',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                'Onboard store branches and assign them to delivery areas to start catalog operations.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              ElevatedButton.icon(
                key: const Key('empty_add_store_button'),
                onPressed: _openCreateStoreDialog,
                icon: const Icon(Icons.add_business_rounded, size: 18),
                label: const Text('Onboard First Store'),
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
        80, // Padding for FAB
      ),
      itemCount: _stores.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.spacingSm),
      itemBuilder: (context, index) {
        final store = _stores[index];
        return Card(
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: store.isActive
                                ? AppColors.primaryLight
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSm,
                            ),
                          ),
                          child: Icon(
                            Icons.storefront_rounded,
                            color: store.isActive
                                ? AppColors.primaryDark
                                : AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingSm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.name,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (store.areaName != null)
                              Text(
                                'Area: ${store.areaName}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      key: Key('edit_store_button_${store.id}'),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edit Store',
                      onPressed: () => _openEditStoreDialog(store),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                const Divider(),
                const SizedBox(height: AppDimensions.spacingXs),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: store.isActive
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull,
                        ),
                        border: Border.all(
                          color: store.isActive
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        store.isActive ? 'Active' : 'Disabled',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: store.isActive
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (store.phone != null && store.phone!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            store.phone!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (store.address != null && store.address!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          store.address!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      key: Key('manage_loyalty_btn_${store.id}'),
                      icon: const Icon(Icons.stars_rounded, size: 16, color: Color(0xFFD97706)),
                      label: const Text('Loyalty'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                        side: const BorderSide(color: Color(0xFFD97706)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        StoreLoyaltyDialog.show(
                          context,
                          storeId: store.id,
                          storeName: store.name,
                          apiClient: AdminScope.apiClientOf(context),
                        );
                      },
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    OutlinedButton.icon(
                      key: Key('manage_staff_btn_${store.id}'),
                      icon: const Icon(Icons.people_outline_rounded, size: 16),
                      label: const Text('Manage Staff'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderStrong),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _navigateToStaffScreen(store),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    OutlinedButton.icon(
                      key: Key('manage_catalog_btn_${store.id}'),
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: const Text('Manage Catalog'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminStoreCatalogScreen(
                              initialStoreId: store.id,
                              storesRepository: _repo,
                              productsRepository:
                                  AdminScope.productsRepositoryOf(context),
                              categoriesRepository:
                                  AdminScope.categoriesRepositoryOf(context),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
