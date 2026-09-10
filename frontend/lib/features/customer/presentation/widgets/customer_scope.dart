import 'package:flutter/material.dart';

import '../../domain/models/store_model.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/store_repository.dart';

/// Pure Flutter InheritedWidget scoping customer feature dependencies and selected store state.
class CustomerScope extends InheritedWidget {
  final StoreRepository storeRepository;
  final ProductRepository productRepository;
  final ValueNotifier<StoreModel?> selectedStoreNotifier;

  const CustomerScope({
    super.key,
    required this.storeRepository,
    required this.productRepository,
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

  static StoreModel? selectedStoreOf(BuildContext context) {
    return of(context).selectedStoreNotifier.value;
  }

  @override
  bool updateShouldNotify(CustomerScope oldWidget) {
    return storeRepository != oldWidget.storeRepository ||
        productRepository != oldWidget.productRepository ||
        selectedStoreNotifier != oldWidget.selectedStoreNotifier;
  }
}
