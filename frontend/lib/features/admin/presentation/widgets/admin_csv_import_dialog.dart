import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../store/domain/models/csv_import_result_model.dart';
import '../../../store/domain/repositories/store_products_repository.dart';
import '../../../../core/utils/file_picker/csv_file_picker.dart';

/// Helper model for representing a selected CSV file before upload.
class SelectedCsvFile {
  final String name;
  final List<int> bytes;

  const SelectedCsvFile({
    required this.name,
    required this.bytes,
  });

  factory SelectedCsvFile.fromString({
    required String name,
    required String content,
  }) {
    return SelectedCsvFile(name: name, bytes: utf8.encode(content));
  }
}

/// Dialog allowing Super Admins to upload a CSV file to bulk import products.
class AdminCsvImportDialog extends StatefulWidget {
  final String storeId;
  final String? storeName;
  final StoreProductsRepository productsRepository;
  final SelectedCsvFile? initialFile;
  final Future<SelectedCsvFile?> Function()? onPickFile;

  const AdminCsvImportDialog({
    super.key,
    required this.storeId,
    this.storeName,
    required this.productsRepository,
    this.initialFile,
    this.onPickFile,
  });

  /// Displays the CSV Bulk Import dialog and returns the [CsvImportResultModel] upon success.
  static Future<CsvImportResultModel?> show(
    BuildContext context, {
    required String storeId,
    String? storeName,
    required StoreProductsRepository productsRepository,
    SelectedCsvFile? initialFile,
    Future<SelectedCsvFile?> Function()? onPickFile,
  }) {
    return showDialog<CsvImportResultModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdminCsvImportDialog(
        storeId: storeId,
        storeName: storeName,
        productsRepository: productsRepository,
        initialFile: initialFile,
        onPickFile: onPickFile,
      ),
    );
  }

  @override
  State<AdminCsvImportDialog> createState() => _AdminCsvImportDialogState();
}

enum _ImportState { idle, loading, success, failure }

class _AdminCsvImportDialogState extends State<AdminCsvImportDialog> {
  _ImportState _state = _ImportState.idle;
  SelectedCsvFile? _selectedFile;
  CsvImportResultModel? _result;
  String? _errorMessage;
  final TextEditingController _rawCsvController = TextEditingController();
  bool _showRawInput = false;

  @override
  void initState() {
    super.initState();
    _selectedFile = widget.initialFile;
  }

  @override
  void dispose() {
    _rawCsvController.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    if (widget.onPickFile != null) {
      final picked = await widget.onPickFile!();
      if (picked != null && mounted) {
        setState(() {
          _selectedFile = picked;
          _errorMessage = null;
        });
      }
      return;
    }

    final picked = await pickCsvFile();
    if (picked != null && mounted) {
      setState(() {
        _selectedFile = picked;
        _errorMessage = null;
      });
      return;
    }

    // Fallback toggle to raw CSV text entry if file picker was cancelled or unsupported
    if (mounted) {
      setState(() {
        _showRawInput = true;
      });
    }
  }

  void _loadSampleCsv() {
    const sample = 'name,price,offerPrice,variantName,category,description,sku,imageUrl,pointsValue\n'
        'Organic Red Apples,8.50,6.99,1kg,Produce,Fresh red apples per kg,APP-001,,10\n'
        'Whole Wheat Bread,4.25,,Default,Bakery,Freshly baked bread loaf,BRD-002,,5\n'
        'Full Cream Milk 1L,6.00,5.25,1 Liter,Dairy,Pasteurized full cream milk,MLK-003,,15';
    _rawCsvController.text = sample;
    setState(() {
      _selectedFile = SelectedCsvFile.fromString(
        name: 'sample_products.csv',
        content: sample,
      );
      _showRawInput = true;
      _errorMessage = null;
    });
  }

  Future<void> _submitImport() async {
    if (_state == _ImportState.loading) return;

    SelectedCsvFile? fileToUpload = _selectedFile;

    if (_showRawInput && _rawCsvController.text.trim().isNotEmpty) {
      fileToUpload = SelectedCsvFile.fromString(
        name: _selectedFile?.name ?? 'catalog_import.csv',
        content: _rawCsvController.text.trim(),
      );
    }

    if (fileToUpload == null || fileToUpload.bytes.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a CSV file or enter CSV data before importing.';
      });
      return;
    }

    setState(() {
      _state = _ImportState.loading;
      _errorMessage = null;
    });

    final res = await widget.productsRepository.importCsv(
      storeId: widget.storeId,
      fileBytes: fileToUpload.bytes,
      fileName: fileToUpload.name,
    );

    if (!mounted) return;

    if (res.isSuccess) {
      setState(() {
        _state = _ImportState.success;
        _result = res.dataOrNull ?? const CsvImportResultModel();
      });
    } else {
      setState(() {
        _state = _ImportState.failure;
        _errorMessage = res.failureOrNull?.message ?? 'CSV import failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final dialogWidth =
        screenWidth < 560 ? (screenWidth - 32).clamp(280.0, 520.0) : 520.0;
    final dialogMaxHeight = (screenHeight * 0.85).clamp(400.0, 720.0);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: dialogMaxHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _ImportState.loading:
        return _buildLoadingView();
      case _ImportState.success:
        return _buildSuccessView();
      case _ImportState.failure:
        return _buildFailureView();
      case _ImportState.idle:
        return _buildIdleView();
    }
  }

  Widget _buildIdleView() {
    final hasFile = _selectedFile != null || _rawCsvController.text.trim().isNotEmpty;

    return SingleChildScrollView(
      key: const ValueKey('csv_import_idle_view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: const Icon(Icons.upload_file_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulk Import Products (CSV)',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (widget.storeName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Store: ${widget.storeName}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                key: const Key('csv_import_close_btn'),
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Upload a CSV file containing product details to insert new items or update existing prices and stock.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          // File selection card
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(
                color: hasFile ? AppColors.primary : AppColors.borderSubtle,
                width: hasFile ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                if (_selectedFile != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFile!.name,
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${(_selectedFile!.bytes.length / 1024).toStringAsFixed(1)} KB',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('csv_remove_file_btn'),
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                        onPressed: () {
                          setState(() {
                            _selectedFile = null;
                            _rawCsvController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ] else ...[
                  const Icon(Icons.cloud_upload_outlined, size: 36, color: AppColors.textTertiary),
                  const SizedBox(height: 8),
                  Text(
                    'No CSV file selected',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a CSV file from device or enter CSV text below',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppDimensions.spacingSm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('csv_file_picker_btn'),
                      onPressed: _chooseFile,
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: Text(
                        _selectedFile != null
                            ? 'Change File'
                            : 'Browse / Input CSV',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('csv_load_sample_btn'),
                      onPressed: _loadSampleCsv,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                      label: const Text('Use Sample Template'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_showRawInput) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              'CSV Content Preview / Manual Editor',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              key: const Key('csv_raw_text_input'),
              controller: _rawCsvController,
              maxLines: 5,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                hintText:
                    'name,price,category,description\nApple,4.50,Produce,Fresh apple',
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              onChanged: (val) {
                if (val.trim().isNotEmpty) {
                  _selectedFile = SelectedCsvFile.fromString(
                    name: _selectedFile?.name ?? 'manual_input.csv',
                    content: val,
                  );
                } else {
                  _selectedFile = null;
                }
                setState(() {});
              },
            ),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Container(
              key: const Key('csv_import_idle_error'),
              padding: const EdgeInsets.all(AppDimensions.spacingSm),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppDimensions.spacingLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('csv_import_cancel_btn'),
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                key: const Key('csv_import_submit_btn'),
                onPressed: hasFile ? _submitImport : null,
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Upload & Import'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Column(
      key: const ValueKey('csv_import_loading_view'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppDimensions.spacingLg),
        const SizedBox(
          height: 48,
          width: 48,
          child: CircularProgressIndicator(
            key: Key('csv_import_loading_indicator'),
            strokeWidth: 3,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        Text(
          'Processing CSV Catalog...',
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Uploading and validating product rows. Please wait...',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spacingLg),
      ],
    );
  }

  Widget _buildSuccessView() {
    final result = _result ?? const CsvImportResultModel();

    return SingleChildScrollView(
      key: const ValueKey('csv_import_success_view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D)),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Completed',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Catalog results for ${widget.storeName ?? "Store"}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          // Metrics summary grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  key: const Key('csv_stat_imported'),
                  label: 'Imported',
                  count: result.imported,
                  color: const Color(0xFF15803D),
                  bgColor: const Color(0xFFDCFCE7),
                  icon: Icons.add_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  key: const Key('csv_stat_updated'),
                  label: 'Updated',
                  count: result.updated,
                  color: const Color(0xFF1D4ED8),
                  bgColor: const Color(0xFFDBEAFE),
                  icon: Icons.edit_note_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  key: const Key('csv_stat_skipped'),
                  label: 'Skipped',
                  count: result.skipped,
                  color: const Color(0xFFB45309),
                  bgColor: const Color(0xFFFEF3C7),
                  icon: Icons.skip_next_rounded,
                ),
              ),
            ],
          ),

          // Row-level errors list (if any)
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
                const SizedBox(width: 6),
                Text(
                  'Row-Level Errors (${result.errors.length})',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              key: const Key('csv_row_errors_list'),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(AppDimensions.spacingSm),
                itemCount: result.errors.length,
                separatorBuilder: (_, __) => const Divider(height: 8),
                itemBuilder: (context, idx) {
                  final err = result.errors[idx];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          err.row != null ? 'Row ${err.row}' : 'General',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              err.message,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFF991B1B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (err.field != null && err.field!.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                'Field: ${err.field}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: AppDimensions.spacingLg),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              key: const Key('csv_import_done_btn'),
              onPressed: () => Navigator.of(context).pop(result),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailureView() {
    return Column(
      key: const ValueKey('csv_import_failure_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
        const SizedBox(height: AppDimensions.spacingSm),
        Text(
          'Import Failed',
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Container(
          key: const Key('csv_import_error_message'),
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Text(
            _errorMessage ?? 'An unexpected error occurred during CSV upload.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              key: const Key('csv_import_retry_btn'),
              onPressed: () {
                setState(() {
                  _state = _ImportState.idle;
                  _errorMessage = null;
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required Key key,
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: AppTextStyles.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
