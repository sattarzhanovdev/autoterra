import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/core/theme.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/screens/distributor/distributor_clients_screen.dart';
import 'package:autoterra/screens/manager/manager_clients_screen.dart';
import 'package:autoterra/services/data_repository.dart';
import 'package:autoterra/widgets/layouts/admin_layout.dart';

class MockDataRepository extends Mock implements DataRepository {}

/// Кнопка выгрузки должна быть доступна всем трём ролям: дистрибьютору,
/// менеджеру региона и главному менеджеру. Главный менеджер до этого вообще
/// не имел в приложении экрана клиентов — только дашборд, 1С, задачи, профиль.
void main() {
  Client client(String company) => Client(
        id: '1',
        inn: '5556667778',
        name: company,
        category: ClientCategory.b,
        region: 'Москва',
        city: 'Москва',
        contact: 'Иван',
        phone: '+79001110000',
        distributorId: '1',
        status: ClientStatus.active,
        createdAt: DateTime(2026, 7, 1),
      );

  Paginated<Client> onePage() => Paginated<Client>(
        items: [client('ООО Ромашка')],
        pageInfo: const PageInfo(
          page: 1, pageSize: 20, count: 1, totalPages: 1,
          hasNext: false, hasPrevious: false,
        ),
      );

  MockDataRepository repoWithClients() {
    final repo = MockDataRepository();
    when(() => repo.distributorClients(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          search: any(named: 'search'),
        )).thenAnswer((_) async => onePage());
    when(() => repo.managerClientsFiltered(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          category: any(named: 'category'),
          regionId: any(named: 'regionId'),
          distributorId: any(named: 'distributorId'),
          search: any(named: 'search'),
        )).thenAnswer((_) async => onePage());
    return repo;
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('Дистрибьютор видит кнопку выгрузки', (tester) async {
    await pump(tester, DistributorClientsScreen(repository: repoWithClients()));

    final button = find.widgetWithIcon(IconButton, Icons.download_outlined);
    expect(button, findsOneWidget);
    expect(tester.widget<IconButton>(button).tooltip, 'Скачать список');
  });

  testWidgets('Менеджер региона видит кнопку выгрузки', (tester) async {
    await pump(tester, ManagerClientsScreen(repository: repoWithClients()));

    expect(find.widgetWithIcon(IconButton, Icons.download_outlined), findsOneWidget);
  });

  testWidgets('Тап открывает выбор формата', (tester) async {
    await pump(tester, ManagerClientsScreen(repository: repoWithClients()));

    await tester.tap(find.widgetWithIcon(IconButton, Icons.download_outlined));
    await tester.pumpAndSettle();

    expect(find.text('СКАЧАТЬ СПИСОК КЛИЕНТОВ'), findsOneWidget);
    expect(find.text('Excel'), findsOneWidget);
    expect(find.text('Word'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
  });

  testWidgets('У главного менеджера в меню есть вкладка «Клиенты»', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: AdminLayout()));
    await tester.pump();

    // BottomNavigationBar рисует подпись дважды (активная/неактивная), поэтому
    // findsWidgets, а не findsOneWidget.
    expect(find.byIcon(Icons.people_outline), findsOneWidget);
    expect(find.text('КЛИЕНТЫ'), findsWidgets);
    // Прежние разделы никуда не делись.
    for (final label in ['ДАШБОРД', 'ИНТЕГРАЦИИ 1С', 'ЗАДАЧИ', 'ПРОФИЛЬ']) {
      expect(find.text(label), findsWidgets, reason: 'потерялся раздел $label');
    }
  });
}
