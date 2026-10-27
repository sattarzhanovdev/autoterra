import 'dart:async';
import 'dart:convert';
import 'package:autoterra/screens/ai/ai_assistant_screen.dart';
import 'package:autoterra/services/ai_presentation.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/app_update.dart';
import 'package:autoterra/services/data_repository.dart';
import 'package:autoterra/widgets/common/order_discount_summary.dart';
import 'package:autoterra/widgets/common/referral_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'order_catalog_ux_test.dart' as fixture;
import 'order_discount_pricing_test.dart' as pricing;

class RefreshRepository extends fixture.CatalogRepository {
  Completer<Map<String, dynamic>>? pending;
  bool fail = false;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> orderQuote(
    List<Map<String, dynamic>> items, {
    String bonusAmount = '0.00',
  }) {
    calls++;
    if (fail) return Future.error(StateError('offline'));
    if (pending != null) return pending!.future;
    return super.orderQuote(items, bonusAmount: bonusAmount);
  }
}

class BonusRepository extends fixture.CatalogRepository {
  @override
  Future<OrderConfigData> orderConfig() async {
    final original = await super.orderConfig();
    return OrderConfigData(
      client: original.client,
      distributor: original.distributor,
      stores: [],
      bonusBalance: 10000,
    );
  }

  @override
  Future<Map<String, dynamic>> orderQuote(
    List<Map<String, dynamic>> items, {
    String bonusAmount = '0.00',
  }) async {
    final quote = await super.orderQuote(items, bonusAmount: bonusAmount);
    final total = double.parse(
      (quote['orderDiscount'] as Map)['total'] as String,
    );
    final max = (total * 10).floor() / 100;
    final applied = double.parse(bonusAmount).clamp(0.0, max);
    quote['bonus'] = {
      'balance': '10000.00',
      'maxAllowed': '$max',
      'applied': '$applied',
      'payableTotal': '${total - applied}',
    };
    return quote;
  }
}

void main() {
  test('AI answer removes citations and appended sources', () {
    expect(
      cleanAiAnswer('Ответ [1].\n\nИсточники:\n[1] Документ.pdf'),
      'Ответ.',
    );
    expect(cleanAiAnswer('Ответ 【1†doc】'), 'Ответ');
  });

  testWidgets('AI chat renders answer without source metadata', (tester) async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'answer': 'Подойдёт грунт [1].',
            'sources': [
              {
                'filename': 'Private-TDS.pdf',
                'title': 'Document title',
                'url': 'https://example.test/document',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: AiAssistantScreen(api: api)));
    await tester.tap(find.text('Какой грунт подойдёт для алюминия?'));
    await tester.pumpAndSettle();
    expect(find.text('Подойдёт грунт.'), findsOneWidget);
    expect(find.textContaining('Источники'), findsNothing);
    expect(find.textContaining('Private-TDS'), findsNothing);
    expect(find.textContaining('[1]'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final code in [null, '  at-ABC123  ']) {
    test('registration sends normalized optional referral: $code', () async {
      final api = ApiClient(
        client: MockClient((request) async {
          final data = jsonDecode(request.body) as Map;
          expect(data['referralCode'], code == null ? null : 'AT-ABC123');
          return http.Response('{}', 200);
        }),
      );
      await api.register({'username': 'test', 'referralCode': ?code});
    });
  }

  test('version policy only updates newer builds', () {
    for (final build in [21, 22, 23, 24]) {
      final policy = UpdatePolicy(build, {
        'latestBuildNumber': 23,
        'minimumSupportedBuildNumber': 22,
      });
      expect(policy.available, build < 23);
      expect(policy.mandatory, build < 22);
    }
  });

  testWidgets(
    'referral progress measures current tier; maximum has no next tier',
    (tester) async {
      const tiers = [
        (from: 0.0, rate: 0.5),
        (from: 100000.0, rate: 1.0),
        (from: 200000.0, rate: 1.5),
        (from: 400000.0, rate: 2.0),
        (from: 800000.0, rate: 2.5),
      ];
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ReferralProgress(volume: 165000, tiers: tiers)),
        ),
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.65,
      );
      expect(find.textContaining('До ставки 1,5%'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ReferralProgress(volume: 800000, tiers: tiers)),
        ),
      );
      expect(find.text('Максимальная ставка — 2,5%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'bonus slider never exceeds server maximum and refreshes payable total',
    (tester) async {
      final repo = BonusRepository();
      await fixture.open(tester, repo);
      final add = find.byKey(const ValueKey('add-to-cart-1'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-checkout')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Использовать бонусы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Использовать бонусы'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.max, 9.55);
      expect(slider.value, slider.max);
      expect(find.textContaining('К оплате: 85,98'), findsOneWidget);
      await fixture.capture(tester, 'checkout-bonuses');
      slider.onChanged!(slider.max / 2);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        lessThanOrEqualTo(9.55),
      );
      expect(find.textContaining('К оплате: 90,76'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'successful basket quote stays visible through 20 seconds, refresh errors and quantity changes',
    (tester) async {
      final repo = RefreshRepository();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await fixture.open(tester, repo);
      final add = find.byKey(const ValueKey('add-to-cart-1'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-checkout')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDiscountSummary), findsOneWidget);
      final calls = repo.calls;
      repo.pending = Completer();
      repo.items = [pricing.product(price: 80)];
      for (var i = 0; i < 42; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(OrderDiscountSummary), findsOneWidget);
        expect(find.textContaining('Расчёт заказа'), findsNothing);
      }
      expect(repo.calls, greaterThan(calls));
      repo.pending!.completeError(StateError('offline'));
      repo.pending = null;
      repo.fail = true;
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(OrderDiscountSummary), findsOneWidget);
      expect(find.textContaining('Расчёт заказа'), findsNothing);
      final plus = find.byIcon(Icons.add).first;
      await tester.ensureVisible(plus);
      await tester.tap(plus);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(OrderDiscountSummary), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
