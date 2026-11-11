import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esouq/core/network/api_client.dart';
import 'package:esouq/core/network/http_method.dart';
import 'package:esouq/core/network/http_transport.dart';
import 'package:esouq/core/theme/app_theme.dart';
import 'package:esouq/features/admin/presentation/widgets/store_loyalty_dialog.dart';

class MockTransport implements HttpTransport {
  Map<String, dynamic> lastPostBody = {};
  int getCallCount = 0;
  int postCallCount = 0;
  int postStatusCode = 200;
  String postResponseBody = '{"success": true}';

  @override
  Future<HttpResponseData> send({
    required Uri uri,
    required HttpMethod method,
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  }) async {
    if (method == HttpMethod.get) {
      getCallCount++;
      return HttpResponseData(
        statusCode: 200,
        body: jsonEncode({
          'id': 'cfg-1',
          'storeId': 'store-test-1',
          'isEnabled': false, // Starts disabled
          'pointsPerCurrencyUnit': 0.10,
          'pointsEarnedPerCurrency': 1.0,
          'minPointsToRedeem': 50,
          'maxDiscountPercent': 50.0,
          'maxPointsPerOrder': 500,
        }),
        headers: const {},
      );
    }
    if (method == HttpMethod.post) {
      postCallCount++;
      if (body != null) {
        lastPostBody = jsonDecode(body as String) as Map<String, dynamic>;
      }
      return HttpResponseData(
        statusCode: postStatusCode,
        body: postResponseBody,
        headers: const {},
      );
    }
    return const HttpResponseData(statusCode: 200, body: '{}', headers: {});
  }
}

Widget buildTestHost({
  required MockTransport transport,
  Size physicalSize = const Size(800, 1000),
}) {
  final apiClient = DefaultApiClient(
    baseUrl: 'http://localhost:4000',
    transport: transport,
  );

  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Builder(
        builder: (ctx) => ElevatedButton(
          key: const Key('open_dialog_btn'),
          onPressed: () {
            StoreLoyaltyDialog.show(
              ctx,
              storeId: 'store-test-1',
              storeName: 'Fresh Mart Riyadh',
              apiClient: apiClient,
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  group('StoreLoyaltyDialog layout and functional verification', () {
    testWidgets(
      'opens, toggles loyalty switch ON, changes setting, and saves cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final transport = MockTransport();
        await tester.pumpWidget(buildTestHost(transport: transport));

        // Tap to open dialog
        await tester.tap(find.byKey(const Key('open_dialog_btn')));
        await tester.pumpAndSettle();

        // Verify dialog loaded with store name
        expect(find.text('Loyalty Points Settings'), findsOneWidget);
        expect(find.text('Fresh Mart Riyadh'), findsOneWidget);

        // Toggle loyalty switch ON
        final switchFinder = find.byKey(const Key('loyalty_is_enabled_switch'));
        expect(switchFinder, findsOneWidget);

        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        // Change points conversion rate to 0.20
        final rateFinder = find.byKey(const Key('loyalty_redemption_rate_input'));
        expect(rateFinder, findsOneWidget);
        await tester.enterText(rateFinder, '0.20');
        await tester.pumpAndSettle();

        // Change max discount to 75
        final maxDiscountFinder = find.byKey(const Key('loyalty_max_discount_percent_input'));
        expect(maxDiscountFinder, findsOneWidget);
        await tester.enterText(maxDiscountFinder, '75');
        await tester.pumpAndSettle();

        // Tap Save button
        final saveBtn = find.byKey(const Key('loyalty_save_btn'));
        expect(saveBtn, findsOneWidget);
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Verify backend received update
        expect(transport.postCallCount, equals(1));
        expect(transport.lastPostBody['isEnabled'], isTrue);
        expect(transport.lastPostBody['pointsPerCurrencyUnit'], equals(0.20));
        expect(transport.lastPostBody['maxDiscountPercent'], equals(75.0));
        expect(transport.lastPostBody['minPointsToRedeem'], equals(0));

        // Dialog automatically closed on success
        expect(find.text('Loyalty Points Settings'), findsNothing);
      },
    );

    testWidgets(
      'renders without unbounded constraint error on narrow Android screen (360x640)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final transport = MockTransport();
        await tester.pumpWidget(buildTestHost(transport: transport));

        await tester.tap(find.byKey(const Key('open_dialog_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Loyalty Points Settings'), findsOneWidget);

        // Toggle switch on narrow screen
        await tester.tap(find.byKey(const Key('loyalty_is_enabled_switch')));
        await tester.pumpAndSettle();

        // Scroll to save button and tap
        final saveBtn = find.byKey(const Key('loyalty_save_btn'));
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        expect(saveBtn, findsOneWidget);

        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(transport.postCallCount, equals(1));
      },
    );

    testWidgets(
      'renders without unbounded constraint error on desktop/web screen (1280x800)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final transport = MockTransport();
        await tester.pumpWidget(buildTestHost(transport: transport));

        await tester.tap(find.byKey(const Key('open_dialog_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Loyalty Points Settings'), findsOneWidget);

        final saveBtn = find.byKey(const Key('loyalty_save_btn'));
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(transport.postCallCount, equals(1));
      },
    );

    testWidgets(
      'displays error message and remains open when save fails',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final transport = MockTransport();
        transport.postStatusCode = 500;
        transport.postResponseBody = '{"message": "Database write error"}';

        await tester.pumpWidget(buildTestHost(transport: transport));

        await tester.tap(find.byKey(const Key('open_dialog_btn')));
        await tester.pumpAndSettle();

        final saveBtn = find.byKey(const Key('loyalty_save_btn'));
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Verify error is shown and dialog stays open
        expect(find.textContaining('Failed to update loyalty settings'), findsOneWidget);
        expect(find.text('Loyalty Points Settings'), findsOneWidget);
      },
    );
  });
}
