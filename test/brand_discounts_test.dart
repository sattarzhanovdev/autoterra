import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/screens/clients/brand_discounts_screen.dart';
import 'package:autoterra/screens/orders/order_screen.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/data_repository.dart';

class BrandRepo extends Mock implements DataRepository {}

void main() {
  late BrandRepo repo;
  late List<Map<String, dynamic>> rows;
  setUp(() {
    repo = BrandRepo();
    rows = [
      {
        'brand': 'bosch',
        'label': 'BOSCH',
        'percent': '10.00',
        'available': true,
      },
      {'brand': 'mann', 'label': 'MANN', 'percent': null, 'available': true},
    ];
    when(
      () => repo.clientBrandDiscounts(
        '1',
        page: any(named: 'page'),
        search: any(named: 'search'),
        discountsOnly: any(named: 'discountsOnly'),
      ),
    ).thenAnswer((call) async {
      final search = call.namedArguments[#search] as String;
      final only = call.namedArguments[#discountsOnly] as bool;
      final filtered = rows
          .where(
            (row) =>
                row['brand'].toString().contains(search.toLowerCase()) &&
                (!only || row['percent'] != null),
          )
          .toList();
      return Paginated(
        items: filtered,
        pageInfo: PageInfo.single(filtered.length),
        metadata: {'canEdit': true},
      );
    });
    when(() => repo.saveBrandDiscounts('1', any())).thenAnswer((call) async {
      for (final entry in call.positionalArguments[1] as List) {
        rows.firstWhere((row) => row['brand'] == entry['brand'])['percent'] =
            entry['percent'];
      }
      return {'status': 'ok'};
    });
    when(() => repo.deleteBrandDiscount('1', any())).thenAnswer((call) async {
      rows.firstWhere(
        (row) => row['brand'] == call.positionalArguments[1],
      )['percent'] = null;
      return {'status': 'ok'};
    });
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: BrandDiscountsScreen(clientId: '1', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('checkboxes select several brands and save comma decimal', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Задать скидку (2)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '7,5');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    verify(
      () => repo.saveBrandDiscounts('1', [
        {'brand': 'bosch', 'percent': '7.5'},
        {'brand': 'mann', 'percent': '7.5'},
      ]),
    ).called(1);
    expect(find.text('7.5%'), findsNWidgets(2));
    expect(find.text('Задать скидку (0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing validates percentage and zero remains explicit', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Изменить').first);
    await tester.pumpAndSettle();
    for (final raw in ['-1', '101', 'NaN', '1.001', '']) {
      await tester.enterText(find.byType(TextField).last, raw);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(
        find.text('Введите процент от 0 до 40, до двух знаков после запятой'),
        findsOneWidget,
      );
    }
    verifyNever(() => repo.saveBrandDiscounts('1', any()));
    await tester.enterText(find.byType(TextField).last, '0');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('delete restores fallback and search filters brands', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();
    verify(() => repo.deleteBrandDiscount('1', 'bosch')).called(1);
    expect(find.text('Общая скидка / ранг'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'mann');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('MANN'), findsOneWidget);
    expect(find.text('BOSCH'), findsNothing);
  });

  testWidgets('readonly permission hides all mutation controls', (
    tester,
  ) async {
    when(
      () => repo.clientBrandDiscounts(
        '1',
        page: any(named: 'page'),
        search: any(named: 'search'),
        discountsOnly: any(named: 'discountsOnly'),
      ),
    ).thenAnswer(
      (_) async => Paginated(
        items: rows,
        pageInfo: PageInfo.single(2),
        metadata: {'canEdit': false},
      ),
    );
    await open(tester);
    expect(find.text('Изменить'), findsNothing);
    expect(find.text('Удалить'), findsNothing);
    expect(
      tester
          .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
          .onChanged,
      isNull,
    );
  });

  testWidgets('failed save keeps previous discount and retryable editor', (
    tester,
  ) async {
    when(
      () => repo.saveBrandDiscounts('1', any()),
    ).thenThrow(Exception('offline'));
    await open(tester);
    await tester.tap(find.text('Изменить').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(
      find.text('Не удалось сохранить скидки. Повторите попытку.'),
      findsOneWidget,
    );
    expect(find.text('10.00%'), findsOneWidget);
  });

  testWidgets('admin brand form to customer catalog and cart uses API price', (
    tester,
  ) async {
    final requests = <http.Request>[];
    String? percent;
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/orders/quote/')) {
          return http.Response(jsonEncode({'orderDiscount': {
            'subtotalBeforeOrderDiscount': 900, 'orderDiscountPercent': 0,
            'discountAmount': 0, 'total': 900, 'nextDiscountPercent': 3,
            'nextThreshold': 10000, 'amountToNextThreshold': 9100, 'progress': 0.09,
          }}), 200);
        }

        Map<String, dynamic> response;
        if (request.url.path.endsWith('/brand-discounts/')) {
          if (request.method == 'PATCH') {
            expect(jsonDecode(request.body), {
              'discounts': [
                {'brand': 'bosch', 'percent': '10'},
              ],
            });
            percent = '10.00';
            response = {'status': 'ok'};
          } else {
            response = {
              'results': [
                {
                  'brand': 'bosch',
                  'label': 'BOSCH',
                  'percent': percent,
                  'available': true,
                },
              ],
              'canEdit': true,
            };
          }
        } else if (request.url.path.endsWith('/orders/create/')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['items'], [
            {'productId': '1', 'quantity': 1},
          ]);
          expect((body['items'] as List).first.containsKey('price'), isFalse);
          response = {
            'order': {'id': '9', 'totalAmount': 900},
          };
        } else if (request.url.path.endsWith('/order-config/')) {
          response = {
            'client': {
              'id': '1',
              'inn': '1234567890',
              'name': 'Клиент',
              'category': 'b',
              'region': 'Регион',
              'city': 'Город',
              'contact': 'Контакт',
              'phone': '1',
              'distributorId': '1',
              'status': 'active',
              'createdAt': '2026-10-13T00:00:00Z',
            },
            'distributor': {
              'id': '1',
              'name': 'Дистрибьютор',
              'inn': '1',
              'regions': [],
              'phone': '1',
              'email': 'a@example.com',
            },
            'stores': [],
            'categories': [],
            'brands': ['BOSCH'],
          };
        } else {
          expect(percent, '10.00');
          response = {
            'results': [
              {
                'id': '1',
                'distributorId': '1',
                'sku': 'B',
                'name': 'Фильтр BOSCH',
                'category': 'Фильтры',
                'brand': 'BOSCH',
                'price': 900,
                'basePrice': 1000,
                'priceSource': 'brand_discount',
                'quantity': 100,
                'status': 'inStock',
                'updatedAt': '2026-10-13T00:00:00Z',
              },
            ],
          };
        }
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final repository = DataRepository(api: api);
    await tester.pumpWidget(
      MaterialApp(
        home: BrandDiscountsScreen(clientId: '1', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '10');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('10.00%'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute<void>(
                    builder: (_) => OrderScreen(repository: repository),
                  ),
                ),
                child: const Text('Каталог клиента'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Каталог клиента'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ДОБАВИТЬ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ДОБАВИТЬ'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Отправить дистрибьютору · 900 ₽'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('Отправить дистрибьютору · 900 ₽'), findsOneWidget);
    await tester.ensureVisible(find.text('Отправить дистрибьютору · 900 ₽'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить дистрибьютору · 900 ₽'));
    await tester.pumpAndSettle();
    expect(
      requests.any((request) => request.url.path.endsWith('/orders/create/')),
      isTrue,
    );
    expect(find.text('Каталог клиента'), findsOneWidget);

    expect(requests.any((request) => request.method == 'PATCH'), isTrue);
    expect(tester.takeException(), isNull);
  });

  test(
    'DELETE uses client-scoped endpoint and canonical brand payload',
    () async {
      final repository = DataRepository(
        api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'DELETE');
            expect(request.url.path, '/api/clients/1/brand-discounts/');
            expect(jsonDecode(request.body), {'brand': 'bosch'});
            return http.Response('{}', 200);
          }),
        ),
      );
      await repository.deleteBrandDiscount('1', 'bosch');
    },
  );
}
