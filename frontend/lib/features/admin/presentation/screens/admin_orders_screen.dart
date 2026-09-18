import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/admin_store_model.dart';
import '../../domain/repositories/admin_stores_repository.dart';
import '../widgets/admin_scope.dart';

/// Orders oversight screen for Super Admin.
///
/// Clarifies the backend contract constraint: Global system-wide unconstrained order aggregation
/// is not exposed by the current production backend. Store-scoped order querying is available per store.
class AdminOrdersScreen extends StatefulWidget {
  final AdminStoresRepository? storesRepository;

  const AdminOrdersScreen({
    super.key,
    this.storesRepository,
  });

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  bool _isLoadingStores = true;
  List<AdminStoreModel> _stores = const [];
  String? _selectedStoreId;

  AdminStoresRepository get _storesRepo =>
      widget.storesRepository ?? AdminScope.storesRepositoryOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoadingStores = true);

    final result = await _storesRepo.getStores();

    if (!mounted) return;

    if (result.isSuccess) {
      final stores = result.dataOrNull ?? [];
      setState(() {
        _stores = stores;
        _isLoadingStores = false;
        if (stores.isNotEmpty) {
          _selectedStoreId = stores.first.id;
        }
      });
    } else {
      setState(() => _isLoadingStores = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Orders Oversight'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice Card
              Card(
                color: const Color(0xFFF8FAFC),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingMd),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Orders Oversight Architecture',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The production backend provides order querying via `GET /orders`, supporting both platform-wide order oversight and store-specific scoping (`GET /orders?store_id=:storeId`). Store staff and riders manage operational order fulfillment directly in their designated portals.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
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

              // Store Selector
              if (_isLoadingStores)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.spacingLg),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                )
              else if (_stores.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacingLg),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.store_mall_directory_outlined,
                          size: 40,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          'No Stores Available',
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create store locations first to inspect store-specific orders.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Text(
                  'Select Store for Order Stream',
                  style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                DropdownButtonFormField<String>(
                  key: const Key('admin_orders_store_dropdown'),
                  value: _selectedStoreId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.storefront_rounded, size: 20),
                  ),
                  items: _stores.map((s) {
                    return DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(s.name),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedStoreId = val),
                ),
                const SizedBox(height: AppDimensions.spacingLg),

                // Order Stream Status
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacingXl),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            size: 30,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                        Text(
                          'Store Orders Stream Active',
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Staff and managers process incoming orders for this store directly in the Store Operations portal.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
