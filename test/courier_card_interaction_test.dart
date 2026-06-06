import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/widgets/layouts/courier_layout.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/services/data_repository.dart';

class MockDataRepository extends Mock implements DataRepository {}

void main() {
  late MockDataRepository mockRepository;

  setUp(() {
    mockRepository = MockDataRepository();
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  final testTaskAssigned = CourierTask(
    id: '1',
    clientId: '101',
    clientName: 'Test Client',
    taskType: 'delivery',
    typeDisplay: 'Доставка',
    address: 'Test Address',
    timeSlot: '10:00-12:00',
    status: CourierTaskStatus.assigned,
    statusDisplay: 'Назначен',
    createdAt: DateTime.now(),
  );

  final testTaskInProgress = CourierTask(
    id: '2',
    clientId: '101',
    clientName: 'Test Client',
    taskType: 'delivery',
    typeDisplay: 'Доставка',
    address: 'Test Address',
    timeSlot: '10:00-12:00',
    status: CourierTaskStatus.inProgress,
    statusDisplay: 'В пути',
    createdAt: DateTime.now(),
  );

  group('CourierTaskCard Smoke Tests', () {
    testWidgets('Should display "ПРИНЯТЬ В РАБОТУ" for assigned status', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        CourierTaskCard(
          task: testTaskAssigned,
          onUpdated: () {},
          repository: mockRepository,
        ),
      ));

      expect(find.text('ПРИНЯТЬ В РАБОТУ'), findsOneWidget);
      expect(find.text('ЗАВЕРШИТЬ (ФОТО)'), findsNothing);
    });

    testWidgets('Should display "ЗАВЕРШИТЬ (ФОТО)" for inProgress status', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        CourierTaskCard(
          task: testTaskInProgress,
          onUpdated: () {},
          repository: mockRepository,
        ),
      ));

      expect(find.text('ЗАВЕРШИТЬ (ФОТО)'), findsOneWidget);
      expect(find.text('ПРИНЯТЬ В РАБОТУ'), findsNothing);
    });
  });

  group('CourierTaskCard Interaction Tests', () {
    testWidgets('Tapping Accept should call repository update', (WidgetTester tester) async {
      // Mock the repository call
      when(() => mockRepository.updateCourierTaskStatus('1', status: 'in_progress'))
          .thenAnswer((_) async => testTaskInProgress);

      await tester.pumpWidget(createTestWidget(
        CourierTaskCard(
          task: testTaskAssigned,
          onUpdated: () {},
          repository: mockRepository,
        ),
      ));

      await tester.tap(find.text('ПРИНЯТЬ В РАБОТУ'));
      await tester.pump(); // Start animation/loading

      verify(() => mockRepository.updateCourierTaskStatus('1', status: 'in_progress')).called(1);
    });
  });
}
