import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../customer/domain/models/product_model.dart';
import '../../domain/models/store_category_model.dart';
import '../../domain/repositories/store_categories_repository.dart';
import '../../domain/repositories/store_products_repository.dart';
import 'store_scope.dart';

/// Modal dialog allowing Store Managers to create a new product item.
class CreateProductDialog extends StatefulWidget {
  final String storeId;
  final StoreProductsRepository? productsRepository;
  final StoreCategoriesRepository? categoriesRepository;

  const CreateProductDialog({
    super.key,
    required this.storeId,
    this.productsRepository,
    this.categoriesRepository,
  });

  static Future<ProductModel?> show(
    BuildContext context, {
    required String storeId,
    StoreProductsRepository? productsRepository,
    StoreCategoriesRepository? categoriesRepository,
  }) {
    return showDialog<ProductModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateProductDialog(
        storeId: storeId,
        productsRepository: productsRepository,
        categoriesRepository: categoriesRepository,
      ),
    );
  }

  @override
  State<CreateProductDialog> createState() => _CreateProductDialogState();
}

class _CreateProductDialogState extends State<CreateProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');

  String? _selectedCategoryId;
  List<StoreCategoryModel> _categories = const [];
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
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
          .toSet()
          .map((c) => StoreCategoryModel(id: c, name: c, storeId: widget.storeId))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _categories = uniqueCats;
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

    final result = await _productsRepo.createProduct(
      storeId: widget.storeId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      price: price,
      category: _selectedCategoryId,
      imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
    );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop(result.dataOrNull);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = result.failureOrNull?.message ?? 'Failed to create product';
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
                        'Add Store Item',
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

                  // Name
                  TextFormField(
                    key: const Key('create_product_name_input'),
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      hintText: 'e.g. Organic Whole Milk 1L',
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
                    key: const Key('create_product_price_input'),
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price (AED) *',
                      hintText: 'e.g. 12.50',
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
                      key: const Key('create_product_category_dropdown'),
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'Select category (optional)',
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
                    key: const Key('create_product_description_input'),
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Item details, weight, brand...',
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Image URL
                  TextFormField(
                    key: const Key('create_product_image_input'),
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL',
                      hintText: 'https://...',
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),

                  // Sort Order
                  TextFormField(
                    key: const Key('create_product_sort_order_input'),
                    controller: _sortOrderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display Sort Order',
                      hintText: '0',
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
                        key: const Key('create_product_submit_btn'),
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Add Product'),
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
