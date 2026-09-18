import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../customer/domain/models/product_model.dart';
import '../../domain/models/store_category_model.dart';
import '../../domain/repositories/store_categories_repository.dart';
import '../../domain/repositories/store_products_repository.dart';
import 'store_scope.dart';

/// Modal dialog allowing Store Managers to edit an existing product item.
class EditProductDialog extends StatefulWidget {
  final String storeId;
  final ProductModel product;
  final StoreProductsRepository? productsRepository;
  final StoreCategoriesRepository? categoriesRepository;

  const EditProductDialog({
    super.key,
    required this.storeId,
    required this.product,
    this.productsRepository,
    this.categoriesRepository,
  });

  static Future<ProductModel?> show(
    BuildContext context, {
    required String storeId,
    required ProductModel product,
    StoreProductsRepository? productsRepository,
    StoreCategoriesRepository? categoriesRepository,
  }) {
    return showDialog<ProductModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditProductDialog(
        storeId: storeId,
        product: product,
        productsRepository: productsRepository,
        categoriesRepository: categoriesRepository,
      ),
    );
  }

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _sortOrderController;
  late bool _isAvailable;

  String? _selectedCategoryId;
  List<StoreCategoryModel> _categories = const [];
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController = TextEditingController(text: widget.product.description ?? '');
    _priceController = TextEditingController(text: widget.product.price.toStringAsFixed(2));
    _imageUrlController = TextEditingController(text: widget.product.imageUrl ?? '');
    _sortOrderController = TextEditingController(text: widget.product.sortOrder.toString());
    _isAvailable = widget.product.isAvailable;
    _selectedCategoryId = widget.product.category ?? widget.product.categoryId;
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  StoreProductsRepository get _productsRepo =>
      widget.productsRepository ?? StoreScope.productsRepositoryOf(context);

  Future<void> _loadCategories() async {
    final result = await _productsRepo.getStoreProducts(widget.storeId);
    if (mounted) {
      final prods = result.dataOrNull ?? [];
      final uniqueCats = prods
          .map((p) => p.category?.trim())
          .where((c) => c != null && c.isNotEmpty)
          .cast<String>()
          .toSet();

      if (widget.product.category != null && widget.product.category!.trim().isNotEmpty) {
        uniqueCats.add(widget.product.category!.trim());
      }

      final categoryModels = uniqueCats
          .map((c) => StoreCategoryModel(id: c, name: c, storeId: widget.storeId))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _categories = categoryModels;
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price < 0) {
      setState(() => _errorMessage = 'Please enter a valid non-negative price');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await _productsRepo.updateProduct(
      storeId: widget.storeId,
      productId: widget.product.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      price: price,
      category: _selectedCategoryId,
      imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
      isAvailable: _isAvailable,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop(result.dataOrNull);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = result.failureOrNull?.message ?? 'Failed to update product';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Store Item',
                        style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: AppDimensions.spacingSm),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingSm),
                      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],

                  // Availability Switch
                  SwitchListTile.adaptive(
                    key: const Key('edit_product_availability_switch'),
                    title: const Text('Item Available in Catalog', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _isAvailable ? 'Customers can view and order this item' : 'Item is hidden / unavailable for orders',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    value: _isAvailable,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _isAvailable = val),
                  ),
                  const Divider(height: 16),

                  // Name
                  TextFormField(
                    key: const Key('edit_product_name_input'),
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Product name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Price
                  TextFormField(
                    key: const Key('edit_product_price_input'),
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price (AED) *',
                      prefixText: 'AED ',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Price is required';
                      }
                      final p = double.tryParse(val.trim());
                      if (p == null || p < 0) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Category Dropdown
                  if (_isLoadingCategories)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: LinearProgressIndicator(),
                    )
                  else if (_categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: const Key('edit_product_category_dropdown'),
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None / General'),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Description
                  TextFormField(
                    key: const Key('edit_product_description_input'),
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Image URL
                  TextFormField(
                    key: const Key('edit_product_image_input'),
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL',
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Sort Order
                  TextFormField(
                    key: const Key('edit_product_sort_order_input'),
                    controller: _sortOrderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display Sort Order',
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                      ElevatedButton(
                        key: const Key('edit_product_submit_btn'),
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
      ),
    );
  }
}
