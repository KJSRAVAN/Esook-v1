import 'package:esouq/core/constants/app_constants.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/customer/domain/models/product_model.dart';
import 'package:esouq/features/customer/presentation/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testProduct = ProductModel(
    id: 'prod-1',
    storeId: 'store-1',
    name: 'Fresh Whole Milk 1L',
    description: 'Fresh local cow milk',
    price: 1.25,
    category: 'Dairy & Eggs',
    isAvailable: true,
    loyaltyPointsPerUnit: 5,
  );

  testWidgets('ProductCard renders default currency from AppConstants', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: ProductCard(product: testProduct),
        ),
      ),
    );

    expect(find.text('Fresh Whole Milk 1L'), findsOneWidget);
    expect(find.text('1.25 ${AppConstants.defaultCurrency}'), findsOneWidget);
    expect(find.text('+5 pts'), findsOneWidget);
  });

  testWidgets('ProductCard renders custom currency when provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: ProductCard(
            product: testProduct,
            currency: 'AED',
          ),
        ),
      ),
    );

    expect(find.text('1.25 AED'), findsOneWidget);
  });
}
