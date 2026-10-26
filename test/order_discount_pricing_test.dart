import 'dart:convert';
import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/screens/orders/order_screen.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/data_repository.dart';
import 'package:autoterra/widgets/common/client_product_price.dart';
import 'package:autoterra/widgets/common/order_discount_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class QuoteRepository extends Mock implements DataRepository {}

ProductData product({
  double price = 780,
  double? base = 1000,
  double percent = 22,
  bool? hasDiscount,
}) => ProductData(
  id: '1',
  distributorId: '1',
  sku: 'P1',
  name: 'Краска',
  category: '',
  brand: '',
  volume: 1,
  price: price,
  basePrice: base,
  effectiveDiscountPercent: percent,
  hasDiscount: hasDiscount ?? percent > 0,
  priceSource: 'personal_discount',
  quantity: 100,
  status: StockStatus.inStock,
  updatedAt: DateTime(2026),
);

void main() {
  test('product fields survive compute and product quote parsing', () async {
    final row = {
      'id': '1',
      'price': '780.00',
      'basePrice': '1000.00',
      'personalPrice': null,
      'discountPercent': '22',
      'effectiveDiscountPercent': '22',
      'hasDiscount': true,
      'priceSource': 'personal_discount',
    };
    final repo = DataRepository(
      api: ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'results': [row],
            }),
            200,
          ),
        ),
      ),
    );
    for (final p in [
      (await repo.products()).items.single,
      (await repo.productQuote(['1'])).single,
    ]) {
      expect(p.price, 780);
      expect(p.basePrice, 1000);
      expect(p.discountPercent, 22);
      expect(p.effectiveDiscountPercent, 22);
      expect(p.hasDiscount, isTrue);
      expect(p.personalPrice, isNull);
    }
  });

  test('old public product payload has safe defaults', () async {
    final repo = DataRepository(
      api: ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'results': [
                {'id': '1', 'price': 1000},
              ],
            }),
            200,
          ),
        ),
      ),
    );
    final p = (await repo.products()).items.single;
    expect(p.basePrice, isNull);
    expect(p.discountPercent, 0);
    expect(p.effectiveDiscountPercent, 0);
    expect(p.hasDiscount, isFalse);
  });

  test(
    'fixed price keeps legacy percent separate from effective percent',
    () async {
      final repo = DataRepository(
        api: ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'results': [
                  {
                    'id': '1',
                    'price': 700,
                    'basePrice': 1000,
                    'discountPercent': 0,
                    'effectiveDiscountPercent': 30,
                    'hasDiscount': true,
                    'personalPrice': 700,
                    'priceSource': 'personal',
                  },
                ],
              }),
              200,
            ),
          ),
        ),
      );
      final p = (await repo.products()).items.single;
      expect(p.discountPercent, 0);
      expect(p.effectiveDiscountPercent, 30);
    },
  );

  testWidgets('personal price shows percent and crossed base price', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClientProductPrice(product: product())),
      ),
    );
    expect(find.text('Персональная скидка −22%'), findsOneWidget);
    final oldPrice = tester.widget<Text>(find.text('1\u00a0000,00 ₽'));
    expect(oldPrice.style?.decoration, TextDecoration.lineThrough);
    expect(find.text('780,00 ₽'), findsOneWidget);
  });

  testWidgets('explicit backend hasDiscount false hides discount details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientProductPrice(product: product(hasDiscount: false)),
        ),
      ),
    );
    expect(find.text('780,00 ₽'), findsOneWidget);
    expect(find.text('1\u00a0000,00 ₽'), findsNothing);
    expect(find.textContaining('Персональная скидка'), findsNothing);
  });

  testWidgets('no discount shows only one price and no zero badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientProductPrice(product: product(price: 1000, percent: 0)),
        ),
      ),
    );
    expect(find.text('1\u00a0000,00 ₽'), findsOneWidget);
    expect(find.textContaining('−0%'), findsNothing);
    expect(
      tester.widget<Text>(find.text('1\u00a0000,00 ₽')).style?.decoration,
      isNull,
    );
  });

  for (final row in [
    (7000, 0, 3, 10000, 3000, 0.7, 0, 7000),
    (10000, 3, 3.5, 15000, 5000, 0.0, 300, 9700),
    (12500, 3, 3.5, 15000, 2500, 0.5, 375, 12125),
    (15000, 3.5, 4, 20000, 5000, 0.0, 525, 14475),
  ]) {
    testWidgets(
      'server summary at ${row.$1} shows exact tier total and progress',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrderDiscountSummary(
                details: {
                  'subtotalBeforeOrderDiscount': '${row.$1}',
                  'orderDiscountPercent': '${row.$2}',
                  'nextDiscountPercent': '${row.$3}',
                  'nextThreshold': '${row.$4}',
                  'amountToNextThreshold': '${row.$5}',
                  'progress': '${row.$6}',
                  'discountAmount': '${row.$7}',
                  'total': '${row.$8}',
                },
              ),
            ),
          ),
        );
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          row.$6,
        );
        expect(
          find.textContaining(
            'Доп. скидка за объём заказа: ${row.$2.toString().replaceAll('.', ',')}%',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'До скидки ${row.$3.toString().replaceAll('.', ',')}% осталось',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Итого:'), findsOneWidget);
        expect(find.textContaining('6,5%'), findsNothing);
        if (row.$1 == 15000) {
          expect(find.text('Итого: 14\u00a0475,00 ₽'), findsOneWidget);
        }
      },
    );
  }

  testWidgets('maximum state hides further purchase incentive', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrderDiscountSummary(
            details: {
              'maximumReached': true,
              'total': '12000',
              'subtotalBeforeOrderDiscount': '12200',
              'discountAmount': '200',
              'orderDiscountPercent': '3',
            },
          ),
        ),
      ),
    );
    expect(find.text('Максимальная скидка 40%'), findsOneWidget);
    expect(find.textContaining('осталось'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    'basket uses latest server total and discards an older response',
    (tester) async {
      final repo = QuoteRepository();
      final first = Completer<Map<String, dynamic>>();
      final second = Completer<Map<String, dynamic>>();
      var calls = 0;
      when(
        () => repo.orderQuote(any()),
      ).thenAnswer((_) => ++calls == 1 ? first.future : second.future);
      when(() => repo.orderConfig()).thenAnswer(
        (_) async => OrderConfigData(
          client: Client(
            id: '1',
            inn: '1',
            name: 'СТО',
            category: ClientCategory.b,
            region: '',
            city: '',
            contact: '',
            phone: '',
            distributorId: '1',
            status: ClientStatus.active,
            createdAt: DateTime(2026),
          ),
          distributor: const Distributor(
            id: '1',
            name: 'Дистрибьютор',
            inn: '1',
            regions: [],
            phone: '',
            email: '',
          ),
          stores: [],
        ),
      );
      when(
        () => repo.products(
          page: any(named: 'page'),
          search: any(named: 'search'),
          category: any(named: 'category'),
          brand: any(named: 'brand'),
          inStockOnly: any(named: 'inStockOnly'),
        ),
      ).thenAnswer(
        (_) async =>
            Paginated(items: [product()], pageInfo: PageInfo.single(1)),
      );
      await tester.pumpWidget(MaterialApp(home: OrderScreen(repository: repo)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ДОБАВИТЬ'));
      await tester.tap(find.text('ДОБАВИТЬ'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('add-to-cart-1')));
      await tester.pump(const Duration(milliseconds: 300));
      second.complete({
        'orderDiscount': {
          'total': '1500.61',
          'subtotalBeforeOrderDiscount': '1560',
        },
      });
      await tester.pump();
      first.complete({
        'orderDiscount': {'total': '1.01'},
      });
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Отправить дистрибьютору · 1500.61 ₽'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Отправить дистрибьютору · 1500.61 ₽'), findsOneWidget);
      expect(find.textContaining('· 1.01 ₽'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'order quote sends only product IDs and quantities and keeps server total',
    () async {
      final repo = DataRepository(
        api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/orders/quote/');
            expect(jsonDecode(request.body), {
              'items': [
                {'productId': '1', 'quantity': 15},
              ],
            });
            return http.Response(
              jsonEncode({
                'orderDiscount': {'total': '14475.00'},
              }),
              200,
            );
          }),
        ),
      );
      final result = await repo.orderQuote([
        {'productId': '1', 'quantity': 15},
      ]);
      expect(result['orderDiscount']['total'], '14475.00');
    },
  );
}
