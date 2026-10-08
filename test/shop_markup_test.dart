import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/core/shop_pricing.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/screens/orders/order_screen.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/data_repository.dart';
import 'package:autoterra/widgets/common/shop_sale_price.dart';
import 'package:autoterra/widgets/common/shop_markup_editor.dart';

class MockApi extends Mock implements ApiClient {}

class MockRepo extends Mock implements DataRepository {}

ProductData product({String clientId = '1', double? markup = 0}) => ProductData(
  id: 'p',
  distributorId: 'd',
  sku: 'p',
  name: 'Краска',
  category: 'Краски',
  brand: 'Brand',
  volume: 1,
  price: 1000,
  basePrice: 1500,
  quantity: 10,
  status: StockStatus.inStock,
  updatedAt: DateTime(2026),
  markupClientId: markup == null ? null : clientId,
  markupPercent: markup,
);

Client shop() => Client(
  id: '1',
  inn: '1234567890',
  name: 'Shop',
  category: ClientCategory.s,
  region: 'Москва',
  city: 'Москва',
  contact: 'Иван',
  phone: '1',
  distributorId: 'd',
  status: ClientStatus.active,
  createdAt: DateTime(2026),
);

void main() {
  setUp(() => DataRepository.markupChanges.value = {});

  test('sale price uses final purchase price and rounds half up', () {
    expect(shop().categoryLabel, 'S');
    expect(shop().categoryDescription, 'Магазин');
    expect(shopSalePrice(1000, 30), 1300);
    expect(shopSalePrice(800, 30), 1040); // Personal discount, not base price.
    expect(shopSalePrice(700, 30), 910); // Individual price.
    expect(shopSalePrice(123.45, 0), 123.45);
    expect(shopSalePrice(0, 30), 0);
    expect(shopSalePrice(0.01, 50), 0.02);
    expect(shopSalePrice(123.45, 12.34), 138.68);
    expect(shopSalePrice(1000, 150), 2500);
  });

  testWidgets('saved percentage updates all mounted prices for this account', (
    tester,
  ) async {
    final api = MockApi();
    when(
      () => api.updateMyMarkup('30'),
    ).thenAnswer((_) async => {'clientId': '1', 'markupPercent': '30.00'});
    final repo = DataRepository(api: api);
    final item = product();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ShopSalePrice(product: item),
              ShopSalePrice(
                product: item,
              ), // Open product card uses the same widget.
              ShopSalePrice(product: product(clientId: '2')),
            ],
          ),
        ),
      ),
    );
    await repo.updateMyMarkup('30');
    await tester.pump();
    expect(find.text('Наценка: 30%'), findsNWidgets(2));
    expect(find.text('Цена продажи: 1\u00a0300,00 ₽'), findsNWidgets(2));
    expect(find.text('Наценка: 0%'), findsOneWidget);
    expect(item.price, 1000); // Cart still uses this price.
  });

  testWidgets('no sale price for other client categories or staff products', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ShopSalePrice(product: product(markup: null))),
    );
    expect(find.textContaining('Цена продажи'), findsNothing);
  });

  testWidgets('editor accepts comma decimal and blocks invalid input', (
    tester,
  ) async {
    final api = MockApi();
    when(
      () => api.updateMyMarkup('30.5'),
    ).thenAnswer((_) async => {'clientId': '1', 'markupPercent': '30.50'});
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ShopMarkupEditor(
                  client: shop(),
                  repository: DataRepository(api: api),
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    for (final input in ['-1', '10000', 'NaN', '1.001', '']) {
      await tester.enterText(find.byType(TextField), input);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Введите число'), findsOneWidget);
    }
    await tester.enterText(find.byType(TextField), '30,5');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    verify(() => api.updateMyMarkup('30.5')).called(1);
    expect(DataRepository.markupChanges.value['1'], 30.5);
    expect(find.byType(ShopMarkupEditor), findsNothing);
  });

  testWidgets('catalog and product card keep cart purchase price', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MockRepo();
    when(() => repo.orderConfig()).thenAnswer(
      (_) async => OrderConfigData(
        client: shop(),
        distributor: const Distributor(
          id: 'd',
          name: 'Дистрибьютор',
          inn: '1',
          regions: [],
          phone: '1',
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
          Paginated(items: [product(markup: 30)], pageInfo: PageInfo.single(1)),
    );
    await tester.pumpWidget(MaterialApp(home: OrderScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Цена продажи: 1\u00a0300,00 ₽'), findsOneWidget);
    await tester.tap(find.text('КРАСКА'));
    await tester.pumpAndSettle();
    expect(find.text('Цена продажи: 1\u00a0300,00 ₽'), findsNWidgets(2));
    expect(find.textContaining('Закупочная цена:'), findsNWidgets(2));
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ДОБАВИТЬ'));
    await tester.tap(find.text('ДОБАВИТЬ'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('1300 ₽/шт'), findsNothing);
    expect(find.text('Отправить дистрибьютору · 1000 ₽'), findsOneWidget);
  });

  test('failed save keeps current display preference', () async {
    final api = MockApi();
    DataRepository.markupChanges.value = {'1': 20};
    when(() => api.updateMyMarkup('30')).thenThrow(Exception('offline'));
    await expectLater(
      DataRepository(api: api).updateMyMarkup('30'),
      throwsException,
    );
    expect(DataRepository.markupChanges.value['1'], 20);
  });
}
