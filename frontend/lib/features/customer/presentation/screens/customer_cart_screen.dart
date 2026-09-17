import 'package:flutter/material.dart';

import '../../cart/presentation/screens/cart_screen.dart';
import '../widgets/customer_scope.dart';

/// Legacy screen wrapper delegating directly to [CartScreen] within [CustomerScope].
class CustomerCartScreen extends StatelessWidget {
  const CustomerCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = CustomerScope.maybeOf(context);
    if (scope == null) {
      return const Scaffold(
        body: Center(child: Text('No active customer session')),
      );
    }

    final store = scope.selectedStoreNotifier.value;

    return CartScreen(
      cartNotifier: scope.cartNotifier,
      storeName: store?.name,
      storeArea: store?.area,
    );
  }
}
