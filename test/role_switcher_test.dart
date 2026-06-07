import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/app.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/services/auth_service.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('RoleSwitcher changes app role and updates UI', (WidgetTester tester) async {
    // 1. Имитируем авторизацию, чтобы GoRouter пустил нас на главную
    SharedPreferences.setMockInitialValues({'auth_token': 'test_token'});
    await ApiClient.loadSavedToken();
    
    // Сбрасываем роль на клиентскую перед тестом
    authService.setRole(UserRole.client);

    // Устанавливаем размер экрана для теста
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    // 2. Запускаем приложение
    await tester.pumpWidget(const AutoterraApp());
    await tester.pumpAndSettle();

    // 3. Проверяем, что по умолчанию загрузился клиентский интерфейс
    // (в нем есть BottomNavigationBar с вкладкой "Главная")
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Главная'), findsOneWidget);

    // 4. Находим кнопку переключателя (иконка щита) и делаем Long Press
    final switcherIcon = find.byIcon(Icons.admin_panel_settings);
    expect(switcherIcon, findsOneWidget);
    
    await tester.longPress(switcherIcon);
    await tester.pump(); // Ждем появления меню

    // 5. Выбираем роль курьера из списка (названия в апперкейсе)
    final courierOption = find.text('COURIER');
    expect(courierOption, findsOneWidget);
    
    await tester.tap(courierOption);
    await tester.pumpAndSettle();

    // 6. Проверяем, что интерфейс сменился на курьерский
    // На экране должен быть заголовок кабинета курьера и не должно быть таббара
    expect(find.text('Кабинет курьера'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);

    // 7. Проверяем, что состояние в AuthService обновилось
    expect(authService.currentRole, UserRole.courier);

    // Очистка ресурсов
    addTearDown(tester.view.resetPhysicalSize);
  });
}
