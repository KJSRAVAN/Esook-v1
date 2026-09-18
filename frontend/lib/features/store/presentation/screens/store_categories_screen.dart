import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/store_category_model.dart';
import '../../domain/repositories/store_categories_repository.dart';
import '../../domain/repositories/store_products_repository.dart';
import '../widgets/store_scope.dart';

/// Categories management screen for Store Staff and Managers.
///
/// NOTE: The backend does not have a standalone categories entity or endpoint.
/// Categories are derived in-memory from products in the store's catalog.
class StoreCategoriesScreen extends StatefulWidget {
  final String? storeId;
  final StoreCategoriesRepository? categoriesRepository;
  final StoreProductsRepository? productsRepository;

  const StoreCategoriesScreen({
    super.key,
    this.storeId,
    this.categoriesRepository,
    this.productsRepository,
  });

  @override
  State<StoreCategoriesScreen> createState() => _StoreCategoriesScreenState();
}

class _StoreCategoriesScreenState extends State<StoreCategoriesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<StoreCategoryModel> _categories = const [];

  String? get _effectiveStoreId =>
      widget.storeId ?? StoreScope.storeIdOf(context);

  StoreProductsRepository get _productsRepo =>
      widget.productsRepository ?? StoreScope.productsRepositoryOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final storeId = _effectiveStoreId;
    if (storeId == null || storeId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Store ID is not available';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _productsRepo.getStoreProducts(storeId);

    if (!mounted) return;

    if (result.isSuccess) {
      final products = result.dataOrNull ?? [];
      final categoryMap = <String, int>{};
      for (final p in products) {
        final cat = p.category?.trim();
        if (cat != null && cat.isNotEmpty) {
          categoryMap[cat] = (categoryMap[cat] ?? 0) + 1;
        }
      }

      final derivedCategories = categoryMap.entries.map((entry) {
        return StoreCategoryModel(
          id: entry.key,
          name: entry.key,
          storeId: storeId,
          productCount: entry.value,
        );
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _categories = derivedCategories;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.failureOrNull?.message ?? 'Failed to load store categories';
      });
    }
  }

  void _showAddCategoryDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: const Text(
            'Direct category creation is not supported by the backend API.\n\n'
            'Categories are dynamically derived from your product catalog. '
            'To add a new category, specify it in the Category field when creating or updating a product.',
          ),
          actions: [
            TextButton(
              key: const Key('category_gap_dismiss_btn'),
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Understood'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = StoreScope.currentUserOf(context);
    final isManager = currentUser?.role.isStoreManager ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Categories'),
        actions: [
          IconButton(
            key: const Key('store_categories_refresh_btn'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadCategories,
          ),
        ],
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              key: const Key('store_add_category_fab'),
              onPressed: _showAddCategoryDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Category'),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: SafeArea(
        child: _buildBody(isManager),
      ),
    );
  }

  Widget _buildBody(bool isManager) {
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
              Text('Failed to Load Categories', style: AppTextStyles.titleMedium),
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton.icon(
                key: const Key('categories_retry_btn'),
                onPressed: _loadCategories,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadCategories,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.category_outlined, size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      'No Categories Found',
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isManager
                          ? 'Tap the button below to add categories for this store.'
                          : 'No categories currently registered for this store.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return Card(
            key: Key('store_category_card_${cat.id}'),
            margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: const Icon(Icons.category_outlined, color: AppColors.primary, size: 20),
              ),
              title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Sort order: ${cat.sortOrder}'),
              trailing: cat.productCount != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      child: Text(
                        '${cat.productCount} items',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
