import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/screens/distributor/distributor_stock_screen.dart';

void main() {
  group('Manual Stock Entry Component Tests', () {
    testWidgets('Add Product form allows text entry', (WidgetTester tester) async {
      // Test the component directly to avoid Scaffold/Navigator complexity
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddProductSheet(onAdded: () {}),
          ),
        ),
      );

      // Find fields by label
      final skuField = find.widgetWithText(TextField, 'АРТИКУЛ (SKU) *');
      final nameField = find.widgetWithText(TextField, 'НАЗВАНИЕ *');
      
      expect(skuField, findsOneWidget);
      expect(nameField, findsOneWidget);

      // Enter data
      await tester.enterText(skuField, 'TEST-SKU');
      await tester.enterText(nameField, 'Test Product');
      
      expect(find.text('TEST-SKU'), findsOneWidget);
      expect(find.text('Test Product'), findsOneWidget);
    });

    testWidgets('Add Product form shows validation error', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddProductSheet(onAdded: () {}),
          ),
        ),
      );

      final submitButton = find.text('ДОБАВИТЬ ТОВАР');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Check for snackbar text
      expect(find.text('SKU и Название обязательны'), findsOneWidget);
    });
  });
}
