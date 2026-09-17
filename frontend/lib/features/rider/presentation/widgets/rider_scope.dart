import 'package:flutter/widgets.dart';

import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/repositories/rider_repository.dart';

/// Scoped provider for rider repositories and session state across the rider feature tree.
class RiderScope extends InheritedWidget {
  final RiderRepository riderRepository;
  final AuthRepository authRepository;
  final UserModel? currentUser;

  const RiderScope({
    super.key,
    required this.riderRepository,
    required this.authRepository,
    this.currentUser,
    required super.child,
  });

  static RiderScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RiderScope>();
    assert(scope != null, 'No RiderScope found in the current widget tree.');
    return scope!;
  }

  static RiderScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RiderScope>();
  }

  static RiderRepository riderRepositoryOf(BuildContext context) => of(context).riderRepository;
  static AuthRepository authRepositoryOf(BuildContext context) => of(context).authRepository;
  static UserModel? currentUserOf(BuildContext context) => of(context).currentUser;

  @override
  bool updateShouldNotify(RiderScope oldWidget) {
    return riderRepository != oldWidget.riderRepository ||
        authRepository != oldWidget.authRepository ||
        currentUser != oldWidget.currentUser;
  }
}
