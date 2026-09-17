import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/admin_user_model.dart';
import '../../domain/repositories/admin_drivers_repository.dart';
import '../widgets/admin_scope.dart';
import '../widgets/create_driver_dialog.dart';

/// Driver fleet management screen for Super Admin to provision and review delivery drivers.
class AdminDriversScreen extends StatefulWidget {
  final AdminDriversRepository? driversRepository;

  const AdminDriversScreen({
    super.key,
    this.driversRepository,
  });

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AdminUserModel> _drivers = const [];

  AdminDriversRepository get _repo =>
      widget.driversRepository ?? AdminScope.driversRepositoryOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repo.getDrivers();

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _drivers = result.dataOrNull ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.failureOrNull?.message ?? 'Failed to load drivers fleet';
      });
    }
  }

  Future<void> _openCreateDriverDialog() async {
    final createdDriver = await CreateDriverDialog.show(
      context,
      driversRepository: _repo,
    );

    if (createdDriver != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Driver "${createdDriver.name}" registered successfully!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
      _loadDrivers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riders & Drivers'),
        actions: [
          IconButton(
            key: const Key('drivers_refresh_button'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadDrivers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_driver_fab'),
        heroTag: 'admin_drivers_fab',
        onPressed: _openCreateDriverDialog,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New Driver'),
        backgroundColor: const Color(0xFFEA580C),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA580C)),
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
              Text(
                'Unable to Load Drivers',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton.icon(
                key: const Key('drivers_retry_button'),
                onPressed: _loadDrivers,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_drivers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  size: 36,
                  color: Color(0xFFEA580C),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'No Drivers Registered',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                'Add driver accounts to enable order pickup and home delivery dispatch.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              ElevatedButton.icon(
                key: const Key('empty_add_driver_button'),
                onPressed: _openCreateDriverDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Register First Driver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingMd,
        AppDimensions.spacingMd,
        AppDimensions.spacingMd,
        80, // Padding for FAB
      ),
      itemCount: _drivers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.spacingSm),
      itemBuilder: (context, index) {
        final driver = _drivers[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: Color(0xFFEA580C),
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              driver.name,
                              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Text(
                              driver.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: driver.isActive ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (driver.phone != null)
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              driver.phone!,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
