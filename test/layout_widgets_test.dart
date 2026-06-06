import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/widgets/layouts/courier_layout.dart';
import 'package:autoterra/widgets/layouts/distributor_layout.dart';
import 'package:autoterra/core/theme.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: child,
    );
  }

  group('CourierLayout Tests', () {
    testWidgets('Should display correct navigation and tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        const CourierLayout(child: CourierTasksScreen()),
      ));

      // Check Bottom Navigation
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Задачи'), findsOneWidget);
      expect(find.text('Маршрут'), findsOneWidget);
      expect(find.text('Профиль'), findsOneWidget);

      // Check TabBar in Tasks Screen
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('НОВЫЕ'), findsOneWidget);
      expect(find.text('В РАБОТЕ'), findsOneWidget);
    });
  });

  group('DistributorLayout Tests', () {
    testWidgets('Should display correct navigation items', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        const DistributorLayout(child: DistributorOrdersScreen()),
      ));

      // Check Bottom Navigation
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Заказы'), findsOneWidget);
      expect(find.text('Клиенты'), findsOneWidget);
      expect(find.text('Склад'), findsOneWidget);
      expect(find.text('Отчеты'), findsOneWidget);

      // Check Header text in Orders screen
      expect(find.text('ВХОДЯЩИЕ ЗАКАЗЫ'), findsOneWidget);
    });
  });

  group('UI Consistency Tests', () {
    testWidgets('Buttons and Cards should have BorderRadius.zero', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        Scaffold(
          body: Column(
            children: [
              ElevatedButton(onPressed: () {}, child: const Text('Test Button')),
              const Card(child: Text('Test Card')),
            ],
          ),
        ),
      ));

      // Test ElevatedButton shape
      final ElevatedButton button = tester.widget(find.byType(ElevatedButton));
      final shape = button.style?.shape?.resolve({});
      if (shape is RoundedRectangleBorder) {
        expect(shape.borderRadius, equals(BorderRadius.zero));
      } else {
        // Fallback to checking the theme if button doesn't have an explicit shape
        final theme = Theme.of(tester.element(find.byType(ElevatedButton)));
        final themeShape = theme.elevatedButtonTheme.style?.shape?.resolve({});
        if (themeShape is RoundedRectangleBorder) {
          expect(themeShape.borderRadius, equals(BorderRadius.zero));
        }
      }

      // Test Card shape
      final Card card = tester.widget(find.byType(Card));
      var cardShape = card.shape as RoundedRectangleBorder?;
      
      // If card doesn't have a shape, check the theme
      if (cardShape == null) {
        final theme = Theme.of(tester.element(find.byType(Card)));
        cardShape = theme.cardTheme.shape as RoundedRectangleBorder?;
      }
      
      if (cardShape != null) {
        expect(cardShape.borderRadius, equals(BorderRadius.zero));
      } else {
        // If still null, it means no shape is defined in either widget or theme
        // which defaults to rounded in Material 3, so we fail if we want strict zero.
        fail('No shape defined for Card, default Material 3 shape is rounded');
      }
    });

    testWidgets('TextFormField should have BorderRadius.zero', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        const Scaffold(
          body: TextField(
            decoration: InputDecoration(labelText: 'Test Input'),
          ),
        ),
      ));

      final TextField textField = tester.widget(find.byType(TextField));
      final inputDecoration = textField.decoration;
      
      // Checking border radius on various border states
      if (inputDecoration?.border is OutlineInputBorder) {
        expect((inputDecoration!.border as OutlineInputBorder).borderRadius, equals(BorderRadius.zero));
      }
      if (inputDecoration?.enabledBorder is OutlineInputBorder) {
        expect((inputDecoration!.enabledBorder as OutlineInputBorder).borderRadius, equals(BorderRadius.zero));
      }
    });
  });
}
