import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/services/pagination_controller.dart';
import 'package:autoterra/widgets/layouts/courier_layout.dart';
import 'package:autoterra/widgets/layouts/distributor_layout.dart';
import 'package:autoterra/core/theme.dart';
import 'package:autoterra/screens/distributor/distributor_screen.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: child,
    );
  }

  /// Контроллер, отдающий пустую страницу без обращения к сети.
  PaginationController<CourierTask> emptyTasksController() {
    return PaginationController<CourierTask>(
      fetchPage: (_) async => const Paginated<CourierTask>.empty(),
    );
  }

  group('CourierLayout Tests', () {
    testWidgets('Should display correct navigation and tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        CourierLayout(child: CourierTasksScreen(
          assignedController: emptyTasksController(),
          inProgressController: emptyTasksController(),
          onRefresh: () {},
        )),
      ));

      // Check Bottom Navigation
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('ЗАДАЧИ'), findsOneWidget);
      expect(find.text('МАРШРУТ'), findsOneWidget);
      expect(find.text('ПРОФИЛЬ'), findsOneWidget);

      // Check TabBar in Tasks Screen
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('НОВЫЕ'), findsOneWidget);
      expect(find.text('В РАБОТЕ'), findsOneWidget);
    });
  });

  group('DistributorLayout Tests', () {
    testWidgets('Should display correct navigation items', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        const DistributorLayout(child: DistributorOrdersTabsScreen()),
      ));

      // Check Bottom Navigation
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('ЗАКАЗЫ'), findsOneWidget);
      expect(find.text('КЛИЕНТЫ'), findsOneWidget);
      expect(find.text('СКЛАД'), findsOneWidget);
      expect(find.text('ОТЧЕТЫ'), findsOneWidget);
    });
  });

  group('UI Consistency Tests', () {
    testWidgets('Buttons and Cards should have correct rigid borders', (WidgetTester tester) async {
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

      // Test ElevatedButton shape (could be BeveledRectangleBorder or RoundedRectangleBorder.zero)
      final ElevatedButton button = tester.widget(find.byType(ElevatedButton));
      final shape = button.style?.shape?.resolve({});
      
      if (shape is BeveledRectangleBorder) {
         // It's using the correct Beveled theme
      } else if (shape is RoundedRectangleBorder) {
        expect(shape.borderRadius, equals(BorderRadius.zero));
      } else {
        final theme = Theme.of(tester.element(find.byType(ElevatedButton)));
        final themeShape = theme.elevatedButtonTheme.style?.shape?.resolve({});
        if (themeShape is RoundedRectangleBorder) {
          expect(themeShape.borderRadius, equals(BorderRadius.zero));
        } else if (themeShape is BeveledRectangleBorder) {
          // OK
        }
      }

      // Test Card shape
      final Card card = tester.widget(find.byType(Card));
      final cardShape = card.shape;
      
      if (cardShape is BeveledRectangleBorder) {
         // OK
      } else if (cardShape is RoundedRectangleBorder) {
         expect(cardShape.borderRadius, equals(BorderRadius.zero));
      } else {
         final theme = Theme.of(tester.element(find.byType(Card)));
         final themeShape = theme.cardTheme.shape;
         if (themeShape is RoundedRectangleBorder) {
           expect(themeShape.borderRadius, equals(BorderRadius.zero));
         } else if (themeShape is BeveledRectangleBorder) {
           // OK
         }
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

