import 'dart:convert';
import 'package:autoterra/core/theme.dart';
import 'package:autoterra/screens/expert/knowledge_documents_panel.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/knowledge_upload_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUpAll(
    () => dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api/'),
  );

  test(
    'batch continues after failure and streams files sequentially',
    () async {
      final names = <String>[];
      var active = 0;
      var maximum = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          active++;
          if (active > maximum) maximum = active;
          expect(
            request.headers['content-type'],
            contains('multipart/form-data'),
          );
          final body = request.body;
          expect(body.toLowerCase(), contains('content-type: text/plain'));
          final bad = body.contains('bad.txt');
          names.add(bad ? 'bad.txt' : 'good.txt');
          await Future<void>.delayed(const Duration(milliseconds: 1));
          active--;
          return bad
              ? jsonResponse({'detail': 'Файл повреждён'}, 400)
              : jsonResponse({
                  'document': {'id': '2', 'status': 'processing'},
                }, 201);
        }),
      );
      final outcomes = <Object?>[];
      final progress = <double>[];
      await uploadKnowledgeBatch(
        api,
        [
          KnowledgeUpload(
            name: 'bad.txt',
            size: 4,
            open: () => Stream.value(utf8.encode('bad!')),
          ),
          KnowledgeUpload(
            name: 'good.txt',
            size: 4,
            open: () => Stream.value(utf8.encode('good')),
          ),
        ],
        onProgress: (_, value) => progress.add(value),
        onResult: (_, error) => outcomes.add(error),
      );
      expect(names, ['bad.txt', 'good.txt']);
      expect(maximum, 1);
      expect(outcomes.first, isA<ApiException>());
      expect(outcomes.last, isNull);
      expect(progress.where((p) => p == 1).length, 2);
    },
  );

  test(
    'oversized file is rejected without reading, next file uploads',
    () async {
      var requests = 0;
      final api = ApiClient(
        client: MockClient((_) async {
          requests++;
          return jsonResponse({
            'document': {'id': '1'},
          }, 201);
        }),
      );
      final outcomes = <Object?>[];
      await uploadKnowledgeBatch(
        api,
        [
          KnowledgeUpload(
            name: 'large.pdf',
            size: 26 * 1024 * 1024,
            open: () => throw StateError('must not read'),
          ),
          KnowledgeUpload(
            name: 'small.txt',
            size: 1,
            open: () => Stream.value([65]),
          ),
        ],
        onProgress: (_, _) {},
        onResult: (_, error) => outcomes.add(error),
      );
      expect(requests, 1);
      expect(outcomes.first, isA<ArgumentError>());
      expect(outcomes.last, isNull);
    },
  );

  test('chat preserves sources and legacy aiChat returns answer', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => jsonResponse({
          'answer': '20 градусов',
          'sources': [
            {'filename': 'manual.pdf', 'page': 2},
          ],
          'suggestEscalation': false,
        }),
      ),
    );
    final result = await api.aiChatWithSources('температура');
    expect((result['sources'] as List).first['page'], 2);
    expect(await api.aiChat('температура'), '20 градусов');
  });

  testWidgets('document panel displays statuses, error, retry and deletion', (
    tester,
  ) async {
    var deleted = false;
    var retried = false;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'DELETE') {
          deleted = true;
          return jsonResponse({'deleted': true});
        }
        if (request.method == 'POST') {
          retried = true;
          return jsonResponse({
            'document': {'id': '1'},
          }, 202);
        }
        final rows = [
          if (!deleted)
            {
              'id': '1',
              'title': 'manual.pdf',
              'size': 1024,
              'status': 'failed',
              'createdAt': '2026-10-13T10:00:00Z',
              'error': 'Требуется OCR',
            },
          {
            'id': '2',
            'title': 'ready.txt',
            'size': 2048,
            'status': 'ready',
            'createdAt': '2026-10-13T10:00:00Z',
            'error': '',
          },
        ];
        return jsonResponse({'results': rows});
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: KnowledgeDocumentsPanel(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Добавить файлы'), findsOneWidget);
    expect(find.text('Ошибка'), findsOneWidget);
    expect(find.text('Готов'), findsOneWidget);
    expect(find.text('Требуется OCR'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(retried, isTrue);
    await tester.tap(find.byTooltip('Удалить документ').first);
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
    expect(find.text('manual.pdf'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
