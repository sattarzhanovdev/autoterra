import 'package:autoterra/screens/qa/learning_materials_screen.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/services/data_repository.dart';
import 'package:autoterra/services/ai_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'order_catalog_ux_test.dart' as fixture;

ProductData item({
  String id = '1',
  String name = 'Old item',
  double price = 1000,
  int quantity = 10,
  String brand = 'Old brand',
  String category = 'Old category',
}) => ProductData(
  id: id,
  distributorId: '1',
  sku: id == '2' ? 'TEST-SKU-001' : 'OLD',
  name: name,
  category: category,
  brand: brand,
  volume: 1,
  price: price,
  quantity: quantity,
  status: quantity > 5
      ? StockStatus.inStock
      : quantity > 0
      ? StockStatus.low
      : StockStatus.outOfStock,
  updatedAt: DateTime(2026),
);

class LiveCatalogRepository extends fixture.CatalogRepository {
  String revision = '1';
  bool fail = false;
  int quoteCalls = 0;
  LiveCatalogRepository() {
    items = [item()];
  }
  @override
  Future<Paginated<LearningMaterial>> learningMaterials({
    int page = 1,
    int pageSize = 20,
    String? kind,
    String? category,
    String? search,
  }) async => const Paginated<LearningMaterial>.empty();
  @override
  Future<String> catalogRevision() async => revision;
  @override
  Future<OrderConfigData> orderConfig() async {
    if (fail) throw StateError('offline');
    final original = await super.orderConfig();
    return OrderConfigData(
      client: original.client,
      distributor: original.distributor,
      stores: [],
      brands: items.map((e) => e.brand).toSet().toList(),
      categories: items.map((e) => e.category).toSet().toList(),
      catalogRevision: revision,
    );
  }

  @override
  Future<Paginated<ProductData>> products({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? category,
    String? brand,
    bool inStockOnly = false,
  }) async {
    if (fail) throw StateError('offline');
    requests.add({'brand': brand, 'category': category, 'search': search});
    final result = items
        .where(
          (p) =>
              (brand == null || brand == p.brand) &&
              (category == null || category == p.category),
        )
        .toList();
    return Paginated(items: result, pageInfo: PageInfo.single(result.length));
  }

  @override
  Future<List<ProductData>> productQuote(List<String> ids) async {
    if (fail) throw StateError('offline');
    return items.where((p) => ids.contains(p.id)).toList();
  }

  @override
  Future<Map<String, dynamic>> orderQuote(
    List<Map<String, dynamic>> rows, {
    String bonusAmount = '0.00',
  }) async {
    quoteCalls++;
    if (fail) throw StateError('offline');
    final total = rows.fold<double>(
      0,
      (sum, row) =>
          sum +
          items.firstWhere((p) => p.id == row['productId']).price *
              (row['quantity'] as int),
    );
    return {
      'orderDiscount': {
        'total': '$total',
        'subtotalBeforeOrderDiscount': '$total',
      },
    };
  }
}

Future<void> refresh(WidgetTester tester) async {
  await tester
      .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
      .onRefresh();
  await tester.pumpAndSettle();
}

void main() {
  test('useful AI links survive citation cleanup', () {
    final answer = cleanAiAnswer(
      'Инструкция: [сайт](https://maker.test/help). https://help.test\nИсточники:\n[1] TDS.pdf',
    );
    expect(answer, contains('[сайт](https://maker.test/help)'));
    expect(answer, contains('https://help.test'));
    expect(answer, isNot(contains('TDS.pdf')));
  });

  testWidgets('learning section displays an empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LearningMaterialsScreen(repository: LiveCatalogRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Материалы пока не добавлены'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'one price cycle requests at most one quote and unchanged prices request none',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final repo = LiveCatalogRepository()
        ..items = [item(), item(id: '2', name: 'Second')];
      await fixture.open(tester, repo);
      final add = find.byKey(const ValueKey('add-to-cart-1'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      final before = repo.quoteCalls;
      repo.items = [
        item(price: 800),
        item(id: '2', name: 'Second', price: 700),
      ];
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.quoteCalls, before + 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.quoteCalls, before + 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'new products appear, price and stock change, selected cart survives full refresh',
    (tester) async {
      final repo = LiveCatalogRepository();
      await fixture.open(tester, repo);
      final add = find.byKey(const ValueKey('add-to-cart-1'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      repo.items = [
        item(price: 800, quantity: 3),
        item(id: '2', name: 'New item'),
      ];
      repo.revision = '2';
      await refresh(tester);
      expect(find.text('В корзине: 1 шт.'), findsWidgets);
      final card = find.byKey(const ValueKey('catalog-product-1'));
      await tester.ensureVisible(card);
      expect(
        find.descendant(of: card, matching: find.text('800,00 ₽')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.textContaining('3 ШТ.')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('catalog-product-2')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('NEW ITEM'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'new item is discovered by background catalog poll without restart',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final repo = LiveCatalogRepository()..items = [];
      await fixture.open(tester, repo);
      expect(find.text('NEW ITEM'), findsNothing);
      repo.items = [item(id: '2', name: 'New item')];
      repo.revision = '2';
      await tester.pump(const Duration(seconds: 45));
      await tester.pumpAndSettle();
      expect(find.text('NEW ITEM'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'stock shortage and deactivated cart item block submission without removing cart',
    (tester) async {
      final repo = LiveCatalogRepository();
      await fixture.open(tester, repo);
      final add = find.byKey(const ValueKey('add-to-cart-1'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byTooltip('Увеличить количество для добавления'));
        await tester.pumpAndSettle();
      }
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      repo.items = [item(quantity: 1)];
      await refresh(tester);
      await tester.tap(find.byKey(const ValueKey('open-checkout')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('доступно 1 шт., в корзине 3'),
        findsOneWidget,
      );
      final submit = find.widgetWithText(
        ElevatedButton,
        'Отправить дистрибьютору · 3000 ₽',
      );
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
      repo.items = [];
      repo.revision = '3';
      await refresh(tester);
      expect(find.textContaining('Товар больше недоступен'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('basket-quantity-1')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(repo.submittedItems, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'revision refresh fixes stale brand and category without clearing previous data on error',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final repo = LiveCatalogRepository();
      await fixture.open(tester, repo);
      await tester.tap(find.text('Old category'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('catalog-brand-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Old brand').last);
      await tester.pumpAndSettle();
      repo.items = [
        item(name: 'New item', brand: 'New brand', category: 'New category'),
      ];
      repo.revision = '2';
      await tester.pump(const Duration(seconds: 45));
      await tester.pumpAndSettle();
      expect(repo.requests.last['brand'], isNull);
      expect(repo.requests.last['category'], isNull);
      expect(find.text('NEW ITEM'), findsOneWidget);
      repo.fail = true;
      await refresh(tester);
      expect(find.text('NEW ITEM'), findsOneWidget);
      expect(
        find.text('Не удалось обновить данные. Повторить'),
        findsOneWidget,
      );
      repo.fail = false;
      repo.items = [
        item(
          name: 'Recovered item',
          brand: 'New brand',
          category: 'New category',
        ),
      ];
      repo.revision = '3';
      await tester.pump(const Duration(seconds: 45));
      await tester.pumpAndSettle();
      expect(find.text('RECOVERED ITEM'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
