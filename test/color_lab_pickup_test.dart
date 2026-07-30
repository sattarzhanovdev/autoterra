import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/core/theme.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/screens/distributor/distributor_color_lab_screen.dart';
import 'package:autoterra/services/data_repository.dart';

class MockDataRepository extends Mock implements DataRepository {}

/// Курьер только забирает лючок: готовую краску и лючок маляр забирает сам,
/// потому что оттенок проверяют на месте. Дистрибьютору при этом нужен
/// дедлайн — до скольки курьеру можно приехать.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU');
  });

  CourierTask pickupTask({CourierTaskStatus status = CourierTaskStatus.created}) {
    return CourierTask(
      id: '10', clientId: '1', clientName: 'Автосервис',
      taskType: 'color_lab_pickup', typeDisplay: 'Забор для Color Lab',
      address: 'Москва, пр. Мира 22', timeSlot: 'В течение дня',
      status: status, statusDisplay: '', createdAt: DateTime(2026, 7, 28),
    );
  }

  ColorRequest request({
    ColorRequestStatus status = ColorRequestStatus.created,
    String transferMethod = 'courier',
    String? arriveUntil,
    List<CourierTask> tasks = const [],
  }) {
    return ColorRequest(
      id: '1', clientId: '1', clientName: 'Автосервис',
      carBrand: 'Toyota', carModel: 'Camry', vin: 'XW8',
      colorCode: '1F7', colorName: 'Белый',
      status: status,
      transferMethod: transferMethod,
      pickupAddress: 'Москва, пр. Мира 22',
      courierArriveUntil: arriveUntil,
      courierTasks: tasks,
      createdAt: DateTime(2026, 7, 28, 9, 0),
    );
  }

  Future<void> pump(WidgetTester tester, ColorRequest item) async {
    final repo = MockDataRepository();
    when(() => repo.distributorColorRequests(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          activeOnly: any(named: 'activeOnly'),
        )).thenAnswer((_) async => Paginated<ColorRequest>(
          items: [item],
          pageInfo: const PageInfo(
            page: 1, pageSize: 20, count: 1, totalPages: 1,
            hasNext: false, hasPrevious: false,
          ),
        ));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: DistributorColorLabScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Показывает дедлайн «Забрать до»', (tester) async {
    await pump(tester, request(arriveUntil: '17:30', tasks: [pickupTask()]));

    expect(find.text('ЗАБРАТЬ ДО'), findsOneWidget);
    expect(find.text('17:30'), findsOneWidget);
  });

  testWidgets('Без указанного времени дедлайн не показывается', (tester) async {
    await pump(tester, request(tasks: [pickupTask()]));
    expect(find.text('ЗАБРАТЬ ДО'), findsNothing);
  });

  testWidgets('При самовывозе дедлайн курьера не показывается', (tester) async {
    await pump(tester, request(transferMethod: 'self_delivery', arriveUntil: '17:30'));
    expect(find.text('ЗАБРАТЬ ДО'), findsNothing);
  });

  testWidgets('Кнопка курьера за лючком остаётся', (tester) async {
    await pump(tester, request(tasks: [pickupTask()]));
    expect(find.text('НАЗНАЧИТЬ КУРЬЕРА ЗА ЛЮЧКОМ'), findsOneWidget);
  });

  testWidgets('У готовой заявки нет назначения курьера на возврат', (tester) async {
    await pump(tester, request(
      status: ColorRequestStatus.ready,
      tasks: [pickupTask(status: CourierTaskStatus.delivered)],
    ));

    expect(find.text('НАЗНАЧИТЬ КУРЬЕРА'), findsNothing);
    expect(find.textContaining('забирает готовую краску и лючок сам'), findsOneWidget);
  });

  test('Модель разбирает courierArriveUntil из ответа API', () {
    final parsed = ColorRequest.fromJson({
      'id': 1, 'clientId': 1, 'carBrand': 'Toyota', 'carModel': 'Camry',
      'vin': 'XW8', 'colorCode': '1F7', 'colorName': 'Белый',
      'status': 'created', 'transferMethod': 'courier',
      'courierArriveUntil': '17:30',
      'createdAt': '2026-07-28T09:00:00',
    });
    expect(parsed.courierArriveUntil, '17:30');
  });

  test('Отсутствие времени приезда — null, а не пустая строка', () {
    final parsed = ColorRequest.fromJson({
      'id': 1, 'clientId': 1, 'carBrand': 'Toyota', 'carModel': 'Camry',
      'vin': 'XW8', 'colorCode': '1F7', 'colorName': 'Белый',
      'status': 'created', 'transferMethod': 'courier',
      'createdAt': '2026-07-28T09:00:00',
    });
    expect(parsed.courierArriveUntil, isNull);
  });
}
