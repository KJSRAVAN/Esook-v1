import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../widgets/customer_scope.dart';
import '../widgets/order_card.dart';
import '../widgets/order_details_sheet.dart';

/// Screen presenting the authenticated customer's order history and active order tracking.
class CustomerOrdersScreen extends StatefulWidget {
  final OrderRepository? orderRepository;

  const CustomerOrdersScreen({super.key, this.orderRepository});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  OrderRepository? _repository;
  bool _isLoading = false;
  String? _errorMessage;
  List<OrderModel> _orders = const [];
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _repository =
          widget.orderRepository ??
          CustomerScope.maybeOf(context)?.orderRepository;
      _isInitialized = true;
      if (_repository != null) {
        _loadOrders();
      }
    }
  }

  Future<void> _loadOrders() async {
    final repo =
        _repository ??
        widget.orderRepository ??
        CustomerScope.maybeOf(context)?.orderRepository;
    if (repo == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await repo.getMyOrders();

    if (!mounted) return;

    result.fold(
      onSuccess: (orders) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      },
      onFailure: (failure) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Orders'),
        centerTitle: false,
        actions: [
          IconButton(
            key: const Key('orders_refresh_button'),
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadOrders,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null && _orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48.0,
                color: AppColors.error,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'Unable to load orders',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              ElevatedButton.icon(
                key: const Key('orders_error_retry_button'),
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh, size: 18.0),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusLg,
                        ),
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        size: 32,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    const Text(
                      'No Orders Yet',
                      style: AppTextStyles.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      'Track active deliveries and view past grocery order history here.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final repo =
        _repository ??
        widget.orderRepository ??
        CustomerScope.maybeOf(context)?.orderRepository;

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSm),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return OrderCard(
            key: Key('order_card_${order.id}'),
            order: order,
            onTap: () {
              OrderDetailsSheet.show(
                context,
                order: order,
                orderRepository: repo,
              );
            },
          );
        },
      ),
    );
  }
}
