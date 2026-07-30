import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/core/theme.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/screens/delivery/delivery_screen.dart';
import 'package:autoterra/services/data_repository.dart';

class MockDataRepository extends Mock implements DataRepository {}

/// Карточка доставки должна объяснять клиенту, что происходит с его заказом:
/// подписанные этапы, время перехода, курьер и телефон.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU');
  });

  CourierTask task({
    required CourierTaskStatus status,
    String taskType = 'delivery',
    String typeDisplay = 'Доставка',
    String? courierName,
    String? courierPhone,
    String? orderId,
    List<CourierTaskEvent> history = const [],
  }) {
    return CourierTask(
      id: '1',
      clientId: '1',
      clientName: 'Автосервис',
      courierName: courierName,
      courierPhone: courierPhone,
      orderId: orderId,
      taskType: taskType,
      typeDisplay: typeDisplay,
      address: 'Москва, пр. Мира 22',
      contactName: 'Иван',
      timeSlot: '10:00 - 18:00',
      status: status,
      statusDisplay: '',
      statusHistory: history,
      createdAt: DateTime(2026, 7, 27, 9, 30),
    );
  }

  Future<void> pumpTasks(WidgetTester tester, List<CourierTask> tasks) async {
    final repo = MockDataRepository();
    when(() => repo.courierTasks(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          activeOnly: any(named: 'activeOnly'),
        )).thenAnswer((_) async => Paginated<CourierTask>(
          items: tasks,
          pageInfo: PageInfo(
            page: 1, pageSize: 20, count: tasks.length, totalPages: 1,
            hasNext: false, hasPrevious: false,
          ),
        ));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: DeliveryScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Все этапы подписаны, а не только текущий', (tester) async {
    await pumpTasks(tester, [task(status: CourierTaskStatus.inProgress)]);

    expect(find.text('Создана'), findsOneWidget);
    expect(find.text('Курьер назначен'), findsOneWidget);
    expect(find.text('В пути'), findsOneWidget);
    expect(find.text('Доставлено'), findsOneWidget);
  });

  testWidgets('Заявка «в пути» не подписана как «Лючок забран»', (tester) async {
    await pumpTasks(tester, [task(status: CourierTaskStatus.inProgress)]);

    // Старая шкала брала подпись по индексу статуса и показывала доставке
    // подписи из сценария забора лючка.
    expect(find.textContaining('Лючок'), findsNothing);
    expect(find.textContaining('Курьер уже в пути'), findsOneWidget);
  });

  testWidgets('У забора лючка последний этап называется «Забрано»', (tester) async {
    await pumpTasks(tester, [
      task(status: CourierTaskStatus.assigned, taskType: 'pickup', typeDisplay: 'Забор лючка'),
    ]);

    expect(find.text('Забрано'), findsOneWidget);
    expect(find.text('Доставлено'), findsNothing);
  });

  testWidgets('Отменённая заявка не выглядит выполненной', (tester) async {
    await pumpTasks(tester, [task(status: CourierTaskStatus.cancelled)]);

    expect(find.textContaining('Заявка отменена'), findsOneWidget);
    // Шкала прогресса для отменённой заявки не показывается вовсе.
    expect(find.text('Доставлено'), findsNothing);
  });

  testWidgets('Показывает курьера и кнопку звонка', (tester) async {
    await pumpTasks(tester, [
      task(
        status: CourierTaskStatus.inProgress,
        courierName: 'Пётр Курьеров',
        courierPhone: '+79001112233',
      ),
    ]);

    expect(find.text('Пётр Курьеров'), findsOneWidget);
    expect(find.text('ПОЗВОНИТЬ'), findsOneWidget);
  });

  testWidgets('Без назначенного курьера объясняет, чего ждать', (tester) async {
    await pumpTasks(tester, [task(status: CourierTaskStatus.created)]);

    expect(find.textContaining('Назначаем курьера'), findsOneWidget);
    expect(find.text('ПОЗВОНИТЬ'), findsNothing);
  });

  testWidgets('Показывает номер заказа и время этапов', (tester) async {
    await pumpTasks(tester, [
      task(
        status: CourierTaskStatus.inProgress,
        orderId: '128',
        history: [
          CourierTaskEvent(status: CourierTaskStatus.created, at: DateTime(2026, 7, 27, 9, 30)),
          CourierTaskEvent(status: CourierTaskStatus.assigned, at: DateTime(2026, 7, 27, 13, 5)),
          CourierTaskEvent(status: CourierTaskStatus.inProgress, at: DateTime(2026, 7, 27, 14, 20)),
        ],
      ),
    ]);

    expect(find.textContaining('Заказ №128'), findsOneWidget);
    expect(find.textContaining('27 июл'), findsWidgets);
  });
}
