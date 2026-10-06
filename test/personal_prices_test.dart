import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/screens/clients/personal_prices_screen.dart';
import 'package:autoterra/screens/orders/order_screen.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/data_repository.dart';

class MockRepo extends Mock implements DataRepository {}

Map<String, dynamic> row({String? price = '650.25'}) => {
  'productId': '7',
  'sku': 'PAINT-7',
  'name': 'Краска',
  'basePrice': '1000.00',
  'rankPrice': '800.00',
  'price': price ?? '800.00',
  'personalPrice': price,
  'overrideId': price == null ? null : '1',
  'isActive': price != null,
  'productActive': true,
  'updatedAt': '2026-10-06T09:00:00Z',
};

void main() {
  late MockRepo repo;
  late Map<String, dynamic> item;
  bool canEdit = true;
  void setupList() {
    when(
      () => repo.clientPrices(
        '1',
        page: any(named: 'page'),
        search: any(named: 'search'),
        overridesOnly: any(named: 'overridesOnly'),
      ),
    ).thenAnswer(
      (_) async => Paginated(
        items: [item],
        pageInfo: PageInfo.single(1),
        metadata: {'canEdit': canEdit},
      ),
    );
  }

  setUp(() {
    repo = MockRepo();
    item = row();
    canEdit = true;
    setupList();
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalPricesScreen(clientId: '1', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'distributor sees base and personal prices without edit controls',
    (tester) async {
      canEdit = false;
      await open(tester);
      expect(find.textContaining('Базовая цена:'), findsOneWidget);
      expect(find.textContaining('Персональная цена: 650,25'), findsOneWidget);
      expect(find.text('Изменить цену'), findsNothing);
      expect(find.text('Задать цену'), findsNothing);
    },
  );

  testWidgets('manager edits price in kopecks and disables it', (tester) async {
    when(
      () => repo.saveClientPrice('1', '7', price: '725.50', isActive: false),
    ).thenAnswer((_) async {});
    await open(tester);
    await tester.tap(find.text('Изменить цену'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Цена, ₽'), '725,50');
    await tester.tap(find.text('Активна'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    verify(
      () => repo.saveClientPrice('1', '7', price: '725.50', isActive: false),
    ).called(1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('invalid price never reaches API', (tester) async {
    await open(tester);
    await tester.tap(find.text('Изменить цену'));
    await tester.pumpAndSettle();
    for (final price in ['-1', 'NaN', '1.001', '0', '10000000000']) {
      await tester.enterText(find.widgetWithText(TextField, 'Цена, ₽'), price);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Введите цену больше нуля'), findsOneWidget);
    }
    verifyNever(
      () => repo.saveClientPrice(
        any(),
        any(),
        price: any(named: 'price'),
        isActive: any(named: 'isActive'),
      ),
    );
  });

  testWidgets('delete refreshes prices and shows rank fallback', (
    tester,
  ) async {
    when(() => repo.deleteClientPrice('1', '7')).thenAnswer((_) async {
      item = row(price: null);
    });
    await open(tester);
    await tester.tap(find.text('Изменить цену'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить цену'));
    await tester.pumpAndSettle();
    verify(() => repo.deleteClientPrice('1', '7')).called(1);
    expect(find.text('Персональная цена: не задана'), findsOneWidget);
    expect(find.textContaining('Цена для клиента: 800,00'), findsOneWidget);
  });

  testWidgets('save error stays visible and can be retried', (tester) async {
    var calls = 0;
    when(
      () => repo.saveClientPrice('1', '7', price: '650.25', isActive: true),
    ).thenAnswer((_) async {
      if (++calls == 1) throw Exception('Сервер недоступен');
    });
    await open(tester);
    await tester.tap(find.text('Изменить цену'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Сервер недоступен'), findsOneWidget);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('search can include products without overrides', (tester) async {
    await open(tester);
    await tester.tap(find.text('Только персональные цены'));
    await tester.enterText(find.byType(TextField), 'PAINT-7');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    verify(
      () => repo.clientPrices(
        '1',
        page: 1,
        search: 'PAINT-7',
        overridesOnly: false,
      ),
    ).called(1);
  });

  testWidgets('price management fits a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Изменить цену'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('API preserves canEdit and catalog personal price metadata', () async {
    final api = ApiClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'results': [
              if (request.url.path.contains('/prices/'))
                row()
              else
                {
                  'id': '7',
                  'price': 650.25,
                  'basePrice': 1000,
                  'personalPrice': 650.25,
                  'priceSource': 'personal',
                },
            ],
            'canEdit': true,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final repo = DataRepository(api: api);
    final prices = await repo.clientPrices('1');
    expect(prices.metadata['canEdit'], isTrue);
    final product = (await repo.products()).items.single;
    expect(product.price, 650.25);
    expect(product.basePrice, 1000);
    expect(product.personalPrice, 650.25);
    expect(product.priceSource, 'personal');
  });

  testWidgets('catalog and basket use the personal unit price', (tester) async {
    final product = ProductData(
      id: '7',
      distributorId: '1',
      sku: 'P-7',
      name: 'Краска',
      category: 'Краски',
      brand: 'AutoTerra',
      volume: 1,
      price: 650.25,
      basePrice: 1000,
      personalPrice: 650.25,
      priceSource: 'personal',
      quantity: 10,
      status: StockStatus.inStock,
      updatedAt: DateTime(2026),
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
      (_) async => Paginated(items: [product], pageInfo: PageInfo.single(1)),
    );
    when(() => repo.orderConfig()).thenAnswer(
      (_) async => OrderConfigData(
        client: Client(
          id: '1',
          inn: '123',
          name: 'СТО',
          category: ClientCategory.b,
          region: 'Пермь',
          city: 'Пермь',
          contact: 'Иван',
          phone: '1',
          distributorId: '1',
          status: ClientStatus.active,
          createdAt: DateTime(2026),
        ),
        distributor: const Distributor(
          id: '1',
          name: 'Дистрибьютор',
          inn: '1',
          regions: [],
          phone: '1',
          email: '',
        ),
        stores: [],
      ),
    );
    await tester.pumpWidget(MaterialApp(home: OrderScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Персональная цена'), findsOneWidget);
    await tester.ensureVisible(find.text('ДОБАВИТЬ'));
    await tester.tap(find.text('ДОБАВИТЬ'));
    await tester.pumpAndSettle();
    expect(find.text('650.25 ₽/шт · 650.25 ₽'), findsOneWidget);
  });
  for (final effectivePrice in [800.0, 850.0]) {
    testWidgets(
      'catalog and basket use the personal percentage price $effectivePrice',
      (tester) async {
        final product = ProductData(
          id: '7',
          distributorId: '1',
          sku: 'P-7',
          name: 'Краска',
          category: 'Краски',
          brand: 'AutoTerra',
          volume: 1,
          price: effectivePrice,
          basePrice: 1000,
          personalPrice: null,
          priceSource: 'personal_discount',
          quantity: 10,
          status: StockStatus.inStock,
          updatedAt: DateTime(2026),
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
              Paginated(items: [product], pageInfo: PageInfo.single(1)),
        );
        when(() => repo.orderConfig()).thenAnswer(
          (_) async => OrderConfigData(
            client: Client(
              id: '1',
              inn: '123',
              name: 'СТО',
              category: ClientCategory.b,
              region: 'Пермь',
              city: 'Пермь',
              contact: 'Иван',
              phone: '1',
              distributorId: '1',
              status: ClientStatus.active,
              createdAt: DateTime(2026),
            ),
            distributor: const Distributor(
              id: '1',
              name: 'Дистрибьютор',
              inn: '1',
              regions: [],
              phone: '1',
              email: '',
            ),
            stores: [],
          ),
        );
        await tester.pumpWidget(
          MaterialApp(home: OrderScreen(repository: repo)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Персональная скидка'), findsOneWidget);
        await tester.ensureVisible(find.text('ДОБАВИТЬ'));
        await tester.tap(find.text('ДОБАВИТЬ'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            '${effectivePrice.toStringAsFixed(0)} ₽/шт · ${effectivePrice.toStringAsFixed(0)} ₽',
          ),
          findsOneWidget,
        );
      },
    );
  }
}
