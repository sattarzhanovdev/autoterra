import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/app.dart';

void main() {
  testWidgets('AutoTerra app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AutoterraApp());
    expect(find.byType(AutoterraApp), findsOneWidget);
  });
}
