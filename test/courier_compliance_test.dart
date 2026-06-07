import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/widgets/layouts/courier_layout.dart';
import 'package:autoterra/core/theme.dart';
import 'package:autoterra/models/models.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: child,
    );
  }

  group('CourierLayout Navigation Tests', () {
    testWidgets('Tapping on Route tab should change the screen content', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        const CourierLayout(child: SizedBox()),
      ));

      // 1. Initial state check (Tasks)
      expect(find.text('ЛОГИСТИКА / КУРЬЕР'), findsOneWidget);

      // 2. Tap on "Маршрут" (Index 1)
      await tester.tap(find.text('МАРШРУТ'));
      await tester.pumpAndSettle();

      // 3. Verify screen changed
      expect(find.text('ТЕКУЩИЙ МАРШРУТ'), findsOneWidget);
    });
  });

  group('CourierLayout UI Brand Compliance Tests', () {
    testWidgets('CourierTaskCard must not use forbidden colors (green, purple)', (WidgetTester tester) async {
      final task1 = CourierTask(
        id: '1',
        clientId: 'c1',
        clientName: 'Test Client 1',
        taskType: 'delivery',
        typeDisplay: 'DELIVERY',
        address: 'Test Address 1',
        timeSlot: '12:00',
        status: CourierTaskStatus.assigned,
        statusDisplay: 'new',
        createdAt: DateTime.now(),
      );

      final task2 = CourierTask(
        id: '2',
        clientId: 'c2',
        clientName: 'Test Client 2',
        taskType: 'pickup',
        typeDisplay: 'COLOR LAB',
        address: 'Test Address 2',
        timeSlot: '13:00',
        status: CourierTaskStatus.inProgress,
        statusDisplay: 'in_progress',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(
        Scaffold(
          body: Column(
            children: [
              CourierTaskCard(task: task1, onUpdated: () {}),
              CourierTaskCard(task: task2, onUpdated: () {}),
            ],
          ),
        ),
      ));

      final containerWidgets = tester.widgetList<Container>(find.byType(Container));
      final elevatedButtons = tester.widgetList<ElevatedButton>(find.byType(ElevatedButton));

      void checkColor(Color? color) {
        if (color == null) return;
        expect(color, isNot(Colors.green));
        expect(color, isNot(Colors.greenAccent));
        expect(color, isNot(Colors.purple));
        expect(color, isNot(Colors.purpleAccent));
      }

      for (var container in containerWidgets) {
        if (container.decoration is BoxDecoration) {
          checkColor((container.decoration as BoxDecoration).color);
        } else if (container.color != null) {
          checkColor(container.color);
        }
      }

      for (var button in elevatedButtons) {
        final color = button.style?.backgroundColor?.resolve({});
        checkColor(color);
      }
    });
  });
}

