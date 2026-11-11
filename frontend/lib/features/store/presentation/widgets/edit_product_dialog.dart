import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/file_picker/image_file_picker.dart';
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
  final Future<SelectedImageFile?> Function()? onPickImage;

  const EditProductDialog({
    super.key,
    required this.storeId,
    required this.product,
    this.productsRepository,
    this.categoriesRepository,
    this.onPickImage,
  });

  static Future<ProductModel?> show(
    BuildContext context, {
    required String storeId,
    required ProductModel product,
    StoreProductsRepository? productsRepository,
    StoreCategoriesRepository? categoriesRepository,
    Future<SelectedImageFile?> Function()? onPickImage,
  }) {
    return showDialog<ProductModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditProductDialog(
        storeId: storeId,
        product: product,
        productsRepository: productsRepository,
        categoriesRepository: categoriesRepository,
        onPickImage: onPickImage,
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
  late final TextEditingController _offerPriceController;
  late final TextEditingController _pointsValueController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _sortOrderController;
  late bool _isAvailable;

  String? _selectedCategoryId;
  List<StoreCategoryModel> _categories = const [];
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  String? _errorMessage;
  String? _imageUploadError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController = TextEditingController(
      text: widget.product.description ?? '',
    );
    _priceController = TextEditingController(
      text: widget.product.price.toStringAsFixed(2),
    );
    _offerPriceController = TextEditingController(
      text: widget.product.offerPrice != null
          ? widget.product.offerPrice!.toStringAsFixed(2)
          : '',
    );
    _pointsValueController = TextEditingController(
      text: widget.product.loyaltyPointsPerUnit.toString(),
    );
    _imageUrlController = TextEditingController(
      text: widget.product.imageUrl ?? '',
    );
    _sortOrderController = TextEditingController(
      text: widget.product.sortOrder.toString(),
    );
    _isAvailable = widget.product.isAvailable;
    _selectedCategoryId = widget.product.categoryId ?? widget.product.category;
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _offerPriceController.dispose();
    _pointsValueController.dispose();
    _imageUrlController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  StoreProductsRepository get _productsRepo =>
      widget.productsRepository ?? StoreScope.productsRepositoryOf(context);

  Future<void> _loadCategories() async {
    final categoriesRepo = widget.categoriesRepository ??
        (mounted ? StoreScope.maybeOf(context)?.categoriesRepository : null);

    final Map<String, StoreCategoryModel> categoryMap = {};

    if (categoriesRepo != null) {
      final catResult = await categoriesRepo.getCategories(widget.storeId);
      if (catResult.isSuccess && catResult.dataOrNull != null) {
        for (final cat in catResult.dataOrNull!) {
          if (cat.id.isNotEmpty && cat.name.isNotEmpty) {
            categoryMap[cat.id] = cat;
          }
        }
      }
    }

    final prodResult = await _productsRepo.getStoreProducts(widget.storeId);
    if (prodResult.isSuccess && prodResult.dataOrNull != null) {
      for (final p in prodResult.dataOrNull!) {
        final catId = p.categoryId?.trim();
        final catName = p.category?.trim();
        if (catId != null && catId.isNotEmpty) {
          categoryMap.putIfAbsent(
            catId,
            () => StoreCategoryModel(
              id: catId,
              name: (catName != null && catName.isNotEmpty) ? catName : catId,
              storeId: widget.storeId,
            ),
          );
        } else if (catName != null && catName.isNotEmpty) {
          categoryMap.putIfAbsent(
            catName,
            () => StoreCategoryModel(
              id: catName,
              name: catName,
              storeId: widget.storeId,
            ),
          );
        }
      }
    }

    if (widget.product.category != null &&
        widget.product.category!.trim().isNotEmpty) {
      final catName = widget.product.category!.trim();
      final catId = widget.product.categoryId?.trim();
      final key = (catId != null && catId.isNotEmpty) ? catId : catName;
      categoryMap.putIfAbsent(
        key,
        () => StoreCategoryModel(
          id: key,
          name: catName,
          storeId: widget.storeId,
        ),
      );
    }

    if (!mounted) return;

    final categoryModels = categoryMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    setState(() {
      _categories = categoryModels;
      _isLoadingCategories = false;
    });
  }

  Future<void> _handleImageUpload() async {
    setState(() => _imageUploadError = null);

    final picked = widget.onPickImage != null
        ? await widget.onPickImage!()
        : await pickImageFile();
    if (picked == null || !mounted) return;

    const maxBytes = 5 * 1024 * 1024; // 5 MB
    if (picked.bytes.length > maxBytes) {
      setState(() {
        _imageUploadError = 'Selected image exceeds the 5 MB limit';
      });
      return;
    }

    setState(() => _isUploadingImage = true);

    final result = await _productsRepo.uploadProductImage(
      storeId: widget.storeId,
      fileBytes: picked.bytes,
      fileName: picked.name,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final url = result.dataOrNull!;
      setState(() {
        _isUploadingImage = false;
        _imageUrlController.text = url;
        _imageUploadError = null;
      });
    } else {
      setState(() {
        _isUploadingImage = false;
        _imageUploadError =
            result.failureOrNull?.message ?? 'Failed to upload product image';
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

    final offerText = _offerPriceController.text.trim();
    final double? offerPrice =
        offerText.isNotEmpty ? double.tryParse(offerText) : null;
    if (offerPrice != null && (offerPrice <= 0 || offerPrice >= price)) {
      setState(
        () => _errorMessage =
            'Offer price must be greater than 0 and less than regular price',
      );
      return;
    }

    final pointsText = _pointsValueController.text.trim();
    final int pointsValue = int.tryParse(pointsText) ?? 0;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await _productsRepo.updateProduct(
      storeId: widget.storeId,
      productId: widget.product.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      price: price,
      offerPrice: offerPrice,
      clearOfferPrice: offerPrice == null,
      pointsValue: pointsValue,
      categoryId: _selectedCategoryId,
      category: _selectedCategoryId,
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      isAvailable: _isAvailable,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop(result.dataOrNull);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            result.failureOrNull?.message ?? 'Failed to update product';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final dialogWidth =
        screenWidth < 540 ? (screenWidth - 32).clamp(280.0, 500.0) : 500.0;
    final dialogMaxHeight = (screenHeight * 0.85).clamp(380.0, 680.0);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: dialogMaxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spacingLg,
                  AppDimensions.spacingMd,
                  AppDimensions.spacingSm,
                  AppDimensions.spacingSm,
                ),
                child: Row(
                  children: [
                    Text(
                      'Edit Store Item',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderSubtle),

              // Form content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.spacingLg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(
                              AppDimensions.spacingSm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSm,
                              ),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingSm),
                        ],

                        // Availability Switch
                        SwitchListTile.adaptive(
                          key: const Key('edit_product_availability_switch'),
                          title: const Text(
                            'Item Available in Catalog',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _isAvailable
                                ? 'Customers can view and order this item'
                                : 'Item is hidden / unavailable for orders',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          value: _isAvailable,
                          activeThumbColor: AppColors.primary,
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
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
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

                        // Offer Price (Optional)
                        TextFormField(
                          key: const Key('edit_product_offer_price_input'),
                          controller: _offerPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Offer Price (AED) (Optional)',
                            hintText: 'e.g. 9.99 (Leave blank to remove offer)',
                            prefixText: 'AED ',
                          ),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final op = double.tryParse(val.trim());
                              if (op == null || op <= 0) {
                                return 'Enter a valid offer price';
                              }
                              final reg = double.tryParse(
                                _priceController.text.trim(),
                              );
                              if (reg != null && op >= reg) {
                                return 'Offer price must be less than regular price';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),

                        // Loyalty Points (Reward points per unit)
                        TextFormField(
                          key: const Key('edit_product_points_value_input'),
                          controller: _pointsValueController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Loyalty Points per Unit (pts)',
                            hintText: 'e.g. 5 (Points awarded per purchased unit)',
                          ),
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
                            initialValue: _selectedCategoryId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Category'),
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
                            onChanged: (val) =>
                                setState(() => _selectedCategoryId = val),
                          ),
                        const SizedBox(height: AppDimensions.spacingSm),

                        // Description
                        TextFormField(
                          key: const Key('edit_product_description_input'),
                          controller: _descriptionController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Item details, weight, brand...',
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),

                        // Image Upload & URL
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _imageUrlController.text.trim().isNotEmpty
                                  ? Image.network(
                                      _imageUrlController.text.trim(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => const Icon(
                                        Icons.broken_image_rounded,
                                        color: AppColors.textTertiary,
                                        size: 24,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.image_outlined,
                                      color: AppColors.textTertiary,
                                      size: 24,
                                    ),
                            ),
                            const SizedBox(width: AppDimensions.spacingMd),
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key('edit_product_upload_image_btn'),
                                onPressed: _isUploadingImage || _isSubmitting
                                    ? null
                                    : _handleImageUpload,
                                icon: _isUploadingImage
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.file_upload_outlined, size: 18),
                                label: Text(
                                  _isUploadingImage ? 'Uploading...' : 'Upload Image File',
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_imageUploadError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _imageUploadError!,
                            key: const Key('edit_product_image_error'),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppDimensions.spacingSm),

                        // Image URL (Direct/Persistent)
                        TextFormField(
                          key: const Key('edit_product_image_input'),
                          controller: _imageUrlController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Image URL',
                            hintText: 'https://...',
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
                            hintText: '0',
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, AppDimensions.buttonHeight),
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: AppDimensions.spacingSm),
                            ElevatedButton(
                              key: const Key('edit_product_submit_btn'),
                              onPressed: _isSubmitting ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, AppDimensions.buttonHeight),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
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
            ],
          ),
        ),
      ),
    );
  }
}
