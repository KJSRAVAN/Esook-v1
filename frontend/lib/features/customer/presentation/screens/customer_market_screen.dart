import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/points_notifier.dart';
import '../../cart/application/cart_notifier.dart';
import '../../cart/presentation/screens/cart_screen.dart';
import '../../domain/models/product_model.dart';
import '../../domain/models/store_model.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/store_repository.dart';
import '../widgets/category_filter_bar.dart';
import '../widgets/customer_points_badge.dart';
import '../widgets/customer_scope.dart';
import '../widgets/product_card.dart';
import '../widgets/product_detail_sheet.dart';
import '../widgets/store_selection_view.dart';
import 'customer_order_history_screen.dart';

/// Customer Market Screen displaying active store catalog, search, and category filtering.
class CustomerMarketScreen extends StatefulWidget {
  final ProductRepository? productRepository;
  final StoreRepository? storeRepository;
  final ValueNotifier<StoreModel?>? selectedStoreNotifier;
  final CartNotifier? cartNotifier;
  final PointsNotifier? pointsNotifier;
  final VoidCallback? onViewCart;
  final VoidCallback? onOpenOrderHistory;
  final String currency;

  const CustomerMarketScreen({
    super.key,
    this.productRepository,
    this.storeRepository,
    this.selectedStoreNotifier,
    this.cartNotifier,
    this.pointsNotifier,
    this.onViewCart,
    this.onOpenOrderHistory,
    this.currency = AppConstants.defaultCurrency,
  });

  @override
  State<CustomerMarketScreen> createState() => _CustomerMarketScreenState();
}

class _CustomerMarketScreenState extends State<CustomerMarketScreen> {
  final _searchController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  List<ProductModel> _allProducts = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String? _lastLoadedStoreId;

  ProductRepository get _productRepo =>
      widget.productRepository ?? CustomerScope.productRepositoryOf(context);

  StoreRepository get _storeRepo =>
      widget.storeRepository ?? CustomerScope.storeRepositoryOf(context);

  ValueNotifier<StoreModel?> get _storeNotifier =>
      widget.selectedStoreNotifier ??
      CustomerScope.of(context).selectedStoreNotifier;

  CartNotifier? get _cartNotifier =>
      widget.cartNotifier ?? CustomerScope.maybeOf(context)?.cartNotifier;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _storeNotifier.addListener(_onSelectedStoreChanged);
      _checkAndLoadCatalog();
    });
  }

  @override
  void dispose() {
    _storeNotifier.removeListener(_onSelectedStoreChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
      });
    }
  }

  void _onSelectedStoreChanged() {
    final store = _storeNotifier.value;
    if (store != null && store.id != _lastLoadedStoreId) {
      _loadCatalog(store.id);
    } else if (store == null) {
      setState(() {
        _allProducts = [];
        _lastLoadedStoreId = null;
      });
    }
  }

  void _checkAndLoadCatalog() {
    final store = _storeNotifier.value;
    if (store != null) {
      _loadCatalog(store.id);
    }
  }

  Future<void> _loadCatalog(String storeId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _lastLoadedStoreId = storeId;
    });

    final result = await _productRepo.getProductsByStore(storeId);

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _isLoading = false;
        _allProducts = result.dataOrNull ?? [];
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            result.failureOrNull?.message ?? 'Failed to load catalog';
      });
    }
  }

  List<String> _extractCategories() {
    final categories = <String>{'All'};
    for (final product in _allProducts) {
      if (product.category != null && product.category!.trim().isNotEmpty) {
        categories.add(product.category!.trim());
      }
    }
    return categories.toList();
  }

  List<ProductModel> _getFilteredProducts() {
    return _allProducts.where((product) {
      // 1. Category filter
      if (_selectedCategory != 'All') {
        if (product.category == null ||
            product.category!.toLowerCase() !=
                _selectedCategory.toLowerCase()) {
          return false;
        }
      }

      // 2. Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = product.name.toLowerCase().contains(query);
        final descMatch =
            product.description != null &&
            product.description!.toLowerCase().contains(query);
        final catMatch =
            product.category != null &&
            product.category!.toLowerCase().contains(query);

        if (!nameMatch && !descMatch && !catMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _openStoreSelector() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
            ),
            child: StoreSelectionView(
              storeRepository: _storeRepo,
              currentSelectedStore: _storeNotifier.value,
              onStoreSelected: (selectedStore) {
                _storeNotifier.value = selectedStore;
                Navigator.of(sheetContext).pop();
              },
              onCancel: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        );
      },
    );
  }

  void _openOrderHistory() {
    if (widget.onOpenOrderHistory != null) {
      widget.onOpenOrderHistory!();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerOrderHistoryScreen(
          orderRepository: CustomerScope.maybeOf(context)?.orderRepository,
          cartNotifier: _cartNotifier,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StoreModel?>(
      valueListenable: _storeNotifier,
      builder: (context, currentStore, _) {
        if (currentStore == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Market'),
              actions: [
                CustomerPointsBadge(
                  pointsNotifier: widget.pointsNotifier,
                  currency: widget.currency,
                ),
                PopupMenuButton<String>(
                  key: const Key('customer_market_overflow_menu'),
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'More options',
                  onSelected: (val) {
                    if (val == 'order_history') {
                      _openOrderHistory();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem<String>(
                      key: Key('menu_order_history'),
                      value: 'order_history',
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                          SizedBox(width: 8),
                          Text('Order History'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: SafeArea(
              child: StoreSelectionView(
                storeRepository: _storeRepo,
                currentSelectedStore: null,
                onStoreSelected: (store) {
                  _storeNotifier.value = store;
                },
              ),
            ),
          );
        }

        final categories = _extractCategories();
        final filteredProducts = _getFilteredProducts();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            titleSpacing: AppDimensions.spacingMd,
            title: InkWell(
              key: const Key('market_store_switcher_button'),
              onTap: _openStoreSelector,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4.0,
                  horizontal: 2.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingXs),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primaryDark,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  currentStore.name,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppColors.primaryDark,
                              ),
                            ],
                          ),
                          Text(
                            currentStore.area,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              CustomerPointsBadge(
                pointsNotifier: widget.pointsNotifier,
                currency: widget.currency,
              ),
              PopupMenuButton<String>(
                key: const Key('customer_market_overflow_menu'),
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'More options',
                onSelected: (val) {
                  if (val == 'order_history') {
                    _openOrderHistory();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem<String>(
                    key: Key('menu_order_history'),
                    value: 'order_history',
                    child: Row(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 8),
                        Text('Order History'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Input Field
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.spacingMd,
                    AppDimensions.spacingSm,
                    AppDimensions.spacingMd,
                    AppDimensions.spacingSm,
                  ),
                  child: TextField(
                    key: const Key('market_search_text_field'),
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products in ${currentStore.name}...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingMd,
                        vertical: AppDimensions.spacingSm,
                      ),
                      isDense: true,
                    ),
                  ),
                ),

                // Categories Bar
                if (!_isLoading &&
                    _errorMessage == null &&
                    _allProducts.isNotEmpty) ...[
                  CategoryFilterBar(
                    categories: categories,
                    selectedCategory: _selectedCategory,
                    onCategorySelected: (cat) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                ],

                // Catalog Body
                Expanded(
                  child: _buildCatalogContent(currentStore, filteredProducts),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildPersistentCartBar(),
        );
      },
    );
  }

  Widget? _buildPersistentCartBar() {
    final notifier = _cartNotifier;
    if (notifier == null) return null;

    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final itemCount = notifier.itemCount;
        if (itemCount <= 0) return const SizedBox.shrink();

        final subtotal = notifier.subtotal;

        return Container(
          key: const Key('market_persistent_cart_bar'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
            border: const Border(
              top: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'} in cart',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${subtotal.toStringAsFixed(2)} ${widget.currency}',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  key: const Key('market_view_cart_button'),
                  onPressed: () {
                    if (widget.onViewCart != null) {
                      widget.onViewCart!();
                    } else {
                      final scope = CustomerScope.maybeOf(context);
                      final selectedStore = _storeNotifier.value;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CartScreen(
                            cartNotifier: notifier,
                            orderRepository: scope?.orderRepository,
                            storeName: selectedStore?.name,
                            storeArea: selectedStore?.area,
                            currency: widget.currency,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View Cart'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingMd,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCatalogContent(StoreModel store, List<ProductModel> products) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: AppDimensions.spacingMd),
            Text(
              'Loading products...',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ],
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
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text('Could Not Load Products', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton.icon(
                key: const Key('market_retry_button'),
                onPressed: () => _loadCatalog(store.id),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_allProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 52,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                'No Products in this Store',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                'This supermarket has not added catalog items yet. Try selecting another store.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              OutlinedButton.icon(
                onPressed: _openStoreSelector,
                icon: const Icon(Icons.storefront_rounded, size: 18),
                label: const Text('Change Supermarket'),
              ),
            ],
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text('No Matching Products', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                'No items found matching "$_searchQuery" in $_selectedCategory.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _selectedCategory = 'All');
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
            ? 3
            : 2;

        return GridView.builder(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.72,
            crossAxisSpacing: AppDimensions.spacingMd,
            mainAxisSpacing: AppDimensions.spacingMd,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(
              key: Key('product_card_${product.id}'),
              product: product,
              cartNotifier: _cartNotifier,
              onTap: () {
                ProductDetailSheet.show(
                  context,
                  product: product,
                  cartNotifier: _cartNotifier,
                );
              },
            );
          },
        );
      },
    );
  }
}
