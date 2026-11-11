import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../customer/domain/models/product_model.dart';
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
      }).toList()..sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _categories = derivedCategories;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            result.failureOrNull?.message ?? 'Failed to load store categories';
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
      body: SafeArea(child: _buildBody(isManager)),
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
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'Failed to Load Categories',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
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
                    const Icon(
                      Icons.category_outlined,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      'No Categories Found',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isManager
                          ? 'Tap the button below to add categories for this store.'
                          : 'No categories currently registered for this store.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
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
              onTap: () {
                final storeId = _effectiveStoreId;
                if (storeId != null && storeId.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StoreCategoryDetailScreen(
                        storeId: storeId,
                        category: cat,
                        productsRepository: _productsRepo,
                      ),
                    ),
                  );
                }
              },
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: const Icon(
                  Icons.category_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(
                cat.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Sort order: ${cat.sortOrder}'),
              trailing: cat.productCount != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull,
                        ),
                      ),
                      child: Text(
                        '${cat.productCount} items',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            ),
          );
        },
      ),
    );
  }
}

/// Detail screen showing products belonging to a specific category.
class StoreCategoryDetailScreen extends StatefulWidget {
  final String storeId;
  final StoreCategoryModel category;
  final StoreProductsRepository productsRepository;

  const StoreCategoryDetailScreen({
    super.key,
    required this.storeId,
    required this.category,
    required this.productsRepository,
  });

  @override
  State<StoreCategoryDetailScreen> createState() =>
      _StoreCategoryDetailScreenState();
}

class _StoreCategoryDetailScreenState extends State<StoreCategoryDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ProductModel> _products = const [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.productsRepository.getStoreProducts(
      widget.storeId,
    );
    if (!mounted) return;

    if (result.isSuccess) {
      final all = result.dataOrNull ?? [];
      final filtered = all.where((p) {
        final cat = p.category?.trim();
        final catId = p.categoryId?.trim();
        return cat == widget.category.name || catId == widget.category.id;
      }).toList();

      setState(() {
        _products = filtered;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            result.failureOrNull?.message ?? 'Failed to load category products';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.category.name),
        actions: [
          IconButton(
            key: const Key('category_detail_refresh_btn'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadProducts,
          ),
        ],
      ),
      body: SafeArea(child: _buildContent()),
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
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'Failed to Load Products',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton.icon(
                key: const Key('category_products_retry_btn'),
                onPressed: _loadProducts,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadProducts,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      'No Products Found',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No products currently assigned to "${widget.category.name}".',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
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
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final p = _products[index];
          return Card(
            key: Key('category_product_card_${p.id}'),
            margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                clipBehavior: Clip.antiAlias,
                child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                    ? Image.network(
                        p.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
              ),
              title: Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Row(
                children: [
                  if (p.hasOffer) ...[
                    Text(
                      'AED ${p.offerPrice!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AED ${p.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'AED ${p.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (p.loyaltyPointsPerUnit > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull,
                        ),
                      ),
                      child: Text(
                        '+${p.loyaltyPointsPerUnit} pts',
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: p.isAvailable
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusFull,
                  ),
                ),
                child: Text(
                  p.isAvailable ? 'Available' : 'Hidden',
                  style: TextStyle(
                    color: p.isAvailable
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB91C1C),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
