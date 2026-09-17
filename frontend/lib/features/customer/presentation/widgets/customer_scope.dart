import 'package:flutter/material.dart';

import '../../cart/application/cart_notifier.dart';
import '../../cart/domain/cart_repository.dart';
import '../../domain/models/store_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/store_repository.dart';

/// Pure Flutter InheritedWidget scoping customer feature dependencies, selected store state, and cart.
class CustomerScope extends InheritedWidget {
  final StoreRepository storeRepository;
  final ProductRepository productRepository;
  final CartRepository cartRepository;
  final OrderRepository orderRepository;
  final CartNotifier cartNotifier;
  final ValueNotifier<StoreModel?> selectedStoreNotifier;

  const CustomerScope({
    super.key,
    required this.storeRepository,
    required this.productRepository,
    required this.cartRepository,
    required this.orderRepository,
    required this.cartNotifier,
    required this.selectedStoreNotifier,
    required super.child,
  });

  static CustomerScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CustomerScope>();
    if (scope == null) {
      throw StateError('No CustomerScope found in widget tree.');
    }
    return scope;
  }

  static CustomerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CustomerScope>();
  }

  static StoreRepository storeRepositoryOf(BuildContext context) {
    return of(context).storeRepository;
  }

  static ProductRepository productRepositoryOf(BuildContext context) {
    return of(context).productRepository;
  }

  static CartRepository cartRepositoryOf(BuildContext context) {
    return of(context).cartRepository;
  }

  static OrderRepository orderRepositoryOf(BuildContext context) {
    return of(context).orderRepository;
  }

  static CartNotifier cartNotifierOf(BuildContext context) {
    return of(context).cartNotifier;
  }

  static StoreModel? selectedStoreOf(BuildContext context) {
    return of(context).selectedStoreNotifier.value;
  }

  @override
  bool updateShouldNotify(CustomerScope oldWidget) {
    return storeRepository != oldWidget.storeRepository ||
        productRepository != oldWidget.productRepository ||
        cartRepository != oldWidget.cartRepository ||
        orderRepository != oldWidget.orderRepository ||
        cartNotifier != oldWidget.cartNotifier ||
        selectedStoreNotifier != oldWidget.selectedStoreNotifier;
  }
}
