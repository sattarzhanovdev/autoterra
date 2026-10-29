import 'package:autoterra/widgets/common/catalog_brand_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'each opening reloads brands; search finds brands beyond product pages',
    (tester) async {
      var brands = ['Старый бренд'];
      var loads = 0;
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogBrandFilter(
              selected: null,
              loadBrands: () async {
                loads++;
                return brands;
              },
              onChanged: (brand) => selected = brand,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('catalog-brand-filter')));
      await tester.pumpAndSettle();
      expect(find.text('Старый бренд'), findsOneWidget);
      await tester.tap(find.text('Старый бренд'));
      await tester.pumpAndSettle();
      expect(selected, 'Старый бренд');
      brands = [for (var i = 0; i < 70; i++) 'Бренд $i', 'Новый бренд'];
      await tester.tap(find.byKey(const ValueKey('catalog-brand-filter')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'НОВЫЙ');
      await tester.pumpAndSettle();
      expect(find.text('Новый бренд'), findsOneWidget);
      expect(find.text('Старый бренд'), findsNothing);
      await tester.tap(find.text('Новый бренд'));
      await tester.pumpAndSettle();
      expect(selected, 'Новый бренд');
      expect(loads, 2);
    },
  );

  testWidgets('network error can be retried and all brands resets selection', (
    tester,
  ) async {
    var fail = true;
    String? selected = 'Old';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogBrandFilter(
            selected: selected,
            loadBrands: () async {
              if (fail) throw StateError('offline');
              return ['New'];
            },
            onChanged: (brand) => selected = brand,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('catalog-brand-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить бренды каталога'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('New'), findsOneWidget);
    await tester.tap(find.text('Все бренды'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(tester.takeException(), isNull);
  });
}
