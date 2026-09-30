import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/core/theme.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/services/pagination_controller.dart';
import 'package:autoterra/widgets/common/paginated_list_view.dart';

/// Смена категории на экране обучения подменяла контроллер целиком, а первая
/// загрузка запускалась только из initState — новый контроллер оставался
/// пустым, и вкладка показывала белый экран, пока список не потянут вниз.
void main() {
  PaginationController<String> controllerFor(
    List<String> items, {
    void Function()? onFetch,
  }) {
    return PaginationController<String>(
      fetchPage: (_) async {
        onFetch?.call();
        return Paginated<String>(
          items: items,
          pageInfo: PageInfo.single(items.length),
        );
      },
    );
  }

  Widget wrap(PaginationController<String> controller) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: PaginatedListView<String>(
          controller: controller,
          itemBuilder: (_, item, __) => Text(item),
        ),
      ),
    );
  }

  testWidgets('первая загрузка идёт сама', (tester) async {
    await tester.pumpWidget(wrap(controllerFor(['УРОК 1'])));
    await tester.pumpAndSettle();

    expect(find.text('УРОК 1'), findsOneWidget);
  });

  testWidgets('подменённый контроллер тоже грузится, без ручного обновления',
      (tester) async {
    await tester.pumpWidget(wrap(controllerFor(['УРОК 1'])));
    await tester.pumpAndSettle();

    var fetched = false;
    await tester.pumpWidget(
      wrap(controllerFor(['ВИДЕО 1'], onFetch: () => fetched = true)),
    );
    await tester.pumpAndSettle();

    expect(fetched, isTrue, reason: 'новый контроллер должен сходить за данными');
    expect(find.text('ВИДЕО 1'), findsOneWidget);
    expect(find.text('УРОК 1'), findsNothing);
  });

  testWidgets('тот же контроллер повторно не перезапрашивается',
      (tester) async {
    var fetches = 0;
    final controller = controllerFor(['УРОК 1'], onFetch: () => fetches++);

    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();
    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    expect(fetches, 1);
  });
}
