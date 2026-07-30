import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/core/theme.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/file_download_service.dart';
import 'package:autoterra/widgets/common/export_sheet.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDownloader extends Mock implements FileDownloadService {}

/// Скачивание списка клиентов: файл сохраняется сразу, без меню «Поделиться»,
/// и человек видит, куда он лёг и скачался ли.
void main() {
  late MockApiClient api;
  late MockDownloader downloader;

  setUpAll(() {
    // any() для непримитивных типов требует зарегистрированного значения.
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    api = MockApiClient();
    downloader = MockDownloader();
    when(() => downloader.destinationLabel).thenReturn('Загрузки');
    when(() => downloader.save(
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
          format: any(named: 'format'),
        )).thenAnswer((invocation) async => SavedFile(
          displayPath: 'Загрузки/${invocation.namedArguments[const Symbol('fileName')]}',
          path: '/tmp/${invocation.namedArguments[const Symbol('fileName')]}',
        ));
  });

  void stubExport({String fileName = 'autoterra-clients-2026-07-30.xlsx'}) {
    when(() => api.exportClients(
          format: any(named: 'format'),
          search: any(named: 'search'),
          status: any(named: 'status'),
          partnerStatus: any(named: 'partnerStatus'),
        )).thenAnswer((_) async => (
          bytes: Uint8List.fromList(utf8.encode('файл')),
          fileName: fileName,
        ));
  }

  Future<void> openSheet(
    WidgetTester tester, {
    String? search,
    String? status,
    int? visibleCount,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showClientExportSheet(
              context,
              search: search,
              status: status,
              visibleCount: visibleCount,
              api: api,
              downloader: downloader,
            ),
            child: const Text('открыть'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();
  }

  // ── Содержимое листа ───────────────────────────────────────────────────────

  testWidgets('Показывает все четыре формата', (tester) async {
    await openSheet(tester);

    expect(find.text('СКАЧАТЬ СПИСОК КЛИЕНТОВ'), findsOneWidget);
    for (final label in ['Excel', 'Word', 'PDF', 'CSV']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('В углу видно, куда сохранится файл', (tester) async {
    await openSheet(tester);

    expect(find.text('СОХРАНИТСЯ В'), findsOneWidget);
    expect(find.text('Загрузки'), findsOneWidget);
  });

  testWidgets('Без фильтров обещает выгрузить всё доступное', (tester) async {
    await openSheet(tester, visibleCount: 42);
    expect(find.textContaining('все доступные вам клиенты — 42 шт.'), findsOneWidget);
  });

  testWidgets('С поиском предупреждает, что выгрузка по фильтру', (tester) async {
    await openSheet(tester, search: 'Ромашка', visibleCount: 1);
    expect(find.textContaining('по текущему фильтру — 1 шт.'), findsOneWidget);
  });

  testWidgets('Последний формат не уезжает под навигацию Android', (tester) async {
    // Экран с системной навигацией снизу, как на Android.
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3;
    tester.view.viewPadding = const FakeViewPadding(bottom: 48, top: 72);
    tester.view.padding = const FakeViewPadding(bottom: 48, top: 72);
    addTearDown(tester.view.reset);

    await openSheet(tester);

    // CSV — последний в списке, он должен быть виден целиком.
    final csv = find.text('CSV');
    expect(csv, findsOneWidget);
    final box = tester.getRect(csv);
    final safeBottom = tester.view.physicalSize.height / tester.view.devicePixelRatio - 48;
    expect(box.bottom, lessThan(safeBottom), reason: 'CSV перекрыт системной навигацией');
  });

  // ── Скачивание ─────────────────────────────────────────────────────────────

  testWidgets('Выбор формата отправляет его на сервер', (tester) async {
    stubExport();
    await openSheet(tester, search: 'Ромашка');

    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();

    verify(() => api.exportClients(
          format: 'pdf',
          search: 'Ромашка',
          status: null,
          partnerStatus: null,
        )).called(1);
  });

  testWidgets('Фильтр по статусу уходит в запрос', (tester) async {
    stubExport();
    await openSheet(tester, status: 'active');

    await tester.tap(find.text('Excel'));
    await tester.pumpAndSettle();

    verify(() => api.exportClients(
          format: 'xlsx',
          search: null,
          status: 'active',
          partnerStatus: null,
        )).called(1);
  });

  testWidgets('Файл сохраняется без меню «Поделиться»', (tester) async {
    stubExport();
    await openSheet(tester);

    await tester.tap(find.text('Excel'));
    await tester.pumpAndSettle();

    verify(() => downloader.save(
          fileName: 'autoterra-clients-2026-07-30.xlsx',
          bytes: any(named: 'bytes'),
          format: 'xlsx',
        )).called(1);
    // Лист остаётся открытым — показывает результат, а не закрывается в шаринг.
    expect(find.text('СКАЧАТЬ СПИСОК КЛИЕНТОВ'), findsOneWidget);
  });

  // ── Индикаторы ─────────────────────────────────────────────────────────────

  testWidgets('Пока файл готовится, показывается прогресс', (tester) async {
    final pending = Completer<({Uint8List bytes, String fileName})>();
    when(() => api.exportClients(
          format: any(named: 'format'),
          search: any(named: 'search'),
          status: any(named: 'status'),
          partnerStatus: any(named: 'partnerStatus'),
        )).thenAnswer((_) => pending.future);

    await openSheet(tester);
    await tester.tap(find.text('PDF'));
    await tester.pump();

    expect(find.text('Скачиваем…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete((bytes: Uint8List(0), fileName: 'x.pdf'));
    await tester.pumpAndSettle();
  });

  testWidgets('После скачивания видно «Скачано» и путь', (tester) async {
    stubExport();
    await openSheet(tester);

    await tester.tap(find.text('Word'));
    await tester.pumpAndSettle();

    expect(find.text('Скачано'), findsOneWidget);
    expect(find.textContaining('Загрузки/autoterra-clients'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    // Отправить можно, но это отдельное действие.
    expect(find.text('ОТПРАВИТЬ'), findsOneWidget);
  });

  testWidgets('Остальные форматы остаются доступны после скачивания', (tester) async {
    stubExport();
    await openSheet(tester);

    await tester.tap(find.text('Excel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();

    expect(find.text('Скачано'), findsNWidgets(2));
  });

  // ── Ошибки ─────────────────────────────────────────────────────────────────

  testWidgets('Ошибка сервера показывается на самом формате', (tester) async {
    when(() => api.exportClients(
          format: any(named: 'format'),
          search: any(named: 'search'),
          status: any(named: 'status'),
          partnerStatus: any(named: 'partnerStatus'),
        )).thenThrow(const ApiException('PDF на сервере не собирается: нет reportlab'));

    await openSheet(tester);
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();

    expect(find.text('PDF на сервере не собирается: нет reportlab'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    // Остальные форматы не заблокированы.
    expect(find.text('Excel'), findsOneWidget);
  });

  testWidgets('Неудачную загрузку можно повторить', (tester) async {
    var attempts = 0;
    when(() => api.exportClients(
          format: any(named: 'format'),
          search: any(named: 'search'),
          status: any(named: 'status'),
          partnerStatus: any(named: 'partnerStatus'),
        )).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw const ApiException('Сеть недоступна');
      return (bytes: Uint8List(0), fileName: 'retry.csv');
    });

    await openSheet(tester);
    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();
    expect(find.text('Сеть недоступна'), findsOneWidget);

    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();

    expect(find.text('Скачано'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('Ошибка сохранения на диск тоже видна', (tester) async {
    stubExport();
    when(() => downloader.save(
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
          format: any(named: 'format'),
        )).thenThrow(Exception('Нет места на устройстве'));

    await openSheet(tester);
    await tester.tap(find.text('Excel'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Нет места на устройстве'), findsOneWidget);
  });
}
