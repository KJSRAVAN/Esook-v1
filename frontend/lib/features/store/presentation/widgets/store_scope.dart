import 'package:flutter/widgets.dart';

import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/repositories/store_categories_repository.dart';
import '../../domain/repositories/store_orders_repository.dart';
import '../../domain/repositories/store_products_repository.dart';

/// Scoped provider for store staff repositories and session state across the store feature tree.
class StoreScope extends InheritedWidget {
  final StoreOrdersRepository ordersRepository;
  final StoreProductsRepository productsRepository;
  final StoreCategoriesRepository categoriesRepository;
  final AuthRepository authRepository;
  final UserModel? currentUser;
  final String? storeId;

  const StoreScope({
    super.key,
    required this.ordersRepository,
    required this.productsRepository,
    required this.categoriesRepository,
    required this.authRepository,
    this.currentUser,
    this.storeId,
    required super.child,
  });

  static StoreScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'No StoreScope found in the current widget tree.');
    return scope!;
  }

  static StoreScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StoreScope>();
  }

  static StoreOrdersRepository ordersRepositoryOf(BuildContext context) =>
      of(context).ordersRepository;
  static StoreProductsRepository productsRepositoryOf(BuildContext context) =>
      of(context).productsRepository;
  static StoreCategoriesRepository categoriesRepositoryOf(
    BuildContext context,
  ) => of(context).categoriesRepository;
  static AuthRepository authRepositoryOf(BuildContext context) =>
      of(context).authRepository;
  static UserModel? currentUserOf(BuildContext context) =>
      of(context).currentUser;
  static String? storeIdOf(BuildContext context) =>
      of(context).storeId ?? of(context).currentUser?.storeId;

  @override
  bool updateShouldNotify(StoreScope oldWidget) {
    return ordersRepository != oldWidget.ordersRepository ||
        productsRepository != oldWidget.productsRepository ||
        categoriesRepository != oldWidget.categoriesRepository ||
        authRepository != oldWidget.authRepository ||
        currentUser != oldWidget.currentUser ||
        storeId != oldWidget.storeId;
  }
}
