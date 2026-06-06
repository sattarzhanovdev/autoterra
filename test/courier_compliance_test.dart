import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/widgets/layouts/courier_layout.dart';
import 'package:autoterra/core/theme.dart';

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
      expect(find.text('РАЗДЕЛ МАРШРУТ В РАЗРАБОТКЕ'), findsNothing);

      // 2. Tap on "Маршрут" (Index 1)
      // BottomNavigationBar items are typically rendered as widgets containing the label
      await tester.tap(find.text('МАРШРУТ'));
      await tester.pumpAndSettle();

      // 3. Verify screen changed
      expect(find.text('РАЗДЕЛ МАРШРУТ В РАЗРАБОТКЕ'), findsOneWidget);
      expect(find.text('ЛОГИСТИКА / КУРЬЕР'), findsNothing);
    });
  });

  group('CourierLayout UI Brand Compliance Tests', () {
    testWidgets('CourierTaskCard must not use forbidden colors (green, purple)', (WidgetTester tester) async {
      // Test two variants: normal delivery and Color Lab
      await tester.pumpWidget(createTestWidget(
        const Scaffold(
          body: Column(
            children: [
              CourierTaskCard(
                address: 'Test 1',
                time: '12:00',
                type: 'DELIVERY',
                isColorLab: false,
                status: 'new',
              ),
              CourierTaskCard(
                address: 'Test 2',
                time: '13:00',
                type: 'COLOR LAB',
                isColorLab: true,
                status: 'in_progress',
              ),
            ],
          ),
        ),
      ));

      // Inspect all Containers and Buttons for background colors
      final containerWidgets = tester.widgetList<Container>(find.byType(Container));
      final elevatedButtons = tester.widgetList<ElevatedButton>(find.byType(ElevatedButton));

      // Helper to check for forbidden colors
      void checkColor(Color? color) {
        if (color == null) return;
        
        // Green and Purple are strictly forbidden
        expect(color, isNot(Colors.green));
        expect(color, isNot(Colors.greenAccent));
        expect(color, isNot(Colors.purple));
        expect(color, isNot(Colors.purpleAccent));
        
        // Even approximated check: green has high green component, purple has high red and blue
        // But for strict test we just check exact matches from Material palette
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
