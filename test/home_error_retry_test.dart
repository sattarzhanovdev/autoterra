import 'package:autoterra/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// Экран с ошибкой подключения был тупиком: ни кнопки, ни «потянуть вниз» —
/// выручал только перезапуск приложения. Тест держит выход открытым.
void main() {
  setUpAll(() {
    // Порт 1 закрыт всегда: соединение отваливается сразу, без ожидания DNS.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://127.0.0.1:1/api/');
  });

  testWidgets('на ошибке подключения есть кнопка «Повторить»', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ClientHomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('ОШИБКА ПОДКЛЮЧЕНИЯ К СЕРВЕРУ'), findsOneWidget);
    expect(find.text('ПОВТОРИТЬ'), findsOneWidget);
  });

  testWidgets('кнопка «Повторить» перезапрашивает данные', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ClientHomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ПОВТОРИТЬ'));
    await tester.pump();

    // Пока запрос в полёте — индикатор загрузки вместо ошибки.
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();
    // Сервера по-прежнему нет — снова ошибка, и снова с выходом.
    expect(find.text('ПОВТОРИТЬ'), findsOneWidget);
  });

  testWidgets('экран ошибки можно потянуть вниз для обновления', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ClientHomeScreen()));
    await tester.pumpAndSettle();

    // Жест сработает, только если ошибка лежит в прокручиваемом списке.
    await tester.fling(find.text('ОШИБКА ПОДКЛЮЧЕНИЯ К СЕРВЕРУ'), const Offset(0, 300), 1000);
    await tester.pump();
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('ПОВТОРИТЬ'), findsOneWidget);
  });
}
