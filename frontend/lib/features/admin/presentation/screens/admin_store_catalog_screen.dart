import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/flutter_secure_storage_impl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/widgets/auth_scope.dart';
import '../../../customer/domain/models/product_model.dart';
import '../../../store/data/repositories/store_categories_repository_impl.dart';
import '../../../store/data/repositories/store_products_repository_impl.dart';
import '../../../store/domain/models/store_category_model.dart';
import '../../../store/domain/repositories/store_categories_repository.dart';
import '../../../store/domain/repositories/store_products_repository.dart';
import '../../../store/presentation/widgets/create_product_dialog.dart';
import '../../../store/presentation/widgets/edit_product_dialog.dart';
import '../../domain/models/admin_store_model.dart';
import '../../domain/repositories/admin_stores_repository.dart';
import '../widgets/admin_csv_import_dialog.dart';
import '../widgets/admin_scope.dart';

/// Store catalog oversight and product management screen for Super Admin.
class AdminStoreCatalogScreen extends StatefulWidget {
  final String? initialStoreId;
  final AdminStoresRepository? storesRepository;
  final StoreProductsRepository? productsRepository;
  final StoreCategoriesRepository? categoriesRepository;
  final AuthRepository? authRepository;
  final bool? isSuperAdmin;
  final Future<SelectedCsvFile?> Function()? onPickCsvFile;

  const AdminStoreCatalogScreen({
    super.key,
    this.initialStoreId,
    this.storesRepository,
    this.productsRepository,
    this.categoriesRepository,
    this.authRepository,
    this.isSuperAdmin,
    this.onPickCsvFile,
  });

  @override
  State<AdminStoreCatalogScreen> createState() =>
      _AdminStoreCatalogScreenState();
}

class _AdminStoreCatalogScreenState extends State<AdminStoreCatalogScreen> {
  bool _isLoadingStores = true;
  String? _storesErrorMessage;
  List<AdminStoreModel> _stores = const [];
  String? _selectedStoreId;

  bool _isLoadingProducts = false;
  String? _productsErrorMessage;
  List<ProductModel> _products = const [];
  List<StoreCategoryModel> _categories = const [];
  String? _selectedCategory;
  String _searchQuery = '';
  bool _hasInitialized = false;

  AdminStoresRepository get _storesRepo =>
      widget.storesRepository ?? AdminScope.storesRepositoryOf(context);

  StoreProductsRepository get _productsRepo {
    if (widget.productsRepository != null) return widget.productsRepository!;
    final scopeRepo = AdminScope.productsRepositoryOf(context);
    if (scopeRepo != null) return scopeRepo;

    final config = AppConfig.fromEnvironment();
    final apiClient = DefaultApiClient(
      baseUrl: config.apiBaseUrl,
      tokenProvider: () =>
          const FlutterSecureStorageImpl().read(key: StorageKeys.authToken),
      timeout: config.connectTimeout,
    );
    return StoreProductsRepositoryImpl(apiClient: apiClient);
  }

  StoreCategoriesRepository get _categoriesRepo {
    if (widget.categoriesRepository != null) {
      return widget.categoriesRepository!;
    }
    final scopeRepo = AdminScope.categoriesRepositoryOf(context);
    if (scopeRepo != null) return scopeRepo;

    final config = AppConfig.fromEnvironment();
    final apiClient = DefaultApiClient(
      baseUrl: config.apiBaseUrl,
      tokenProvider: () =>
          const FlutterSecureStorageImpl().read(key: StorageKeys.authToken),
      timeout: config.connectTimeout,
    );
    return StoreCategoriesRepositoryImpl(apiClient: apiClient);
  }

  bool _isSuperAdmin = true;

  @override
  void initState() {
    super.initState();
    if (widget.isSuperAdmin != null) {
      _isSuperAdmin = widget.isSuperAdmin!;
    }
  }

  @override
  void didUpdateWidget(AdminStoreCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSuperAdmin != oldWidget.isSuperAdmin && widget.isSuperAdmin != null) {
      setState(() {
        _isSuperAdmin = widget.isSuperAdmin!;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      _checkSuperAdminRole();
      _loadStores();
    }
  }

  Future<void> _checkSuperAdminRole() async {
    if (widget.isSuperAdmin != null) {
      setState(() => _isSuperAdmin = widget.isSuperAdmin!);
      return;
    }

    final authRepo = widget.authRepository ?? AuthScope.maybeOf(context);
    if (authRepo != null) {
      final userRes = await authRepo.getCurrentUser();
      if (mounted && userRes.isSuccess) {
        final user = userRes.dataOrNull;
        setState(() {
          _isSuperAdmin = user?.role.isSuperAdmin ?? false;
        });
      }
    }
  }

  void _openCsvImportDialog() {
    if (!_isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access Restricted: Only Super Admins can import products via CSV.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final storeId = _selectedStoreId;
    if (storeId == null) return;

    final selectedStore = _stores.where((s) => s.id == storeId).firstOrNull;

    AdminCsvImportDialog.show(
      context,
      storeId: storeId,
      storeName: selectedStore?.name,
      productsRepository: _productsRepo,
      onPickFile: widget.onPickCsvFile,
    ).then((result) {
      if (result != null && mounted) {
        _loadProductsForStore(storeId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'CSV Import complete: ${result.imported} imported, ${result.updated} updated, ${result.skipped} skipped',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  Future<void> _loadStores() async {
    setState(() {
      _isLoadingStores = true;
      _storesErrorMessage = null;
    });

    final result = await _storesRepo.getStores();

    if (!mounted) return;

    if (result.isSuccess) {
      final stores = result.dataOrNull ?? [];
      setState(() {
        _stores = stores;
        _isLoadingStores = false;
        if (stores.isNotEmpty) {
          final matched = stores.any((s) => s.id == widget.initialStoreId);
          _selectedStoreId = matched ? widget.initialStoreId : stores.first.id;
        }
      });
      if (_selectedStoreId != null) {
        _loadProductsForStore(_selectedStoreId!);
      }
    } else {
      setState(() {
        _isLoadingStores = false;
        _storesErrorMessage =
            result.failureOrNull?.message ?? 'Failed to load stores';
      });
    }
  }

  Future<void> _loadProductsForStore(String storeId) async {
    setState(() {
      _isLoadingProducts = true;
      _productsErrorMessage = null;
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
        _isLoadingProducts = false;
      });
    } else {
      setState(() {
        _isLoadingProducts = false;
        _productsErrorMessage =
            productsRes.failureOrNull?.message ?? 'Failed to load catalog';
      });
    }
  }

  Future<void> _toggleProductAvailability(
    ProductModel product,
    bool newStatus,
  ) async {
    final storeId = _selectedStoreId;
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
    final storeId = _selectedStoreId;
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
    final storeId = _selectedStoreId;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Catalog Oversight'),
        actions: [
          if (_isSuperAdmin && _selectedStoreId != null)
            IconButton(
              key: const Key('admin_catalog_csv_import_btn'),
              icon: const Icon(Icons.upload_file_rounded),
              tooltip: 'Import Products via CSV',
              onPressed: (_isLoadingStores || _isLoadingProducts)
                  ? null
                  : _openCsvImportDialog,
            ),
          IconButton(
            key: const Key('admin_catalog_refresh_btn'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: (_isLoadingStores || _isLoadingProducts)
                ? null
                : () {
                    if (_selectedStoreId != null) {
                      _loadProductsForStore(_selectedStoreId!);
                    } else {
                      _loadStores();
                    }
                  },
          ),
        ],
      ),
      floatingActionButton: _selectedStoreId != null
          ? FloatingActionButton.extended(
              key: const Key('admin_add_product_fab'),
              heroTag: 'admin_add_product_fab',
              onPressed: _openCreateProductDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildStoreSelector(),
            const Divider(height: 1),
            _buildFilters(),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreSelector() {
    if (_isLoadingStores) {
      return const Padding(
        padding: EdgeInsets.all(AppDimensions.spacingMd),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_storesErrorMessage != null) {
      return Container(
        color: const Color(0xFFFEF2F2),
        padding: const EdgeInsets.all(AppDimensions.spacingSm),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _storesErrorMessage!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
            TextButton(
              onPressed: _loadStores,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_stores.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: DropdownButtonFormField<String>(
        key: const Key('admin_catalog_store_dropdown'),
        // ignore: deprecated_member_use
        value: _selectedStoreId,
        decoration: InputDecoration(
          labelText: 'Select Store Branch',
          prefixIcon: const Icon(Icons.storefront_rounded, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: const BorderSide(color: AppColors.borderSubtle),
          ),
        ),
        items: _stores.map((s) {
          return DropdownMenuItem<String>(
            value: s.id,
            child: Text(
              '${s.name}${s.areaName != null ? ' (${s.areaName})' : ''}',
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          );
        }).toList(),
        onChanged: (newStoreId) {
          if (newStoreId != null && newStoreId != _selectedStoreId) {
            setState(() {
              _selectedStoreId = newStoreId;
              _selectedCategory = 'ALL';
              _searchQuery = '';
            });
            _loadProductsForStore(newStoreId);
          }
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: Column(
        children: [
          TextField(
            key: const Key('admin_catalog_search_input'),
            decoration: InputDecoration(
              hintText: 'Search products by name or category...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
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
                  _buildCategoryChip('ALL', 'All Items'),
                  ..._categories.map((c) => _buildCategoryChip(c.name, c.name)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String categoryId, String label) {
    final isSelected =
        (_selectedCategory == null && categoryId == 'ALL') ||
        _selectedCategory == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: AppDimensions.spacingXs),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedCategory = categoryId == 'ALL' ? null : categoryId;
          });
        },
        selectedColor: AppColors.primaryLight,
        checkmarkColor: AppColors.primaryDark,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_productsErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'Unable to Load Catalog',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                _productsErrorMessage!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton.icon(
                key: const Key('products_retry_btn'),
                onPressed: () {
                  if (_selectedStoreId != null) {
                    _loadProductsForStore(_selectedStoreId!);
                  }
                },
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
        onRefresh: () async {
          if (_selectedStoreId != null) {
            await _loadProductsForStore(_selectedStoreId!);
          }
        },
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      'No Products in Catalog',
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the button below to add products to this store branch.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    Wrap(
                      spacing: AppDimensions.spacingSm,
                      runSpacing: AppDimensions.spacingSm,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          key: const Key('empty_add_product_btn'),
                          onPressed: _openCreateProductDialog,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add First Product'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, AppDimensions.buttonHeight),
                          ),
                        ),
                        if (_isSuperAdmin)
                          OutlinedButton.icon(
                            key: const Key('empty_csv_import_btn'),
                            onPressed: _openCsvImportDialog,
                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                            label: const Text('Import CSV'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, AppDimensions.buttonHeight),
                            ),
                          ),
                      ],
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
      onRefresh: () async {
        if (_selectedStoreId != null) {
          await _loadProductsForStore(_selectedStoreId!);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spacingMd,
          AppDimensions.spacingMd,
          AppDimensions.spacingMd,
          80, // FAB padding
        ),
        itemCount: displayProducts.length,
        itemBuilder: (context, index) {
          final product = displayProducts[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
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
            // Product Icon / Thumbnail
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: const Icon(
                Icons.shopping_basket_outlined,
                color: AppColors.textTertiary,
                size: 26,
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
                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (product.category != null && product.category!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.category!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
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

            // Availability Badge & Controls
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: product.isAvailable
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
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
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Inline Availability Switch
                    Transform.scale(
                      scale: 0.8,
                      child: Switch.adaptive(
                        key: Key('product_toggle_${product.id}'),
                        value: product.isAvailable,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) => _toggleProductAvailability(product, val),
                      ),
                    ),
                    // Edit Product Button
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
            ),
          ],
        ),
      ),
    );
  }
}
