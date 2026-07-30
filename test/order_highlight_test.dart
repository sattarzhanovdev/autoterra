import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:autoterra/core/theme.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/screens/purchases/purchases_screen.dart';
import 'package:autoterra/widgets/common/section_header.dart';

/// В списке заказов оператор должен с одного взгляда видеть, что ещё требует
/// разбора, а что уже закрыто. Единственный акцентный цвет в палитре —
/// фирменный красный, поэтому он достаётся только новым заказам.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU');
  });

  Order order(OrderStatus status) {
    return Order(
      id: '1',
      clientId: '1',
      clientName: 'Автосервис',
      distributorId: '1',
      storeName: 'Точка',
      documentNumber: 'ORD-001',
      date: DateTime(2026, 7, 20),
      totalAmount: 12000,
      status: status,
      items: const [],
      createdAt: DateTime(2026, 7, 20),
    );
  }

  Future<AppCard> pumpCard(WidgetTester tester, OrderStatus status) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: OrderCard(
          order: order(status),
          fmt: NumberFormat('#,##0', 'ru_RU'),
          isDistributor: true,
        ),
      ),
    ));
    return tester.widget<AppCard>(find.byType(AppCard));
  }

  testWidgets('новый заказ помечен красным и подписан', (tester) async {
    final card = await pumpCard(tester, OrderStatus.newOrder);

    expect(card.redAccent, isTrue);
    expect(find.text('НОВЫЙ'), findsOneWidget);
    expect(find.text('ОБРАБОТАН'), findsNothing);
  });

  testWidgets('доставленный заказ приглушён и подписан', (tester) async {
    final card = await pumpCard(tester, OrderStatus.fulfilled);

    expect(card.redAccent, isFalse);
    expect(card.background, AppColors.canvas);
    expect(find.text('ОБРАБОТАН'), findsOneWidget);
  });

  testWidgets('отменённый и отклонённый тоже считаются обработанными',
      (tester) async {
    for (final status in [OrderStatus.cancelled, OrderStatus.rejected]) {
      final card = await pumpCard(tester, status);

      expect(card.background, AppColors.canvas, reason: '$status');
      expect(find.text('ОБРАБОТАН'), findsOneWidget, reason: '$status');
    }
  });

  testWidgets('заказ в работе не выделяется ни красным, ни серым',
      (tester) async {
    // Промежуточные статусы — обычная карточка: иначе красным светился бы
    // весь список и выделение перестало бы что-либо значить.
    for (final status in [
      OrderStatus.confirmed,
      OrderStatus.adjusted,
      OrderStatus.paid,
      OrderStatus.shipped,
    ]) {
      final card = await pumpCard(tester, status);

      expect(card.redAccent, isFalse, reason: '$status');
      expect(card.background, isNull, reason: '$status');
      expect(find.text('НОВЫЙ'), findsNothing, reason: '$status');
      expect(find.text('ОБРАБОТАН'), findsNothing, reason: '$status');
    }
  });

  testWidgets('у нового заказа остаётся кнопка разбора', (tester) async {
    // Выделение не должно подменять собой действие оператора.
    await pumpCard(tester, OrderStatus.newOrder);

    expect(find.text('РАЗОБРАТЬ ЗАКАЗ'), findsOneWidget);
  });
}
