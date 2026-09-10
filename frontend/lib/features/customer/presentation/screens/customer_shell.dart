import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../widgets/customer_bottom_navigation.dart';
import 'customer_account_screen.dart';
import 'customer_cart_screen.dart';
import 'customer_chat_screen.dart';
import 'customer_market_screen.dart';
import 'customer_orders_screen.dart';

/// Main application shell for authenticated customer users.
///
/// Features:
/// - Persistent bottom navigation across the 5 primary customer tabs:
///   1. Market
///   2. Chat
///   3. Cart
///   4. Orders
///   5. Account
/// - Indexed state retention across tab switches
/// - Responsive layout handling with proper SafeArea support
class CustomerShell extends StatefulWidget {
  final int initialIndex;
  final AuthRepository? authRepository;

  const CustomerShell({
    super.key,
    this.initialIndex = 0,
    this.authRepository,
  });

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onNavigationTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const CustomerMarketScreen(),
          const CustomerChatScreen(),
          const CustomerCartScreen(),
          const CustomerOrdersScreen(),
          CustomerAccountScreen(authRepository: widget.authRepository),
        ],
      ),
      bottomNavigationBar: CustomerBottomNavigation(
        currentIndex: _currentIndex,
        onTap: _onNavigationTabSelected,
      ),
    );
  }
}
