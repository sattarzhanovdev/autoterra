import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/screens/purchases/add_purchase_screen.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('AddPurchaseScreen shows Alert dialog on duplicate_detected error', (WidgetTester tester) async {
    // Устанавливаем большой размер экрана, чтобы все было на виду без скролла
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Создаем MockClient, который возвращает 400 Bad Request с ошибкой дубликата
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'detail': 'Duplicate detected',
          'error': 'duplicate_detected',
          'message': 'Покупка с такими данными уже загружена и имеет статус [На проверке]'
        }),
        400,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final testApi = ApiClient(client: mockClient);

    // 2. Отрисовываем экран
    await tester.pumpWidget(MaterialApp(
      home: AddPurchaseScreen(api: testApi),
    ));

    // 3. Заполняем поля формы
    await tester.enterText(find.byType(TextFormField).at(0), 'INV-12345'); // Номер документа
    
    // Выбираем дату через контроллер/стейт (сложно через UI без открытия пикера)
    // Но в нашем коде мы можем просто нажать на InkWell и сэмулировать выбор
    // Для простоты теста, мы можем найти стейт и установить дату вручную
    final state = tester.state<State<AddPurchaseScreen>>(find.byType(AddPurchaseScreen));
    // Т.к. поле _date приватное в стейте, мы можем использовать диагностику или просто нажать
    
    await tester.tap(find.text('ВЫБЕРИТЕ ДАТУ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // Выбираем текущую дату по умолчанию
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), '15000'); // Сумма

    // 4. Нажимаем кнопку отправки
    final submitButton = find.text('ОТПРАВИТЬ НА ПРОВЕРКУ');
    await tester.tap(submitButton);
    await tester.pump(); // Начинаем загрузку
    await tester.pumpAndSettle(); // Ждем завершения запроса и анимаций диалога

    // 5. Проверяем наличие диалога с ошибкой дубликата
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('ВНИМАНИЕ'), findsOneWidget);
    expect(find.textContaining('Покупка с такими данными уже загружена'), findsOneWidget);
    
    // Проверяем стиль (черный фон диалога)
    final alertDialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(alertDialog.backgroundColor, const Color(0xFF171717));
  });
}
