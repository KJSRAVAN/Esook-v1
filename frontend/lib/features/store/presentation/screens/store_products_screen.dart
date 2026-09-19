import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../customer/domain/models/product_model.dart';
import '../../domain/models/store_category_model.dart';
import '../../domain/repositories/store_categories_repository.dart';
import '../../domain/repositories/store_products_repository.dart';
import '../widgets/create_product_dialog.dart';
import '../widgets/edit_product_dialog.dart';
import '../widgets/store_scope.dart';

/// Products catalog management screen for Store Staff and Managers.
class StoreProductsScreen extends StatefulWidget {
  final String? storeId;
  final StoreProductsRepository? productsRepository;
  final StoreCategoriesRepository? categoriesRepository;

  const StoreProductsScreen({
    super.key,
    this.storeId,
    this.productsRepository,
    this.categoriesRepository,
  });

  @override
  State<StoreProductsScreen> createState() => _StoreProductsScreenState();
}

class _StoreProductsScreenState extends State<StoreProductsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ProductModel> _products = const [];
  List<StoreCategoryModel> _categories = const [];
  String? _selectedCategory;
  String _searchQuery = '';

  String? get _effectiveStoreId =>
      widget.storeId ?? StoreScope.storeIdOf(context);

  StoreProductsRepository get _productsRepo =>
      widget.productsRepository ?? StoreScope.productsRepositoryOf(context);

  StoreCategoriesRepository get _categoriesRepo =>
      widget.categoriesRepository ?? StoreScope.categoriesRepositoryOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProductsAndCategories();
  }

  Future<void> _loadProductsAndCategories() async {
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

    final productsRes = await _productsRepo.getStoreProducts(storeId);

    if (!mounted) return;

    if (productsRes.isSuccess) {
      final prods = productsRes.dataOrNull ?? [];
      final derivedCategories =
          prods
              .map((p) => p.category?.trim())
              .where((c) => c != null && c.isNotEmpty)
              .cast<String>()
              .toSet()
              .map((c) => StoreCategoryModel(id: c, name: c, storeId: storeId))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _products = prods;
        _categories = derivedCategories;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            productsRes.failureOrNull?.message ??
            'Failed to load store products';
      });
    }
  }

  Future<void> _toggleProductAvailability(
    ProductModel product,
    bool newStatus,
  ) async {
    final storeId = _effectiveStoreId;
    if (storeId == null) return;

    final result = await _productsRepo.toggleAvailability(
      storeId: storeId,
      productId: product.id,
      isAvailable: newStatus,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final updated = result.dataOrNull!;
      setState(() {
        _products = _products
            .map((p) => p.id == updated.id ? updated : p)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${product.name} is now ${newStatus ? "Available" : "Unavailable"}',
          ),
          backgroundColor: newStatus
              ? AppColors.success
              : AppColors.textSecondary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failureOrNull?.message ?? 'Failed to toggle availability',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openCreateProductDialog() {
    final storeId = _effectiveStoreId;
    if (storeId == null) return;

    CreateProductDialog.show(
      context,
      storeId: storeId,
      productsRepository: _productsRepo,
      categoriesRepository: _categoriesRepo,
    ).then((created) {
      if (created != null && mounted) {
        setState(() => _products = [created, ..._products]);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${created.name} created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  void _openEditProductDialog(ProductModel product) {
    final storeId = _effectiveStoreId;
    if (storeId == null) return;

    EditProductDialog.show(
      context,
      storeId: storeId,
      product: product,
      productsRepository: _productsRepo,
      categoriesRepository: _categoriesRepo,
    ).then((updated) {
      if (updated != null && mounted) {
        setState(() {
          _products = _products
              .map((p) => p.id == updated.id ? updated : p)
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updated.name} updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  List<ProductModel> get _filteredProducts {
    var list = _products;

    if (_selectedCategory != null && _selectedCategory != 'ALL') {
      list = list
          .where(
            (p) =>
                p.category == _selectedCategory ||
                p.categoryId == _selectedCategory,
          )
          .toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((p) {
        final matchName = p.name.toLowerCase().contains(q);
        final matchDesc = p.description?.toLowerCase().contains(q) ?? false;
        final matchCat = p.category?.toLowerCase().contains(q) ?? false;
        return matchName || matchDesc || matchCat;
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = StoreScope.currentUserOf(context);
    final isManager = currentUser?.role.isStoreManager ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Products'),
        actions: [
          IconButton(
            key: const Key('store_products_refresh_btn'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadProductsAndCategories,
          ),
        ],
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              key: const Key('store_add_product_fab'),
              onPressed: _openCreateProductDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product'),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Search & Category Filters
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: Column(
                children: [
                  TextField(
                    key: const Key('store_products_search_input'),
                    decoration: InputDecoration(
                      hintText: 'Search product name or category...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                        borderSide: const BorderSide(
                          color: AppColors.borderSubtle,
                        ),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  if (_categories.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingSm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryFilterChip(null, 'All Categories'),
                          ..._categories.map(
                            (c) => _buildCategoryFilterChip(c.id, c.name),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // Product List
            Expanded(child: _buildProductsList(isManager)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip(String? categoryId, String label) {
    final isSelected = _selectedCategory == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryLight,
        checkmarkColor: AppColors.primaryDark,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? categoryId : null;
          });
        },
      ),
    );
  }

  Widget _buildProductsList(bool isManager) {
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
              Text('Failed to Load Products', style: AppTextStyles.titleMedium),
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
                key: const Key('products_retry_btn'),
                onPressed: _loadProductsAndCategories,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final displayProducts = _filteredProducts;

    if (displayProducts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadProductsAndCategories,
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
                      'No Products in Catalog',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isManager
                          ? 'Tap the button below to add items to this store.'
                          : 'No items found matching the current search criteria.',
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
      onRefresh: _loadProductsAndCategories,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        itemCount: displayProducts.length,
        itemBuilder: (context, index) {
          final product = displayProducts[index];
          return _buildProductCard(product, isManager);
        },
      ),
    );
  }

  Widget _buildProductCard(ProductModel product, bool isManager) {
    return Card(
      key: Key('store_product_card_${product.id}'),
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image or Icon
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: const Icon(
                Icons.shopping_basket_outlined,
                color: AppColors.textTertiary,
                size: 28,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (product.category != null &&
                      product.category!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.category!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${product.price.toStringAsFixed(2)} AED',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Status Badge & Controls
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: product.isAvailable
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusFull,
                    ),
                  ),
                  child: Text(
                    product.isAvailable ? 'Available' : 'Unavailable',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: product.isAvailable
                          ? const Color(0xFF15803D)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isManager) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Inline Availability Toggle
                      Transform.scale(
                        scale: 0.8,
                        child: Switch.adaptive(
                          key: Key('product_toggle_${product.id}'),
                          value: product.isAvailable,
                          activeColor: AppColors.primary,
                          onChanged: (val) =>
                              _toggleProductAvailability(product, val),
                        ),
                      ),
                      // Edit Button
                      IconButton(
                        key: Key('product_edit_btn_${product.id}'),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit Product',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _openEditProductDialog(product),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
