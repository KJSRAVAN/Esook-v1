import 'package:flutter/widgets.dart';

import '../../domain/repositories/admin_drivers_repository.dart';
import '../../domain/repositories/admin_stores_repository.dart';
import '../../domain/repositories/admin_users_repository.dart';

/// Scoped provider for admin repositories across the admin feature tree.
class AdminScope extends InheritedWidget {
  final AdminUsersRepository usersRepository;
  final AdminDriversRepository driversRepository;
  final AdminStoresRepository storesRepository;

  const AdminScope({
    super.key,
    required this.usersRepository,
    required this.driversRepository,
    required this.storesRepository,
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

  static AdminUsersRepository usersRepositoryOf(BuildContext context) =>
      of(context).usersRepository;
  static AdminDriversRepository driversRepositoryOf(BuildContext context) =>
      of(context).driversRepository;
  static AdminStoresRepository storesRepositoryOf(BuildContext context) =>
      of(context).storesRepository;

  @override
  bool updateShouldNotify(AdminScope oldWidget) {
    return usersRepository != oldWidget.usersRepository ||
        driversRepository != oldWidget.driversRepository ||
        storesRepository != oldWidget.storesRepository;
  }
}
