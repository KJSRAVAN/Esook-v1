import 'package:flutter/widgets.dart';

import '../../../../core/network/api_client.dart';
import '../../../store/domain/repositories/store_categories_repository.dart';
import '../../../store/domain/repositories/store_orders_repository.dart';
import '../../../store/domain/repositories/store_products_repository.dart';
import '../../domain/repositories/admin_drivers_repository.dart';
import '../../domain/repositories/admin_stores_repository.dart';
import '../../domain/repositories/admin_users_repository.dart';

/// Scoped provider for admin repositories across the admin feature tree.
class AdminScope extends InheritedWidget {
  final ApiClient? apiClient;
  final AdminUsersRepository usersRepository;
  final AdminDriversRepository driversRepository;
  final AdminStoresRepository storesRepository;
  final StoreOrdersRepository? ordersRepository;
  final StoreProductsRepository? productsRepository;
  final StoreCategoriesRepository? categoriesRepository;

  const AdminScope({
    super.key,
    this.apiClient,
    required this.usersRepository,
    required this.driversRepository,
    required this.storesRepository,
    this.ordersRepository,
    this.productsRepository,
    this.categoriesRepository,
    required super.child,
  });

  static AdminScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdminScope>();
    assert(scope != null, 'No AdminScope found in the current widget tree.');
    return scope!;
  }

  static AdminScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminScope>();
  }

  static ApiClient? apiClientOf(BuildContext context) =>
      maybeOf(context)?.apiClient;
  static AdminUsersRepository usersRepositoryOf(BuildContext context) =>
      of(context).usersRepository;
  static AdminDriversRepository driversRepositoryOf(BuildContext context) =>
      of(context).driversRepository;
  static AdminStoresRepository storesRepositoryOf(BuildContext context) =>
      of(context).storesRepository;
  static StoreOrdersRepository? ordersRepositoryOf(BuildContext context) =>
      maybeOf(context)?.ordersRepository;
  static StoreProductsRepository? productsRepositoryOf(BuildContext context) =>
      maybeOf(context)?.productsRepository;
  static StoreCategoriesRepository? categoriesRepositoryOf(
    BuildContext context,
  ) => maybeOf(context)?.categoriesRepository;

  @override
  bool updateShouldNotify(AdminScope oldWidget) {
    return apiClient != oldWidget.apiClient ||
        usersRepository != oldWidget.usersRepository ||
        driversRepository != oldWidget.driversRepository ||
        storesRepository != oldWidget.storesRepository ||
        ordersRepository != oldWidget.ordersRepository ||
        productsRepository != oldWidget.productsRepository ||
        categoriesRepository != oldWidget.categoriesRepository;
  }
}
