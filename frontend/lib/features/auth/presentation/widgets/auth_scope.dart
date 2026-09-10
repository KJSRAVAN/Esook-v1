import 'package:flutter/material.dart';

import '../../domain/repositories/auth_repository.dart';

/// Pure Flutter InheritedWidget providing [AuthRepository] down the widget tree.
class AuthScope extends InheritedWidget {
  final AuthRepository repository;

  const AuthScope({
    super.key,
    required this.repository,
    required super.child,
  });

  /// Retrieves the [AuthRepository] from the nearest ancestor [AuthScope].
  static AuthRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    if (scope == null) {
      throw StateError('No AuthScope found in widget tree.');
    }
    return scope.repository;
  }

  /// Retrieves the [AuthRepository] from the nearest ancestor [AuthScope], or null if not found.
  static AuthRepository? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    return scope?.repository;
  }

  @override
  bool updateShouldNotify(AuthScope oldWidget) => repository != oldWidget.repository;
}
