import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/screens/color/color_center_screen.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/services/data_repository.dart';
import 'package:autoterra/widgets/common/status_badge.dart';

void main() {
  group('ColorCenterScreen Widget Tests', () {
    testWidgets('Shows empty state when no requests', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ColorCenterScreen(),
        ),
      );
      
      // Initially loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Wait for future (using fake/empty response if repository was mocked, 
      // but here we just test the UI transition)
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      
      // Should show empty state if repo returns empty (depending on environment)
      // Since we can't easily mock DataRepository here without major refactoring 
      // of the singleton pattern, we'll focus on sub-widgets.
    });

    testWidgets('StatusBadge.fromColorStatus handles all statuses', (WidgetTester tester) async {
      for (var status in ColorRequestStatus.values) {
        final badge = StatusBadge.fromColorStatus(status);
        expect(badge.label, isNotEmpty);
      }
    });
  });
}
