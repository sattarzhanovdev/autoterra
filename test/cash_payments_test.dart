import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/screens/orders/order_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/screens/clients/cash_payment_widgets.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/data_repository.dart';
import 'package:autoterra/widgets/layouts/courier_layout.dart';

class CashRepo extends Mock implements DataRepository {}

CourierTask task({
  bool collected = false,
  String method = 'cash',
  CourierTaskStatus status = CourierTaskStatus.inProgress,
  bool picked = true,
}) => CourierTask(
  id: '7',
  clientId: '1',
  clientName: 'Автосервис',
  orderId: '5',
  orderNumber: 'ORD-00005',
  taskType: 'delivery',
  typeDisplay: 'Доставка',
  address: 'Адрес',
  timeSlot: '10–18',
  status: status,
  statusDisplay: 'В пути',
  createdAt: DateTime(2026),
  paymentMethod: method,
  cashAmount: 1600,
  cashCollected: collected,
  allItemsPicked: picked,
  orderItems: [
    CourierOrderItem(
      id: '1',
      name: 'Краска',
      sku: 'P-1',
      quantity: 2,
      picked: picked,
    ),
  ],
);
Order order() => Order(
  id: '5',
  clientId: '1',
  distributorId: '1',
  storeName: 'СТО',
  documentNumber: 'ORD-00005',
  date: DateTime(2026),
  totalAmount: 1600,
  status: OrderStatus.confirmed,
  items: const [],
  createdAt: DateTime(2026),
  canChooseCash: true,
);

void main() {
  late CashRepo repo;
  setUp(() => repo = CashRepo());
  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'permission is off by default and changes only after successful save',
    (tester) async {
      when(
        () => repo.clientCashPermission('1'),
      ).thenAnswer((_) async => {'cashPaymentAllowed': false});
      final saved = Completer<Map<String, dynamic>>();
      when(
        () => repo.updateClientCashPermission('1', true),
      ).thenAnswer((_) => saved.future);
      await show(
        tester,
        ClientCashPermissionCard(clientId: '1', repository: repo),
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      saved.complete({'cashPaymentAllowed': true});
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      verify(() => repo.updateClientCashPermission('1', true)).called(1);
    },
  );

  testWidgets('failed permission update leaves the previous value', (
    tester,
  ) async {
    when(
      () => repo.clientCashPermission('1'),
    ).thenAnswer((_) async => {'cashPaymentAllowed': true});
    when(
      () => repo.updateClientCashPermission('1', false),
    ).thenThrow(Exception('403'));
    await show(
      tester,
      ClientCashPermissionCard(clientId: '1', repository: repo),
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(find.textContaining('Не удалось изменить доступ'), findsOneWidget);
  });

  testWidgets('order cash choice requires confirmation', (tester) async {
    when(() => repo.chooseOrderCash('5')).thenAnswer((_) async => order());
    var changed = false;
    await show(
      tester,
      OrderCashChoiceButton(
        order: order(),
        repository: repo,
        onChanged: (_) => changed = true,
      ),
    );
    await tester.tap(find.text('ОПЛАТА НАЛИЧНЫМИ КУРЬЕРУ'));
    await tester.pumpAndSettle();
    verifyNever(() => repo.chooseOrderCash('5'));
    await tester.tap(find.text('Выбрать наличные'));
    await tester.pumpAndSettle();
    verify(() => repo.chooseOrderCash('5')).called(1);
    expect(changed, isTrue);
  });

  testWidgets(
    'receipt enables completion only after confirmed server response',
    (tester) async {
      when(
        () => repo.courierCollectCash('7'),
      ).thenAnswer((_) async => task(collected: true));
      await show(
        tester,
        CourierTaskCard(task: task(), onUpdated: () {}, repository: repo),
      );
      final complete = find.widgetWithText(ElevatedButton, 'ЗАВЕРШИТЬ (ФОТО)');
      expect(tester.widget<ElevatedButton>(complete).onPressed, isNull);
      await tester.tap(find.text('ВЗЯЛ НАЛИЧНЫЕ'));
      await tester.pumpAndSettle();
      verifyNever(() => repo.courierCollectCash('7'));
      await tester.tap(find.text('Да, деньги получил'));
      await tester.pumpAndSettle();
      verify(() => repo.courierCollectCash('7')).called(1);
      expect(find.textContaining('НАЛИЧНЫЕ ПОЛУЧЕНЫ'), findsOneWidget);
      expect(find.text('ВЗЯЛ НАЛИЧНЫЕ'), findsNothing);
      expect(tester.widget<ElevatedButton>(complete).onPressed, isNotNull);
    },
  );

  testWidgets('cancelling receipt does not register money', (tester) async {
    await show(
      tester,
      CourierCashCollection(task: task(), repository: repo, onChanged: (_) {}),
    );
    await tester.tap(find.text('ВЗЯЛ НАЛИЧНЫЕ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Нет'));
    await tester.pumpAndSettle();
    verifyNever(() => repo.courierCollectCash('7'));
  });

  testWidgets('failed receipt keeps delivery blocked', (tester) async {
    when(() => repo.courierCollectCash('7')).thenThrow(Exception('network'));
    await show(
      tester,
      CourierTaskCard(task: task(), onUpdated: () {}, repository: repo),
    );
    await tester.tap(find.text('ВЗЯЛ НАЛИЧНЫЕ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Да, деньги получил'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Не удалось подтвердить наличные'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'ЗАВЕРШИТЬ (ФОТО)'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('online orders and assembly do not show receipt button', (
    tester,
  ) async {
    for (final value in [
      task(method: 'online'),
      task(status: CourierTaskStatus.assigned),
    ]) {
      await show(
        tester,
        CourierCashCollection(task: value, repository: repo, onChanged: (_) {}),
      );
      expect(find.text('ВЗЯЛ НАЛИЧНЫЕ'), findsNothing);
    }
  });

  testWidgets('courier can assemble before departing with a cash order', (
    tester,
  ) async {
    when(
      () => repo.courierPickItem('7', '1'),
    ).thenAnswer((_) async => task(status: CourierTaskStatus.assigned));
    await show(
      tester,
      CourierTaskCard(
        task: task(status: CourierTaskStatus.assigned, picked: false),
        onUpdated: () {},
        repository: repo,
      ),
    );
    final depart = find.widgetWithText(ElevatedButton, 'ПРИНЯТЬ В РАБОТУ');
    expect(tester.widget<ElevatedButton>(depart).onPressed, isNull);
    await tester.tap(find.text('СОБРАНО'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(depart).onPressed, isNotNull);
  });

  testWidgets('cash checkout shows full amount without a bonus deduction', (
    tester,
  ) async {
    when(() => repo.orderConfig()).thenAnswer(
      (_) async => OrderConfigData(
        client: Client(
          id: '1',
          inn: '123',
          name: 'СТО',
          category: ClientCategory.b,
          region: 'Регион',
          city: 'Город',
          contact: 'Иван',
          phone: '1',
          distributorId: '1',
          status: ClientStatus.active,
          createdAt: DateTime(2026),
          cashPaymentAllowed: true,
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
        bonusBalance: 200,
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
      (_) async => Paginated(
        items: [
          ProductData(
            id: '1',
            distributorId: '1',
            sku: 'P-1',
            name: 'Краска',
            category: 'Краски',
            brand: 'AutoTerra',
            volume: 1,
            price: 1000,
            quantity: 10,
            status: StockStatus.inStock,
            updatedAt: DateTime(2026),
          ),
        ],
        pageInfo: PageInfo.single(1),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: OrderScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ДОБАВИТЬ'));
    await tester.tap(find.text('ДОБАВИТЬ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Оплата наличными курьеру'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Оплата наличными курьеру'));
    await tester.pumpAndSettle();
    final notice = find.text(
      'Наличными курьеру: 1000 ₽. Бонусы при этом способе оплаты не списываются.',
    );
    await tester.scrollUntilVisible(
      notice,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(notice, findsOneWidget);
    expect(find.text('Спишется с этого заказа'), findsNothing);
  });

  test(
    'API sends permission, cash choice and receipt without trusting a client amount',
    () async {
      final calls = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          calls.add(request);
          return http.Response('{}', 200);
        }),
      );
      await api.updateClientCashPermission('1', true);
      await api.chooseOrderCash('5');
      await api.courierCollectCash('7');
      expect(jsonDecode(calls[0].body), {'cashPaymentAllowed': true});
      expect(calls[0].method, 'PATCH');
      expect(calls[1].url.path, '/api/orders/5/cash/');
      expect(calls[2].url.path, '/api/courier/tasks/7/collect-cash/');
      expect(jsonDecode(calls[2].body), isEmpty);
    },
  );
}
