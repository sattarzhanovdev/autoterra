import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:autoterra/core/theme.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/screens/orders/order_screen.dart';
import 'package:autoterra/services/data_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ProductData product({
  int quantity = 4,
  StockStatus status = StockStatus.inStock,
}) => ProductData(
  id: '1',
  distributorId: '1',
  sku: '00024216',
  name: '00202 SM Быстросъемный',
  category: 'Круги',
  brand: 'AutoTerra',
  volume: 1,
  price: 95.53,
  basePrice: 125.70,
  effectiveDiscountPercent: 24,
  hasDiscount: true,
  priceSource: 'personal_discount',
  quantity: quantity,
  status: status,
  updatedAt: DateTime(2026),
);

class CatalogRepository extends DataRepository {
  List<String> brands = ['AutoTerra'];
  List<ProductData> items = [product()];
  final requests = <Map<String, dynamic>>[];
  Future<Paginated<ProductData>> Function()? load;

  @override
  Future<OrderConfigData> orderConfig() async => OrderConfigData(
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
    categories: ['Круги'],
    brands: List.of(brands),
  );

  @override
  Future<Paginated<ProductData>> products({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? category,
    String? brand,
    bool inStockOnly = false,
  }) async {
    requests.add({
      'search': search,
      'category': category,
      'brand': brand,
      'inStockOnly': inStockOnly,
    });
    if (load != null) return load!();
    return Paginated(items: items, pageInfo: PageInfo.single(items.length));
  }

  @override
  Future<List<ProductData>> productQuote(List<String> ids) async => items;

  @override
  Future<Map<String, dynamic>> orderQuote(
    List<Map<String, dynamic>> items,
  ) async {
    final quantity = items.fold<int>(
      0,
      (sum, row) => sum + (row['quantity'] as int),
    );
    final total = (quantity * 95.53).toStringAsFixed(2);
    return {
      'orderDiscount': {
        'subtotalBeforeOrderDiscount': total,
        'total': total,
        'orderDiscountPercent': '0',
        'discountAmount': '0',
        'progress': '0.009553',
        'nextThreshold': '10000',
        'nextDiscountPercent': '3',
        'amountToNextThreshold': '9904.47',
      },
    };
  }
}

Future<void> open(WidgetTester tester, CatalogRepository repo) async {
  if (Platform.environment['AUTOTERRA_UX_SCREENSHOTS'] != null) {
    await tester.runAsync(() async {
      for (final font in {
        'TTNeoris': 'assets/fonts/TTNeoris-DemiBold.ttf',
        'Roboto': 'assets/fonts/TTNeoris-DemiBold.ttf',
        'TTOctosquares': 'assets/fonts/TTOctosquares-Medium.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        'AutoTerraIcons': 'assets/fonts/AutoTerraIcons.ttf',
      }.entries) {
        final loader = FontLoader(font.key)
          ..addFont(rootBundle.load(font.value));
        await loader.load();
      }
    });
  }
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: RepaintBoundary(
        key: const ValueKey('screen'),
        child: OrderScreen(repository: repo),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  final dir = Platform.environment['AUTOTERRA_UX_SCREENSHOTS'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('screen')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('$dir/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final row in [
    (49, StockStatus.inStock, 'В НАЛИЧИИ · 49 ШТ.'),
    (4, StockStatus.inStock, 'МАЛО · 4 ШТ.'),
    (0, StockStatus.onOrder, 'ПОД ЗАКАЗ'),
    (0, StockStatus.inStock, 'НЕТ В НАЛИЧИИ'),
  ]) {
    testWidgets('stock from backend: ${row.$3}', (tester) async {
      final repo = CatalogRepository()
        ..items = [product(quantity: row.$1, status: row.$2)];
      await open(tester, repo);
      await tester.ensureVisible(find.text(row.$3));
      expect(find.text(row.$3), findsOneWidget);
      if (row.$1 == 0 && row.$2 != StockStatus.onOrder) {
        expect(find.text('ДОБАВИТЬ'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'catalog price, stock, add to max, disabled plus and minus to zero',
    (tester) async {
      await open(tester, CatalogRepository());
      expect(find.text('Персональная скидка −24%'), findsOneWidget);
      expect(find.text('95,53 ₽'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('125,70 ₽')).style?.decoration,
        TextDecoration.lineThrough,
      );
      await tester.ensureVisible(find.text('ДОБАВИТЬ'));
      await capture(tester, 'catalog-discount-stock');
      await tester.tap(find.text('ДОБАВИТЬ'));
      await tester.pumpAndSettle();
      expect(find.text('Доступно: 4 шт.'), findsOneWidget);
      expect(find.text('В корзине'), findsWidgets);
      for (var next = 2; next <= 4; next++) {
        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle();
        expect(find.text('$next').first, findsOneWidget);
      }
      expect(find.text('МАЛО · 4 ШТ.'), findsOneWidget);
      expect(
        find.text('Достигнут максимальный остаток: 4 шт.'),
        findsOneWidget,
      );
      final plus = find.widgetWithIcon(IconButton, Icons.add).first;
      expect(tester.widget<IconButton>(plus).onPressed, isNull);
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(find.text('4').first, findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('00202 SM БЫСТРОСЪЕМНЫЙ'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await capture(tester, 'catalog-max-stock');
      for (var next = 3; next >= 0; next--) {
        await tester.tap(find.byIcon(Icons.remove).first);
        await tester.pumpAndSettle();
        if (next > 0) expect(find.text('$next').first, findsOneWidget);
      }
      expect(find.text('ДОБАВИТЬ'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('onOrder zero keeps the existing additional order rule', (
    tester,
  ) async {
    final repo = CatalogRepository()
      ..items = [product(quantity: 0, status: StockStatus.onOrder)];
    await open(tester, repo);
    await tester.ensureVisible(find.text('ДОБАВИТЬ'));
    await tester.tap(find.text('ДОБАВИТЬ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.text('2').first, findsOneWidget);
    expect(find.text('Достигнут максимальный остаток: 0 шт.'), findsNothing);
  });

  testWidgets('refresh clears a selected brand missing from fresh config', (
    tester,
  ) async {
    final repo = CatalogRepository()..brands = ['DeKor'];
    await open(tester, repo);
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DeKor').last);
    await tester.pumpAndSettle();
    expect(repo.requests.last['brand'], 'DeKor');
    repo.brands = ['DeKar'];
    tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pumpAndSettle();
    expect(repo.requests.last['brand'], isNull);
    expect(find.text('DeKor'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    expect(find.text('DeKar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'zero count ends loading; reset clears every filter and fetches again',
    (tester) async {
      final repo = CatalogRepository();
      await open(tester, repo);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Круги'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AutoTerra').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'В наличии'));
      await tester.pumpAndSettle();
      repo.items = [];
      await tester.enterText(find.byType(TextField).first, 'нет совпадений');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.requests.last, {
        'category': 'Круги',
        'brand': 'AutoTerra',
        'inStockOnly': true,
        'search': 'нет совпадений',
      });
      expect(
        find.text('По выбранным фильтрам товары не найдены'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.ensureVisible(find.text('СБРОСИТЬ ФИЛЬТРЫ'));
      await capture(tester, 'catalog-empty');
      repo.items = [product()];
      await tester.tap(find.text('СБРОСИТЬ ФИЛЬТРЫ'));
      await tester.pumpAndSettle();
      expect(repo.requests.last, {
        'category': null,
        'brand': null,
        'inStockOnly': false,
        'search': null,
      });
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        '',
      );
      expect(find.text('00202 SM БЫСТРОСЪЕМНЫЙ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loading and filter loading have descriptions; error can be retried',
    (tester) async {
      final first = Completer<Paginated<ProductData>>();
      final repo = CatalogRepository()..load = () => first.future;
      await tester.pumpWidget(MaterialApp(home: OrderScreen(repository: repo)));
      await tester.pump();
      expect(find.text('Загрузка товаров...'), findsOneWidget);
      first.complete(
        Paginated(items: [product()], pageInfo: PageInfo.single(1)),
      );
      await tester.pumpAndSettle();
      final second = Completer<Paginated<ProductData>>();
      repo.load = () => second.future;
      await tester.tap(find.widgetWithText(FilterChip, 'В наличии'));
      await tester.pump();
      expect(find.text('Обновляем каталог...'), findsOneWidget);
      second.completeError(Exception('network unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Не удалось загрузить товары'), findsOneWidget);
      repo.load = null;
      await tester.tap(find.text('ПОВТОРИТЬ'));
      await tester.pumpAndSettle();
      expect(find.text('00202 SM БЫСТРОСЪЕМНЫЙ'), findsOneWidget);
      expect(find.text('Не удалось загрузить товары'), findsNothing);
    },
  );
}
