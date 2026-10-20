import 'package:autoterra/models/models.dart';
import 'package:autoterra/screens/orders/order_screen.dart';
import 'package:autoterra/screens/admin/admin_integration_screen.dart';
import 'package:autoterra/models/paginated.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/screens/clients/client_settings_card.dart';
import 'package:autoterra/screens/profile/distributor_profile_editor.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/data_repository.dart';

class SettingsRepo extends Mock implements DataRepository {}

Map<String, dynamic> settings({
  bool edit = true,
  String category = 'b',
  String status = 'active',
}) => {
  'client': {'status': status, 'category': category},
  'canEdit': edit,
  'statuses': [
    {'value': 'active', 'label': 'Активный'},
    {'value': 'blocked', 'label': 'Заблокирован'},
  ],
  'categories': [
    {'value': 'b', 'label': 'B · Автосервис с кузовным цехом'},
    {'value': 's', 'label': 'Магазин'},
  ],
};

void main() {
  late SettingsRepo repo;
  setUp(() {
    repo = SettingsRepo();
    when(() => repo.clientSettings('1')).thenAnswer((_) async => settings());
    when(() => repo.updateClientSettings('1', any())).thenAnswer((call) async {
      final values = call.positionalArguments[1] as Map<String, dynamic>;
      return settings(category: values['category'], status: values['status']);
    });
  });

  Future<void> open(WidgetTester tester, {VoidCallback? changed}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientSettingsCard(
            clientId: '1',
            repository: repo,
            onChanged: changed,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('backend choices save and update immediately on narrow screen', (
    tester,
  ) async {
    var changes = 0;
    await open(tester, changed: () => changes++);
    await tester.tap(find.byTooltip('Изменить статус и категорию'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Магазин').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Категория: Магазин'), findsOneWidget);
    expect(changes, 1);
    expect(tester.takeException(), isNull);
    verify(
      () =>
          repo.updateClientSettings('1', {'status': 'active', 'category': 's'}),
    ).called(1);
  });

  testWidgets('manager confirms registration without financial edit access', (
    tester,
  ) async {
    var approved = false;
    when(() => repo.clientSettings('1')).thenAnswer(
      (_) async => {
        ...settings(edit: false, status: approved ? 'active' : 'new'),
        'canApprove': !approved,
      },
    );
    when(() => repo.approveClient('1')).thenAnswer((_) async {
      approved = true;
    });
    var changes = 0;
    await open(tester, changed: () => changes++);
    expect(find.byTooltip('Изменить статус и категорию'), findsNothing);
    await tester.tap(find.text('ПОДТВЕРДИТЬ РЕГИСТРАЦИЮ'));
    await tester.pumpAndSettle();
    expect(find.text('Статус: Активный'), findsOneWidget);
    expect(find.text('ПОДТВЕРДИТЬ РЕГИСТРАЦИЮ'), findsNothing);
    expect(changes, 1);
    verify(() => repo.approveClient('1')).called(1);
  });

  testWidgets('failed approval keeps registration available to retry', (
    tester,
  ) async {
    when(() => repo.clientSettings('1')).thenAnswer(
      (_) async => {
        ...settings(edit: false, status: 'new'),
        'canApprove': true,
      },
    );
    when(() => repo.approveClient('1')).thenThrow(Exception('offline'));
    await open(tester);
    await tester.tap(find.text('ПОДТВЕРДИТЬ РЕГИСТРАЦИЮ'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Не удалось подтвердить регистрацию:'),
      findsOneWidget,
    );
    expect(find.text('ПОДТВЕРДИТЬ РЕГИСТРАЦИЮ'), findsOneWidget);
  });

  testWidgets('read-only role has no edit control', (tester) async {
    when(
      () => repo.clientSettings('1'),
    ).thenAnswer((_) async => settings(edit: false));
    await open(tester);
    expect(find.byTooltip('Изменить статус и категорию'), findsNothing);
  });

  testWidgets('load failure can retry', (tester) async {
    when(() => repo.clientSettings('1')).thenThrow(Exception('offline'));
    await open(tester);
    expect(find.text('Не удалось загрузить настройки клиента'), findsOneWidget);
    when(() => repo.clientSettings('1')).thenAnswer((_) async => settings());
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('Статус: Активный'), findsOneWidget);
  });

  testWidgets('failed save keeps current data and allows retry', (
    tester,
  ) async {
    when(
      () => repo.updateClientSettings('1', any()),
    ).thenThrow(Exception('offline'));
    await open(tester);
    await tester.tap(find.byTooltip('Изменить статус и категорию'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось сохранить настройки клиента'), findsOneWidget);
    expect(find.text('Статус: Активный'), findsOneWidget);
  });

  testWidgets(
    'profile editor validates, saves contacts and preserves critical identity',
    (tester) async {
      when(() => repo.updateDistributorProfile(any())).thenAnswer(
        (_) async => {
          'distributor': {'name': 'Новое имя'},
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => DistributorProfileEditor(
                    distributor: {
                      'name': 'Дистрибьютор',
                      'email': 'old@example.com',
                      'phone': '+79001234567',
                    },
                    repository: repo,
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
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'invalid');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Введите email'), findsOneWidget);
      verifyNever(() => repo.updateDistributorProfile(any()));
      await tester.enterText(fields.at(0), 'Новое имя');
      await tester.enterText(fields.at(1), 'new@example.com');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      verify(
        () => repo.updateDistributorProfile({
          'name': 'Новое имя',
          'email': 'new@example.com',
          'phone': '+79001234567',
        }),
      ).called(1);
      expect(find.byType(DistributorProfileEditor), findsNothing);
    },
  );

  testWidgets('integration failure shows retry instead of fabricated tokens', (
    tester,
  ) async {
    when(
      () => repo.adminIntegrationTokens(page: any(named: 'page')),
    ).thenThrow(Exception('offline'));
    await tester.pumpWidget(
      MaterialApp(home: AdminIntegrationScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Не удалось загрузить интеграции'),
      findsOneWidget,
    );
    expect(find.textContaining('abc123'), findsNothing);
    expect(find.text('ГЕНЕРИРОВАТЬ'), findsNothing);
    when(
      () => repo.adminIntegrationTokens(page: any(named: 'page')),
    ).thenAnswer((_) async => const Paginated.empty());
    when(
      () => repo.adminIntegrationLogs(),
    ).thenAnswer((_) async => const Paginated.empty());
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Не удалось загрузить интеграции'),
      findsNothing,
    );
    expect(find.text('ТОКЕНЫ ДИСТРИБЬЮТОРОВ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('order configuration failure has a working retry', (
    tester,
  ) async {
    when(
      () => repo.products(
        page: any(named: 'page'),
        search: any(named: 'search'),
        category: any(named: 'category'),
        brand: any(named: 'brand'),
        inStockOnly: any(named: 'inStockOnly'),
      ),
    ).thenAnswer((_) async => const Paginated.empty());
    // Use an asynchronous failure so FutureBuilder can render the error.
    when(
      () => repo.orderConfig(),
    ).thenAnswer((_) async => throw Exception('offline'));
    await tester.pumpWidget(MaterialApp(home: OrderScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    verify(() => repo.orderConfig()).called(2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a cash order preserves selected payment method', (
    tester,
  ) async {
    when(() => repo.orderConfig()).thenAnswer(
      (_) async => OrderConfigData(
        client: Client(
          id: '1',
          inn: '1234567890',
          name: 'Клиент',
          category: ClientCategory.b,
          region: 'Регион',
          city: 'Город',
          contact: 'Контакт',
          phone: '1',
          distributorId: '1',
          status: ClientStatus.active,
          cashPaymentAllowed: true,
          createdAt: DateTime(2026),
        ),
        distributor: const Distributor(
          id: '1',
          name: 'Дистрибьютор',
          inn: '1',
          regions: [],
          phone: '1',
          email: 'a@example.com',
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
    ).thenAnswer((_) async => const Paginated.empty());
    final order = Order(
      id: '5',
      clientId: '1',
      distributorId: '1',
      storeName: '',
      documentNumber: 'ORD-5',
      date: DateTime(2026),
      totalAmount: 0,
      status: OrderStatus.newOrder,
      paymentMethod: 'cash',
      items: const [],
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OrderScreen(initialOrder: order, repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(SwitchListTile),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  test('repository sends cash and atomic replacement to API', () async {
    final requests = <http.Request>[];
    final repository = DataRepository(
      api: ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 201);
        }),
      ),
    );
    await repository.createOrder(
      items: [
        {'productId': '1', 'quantity': 2},
      ],
      comment: '',
      paymentMethod: 'cash',
    );
    await repository.createOrder(
      items: [
        {'productId': '1', 'quantity': 3},
      ],
      comment: 'Новый',
      replaceOrderId: '5',
    );
    expect(jsonDecode(requests.first.body)['paymentMethod'], 'cash');
    expect(requests.last.url.path, '/api/orders/5/replace/');
    expect(requests.length, 2);
  });
}
