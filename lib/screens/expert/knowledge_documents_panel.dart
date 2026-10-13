import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';
import '../../services/knowledge_upload_queue.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';

class KnowledgeDocumentsPanel extends StatefulWidget {
  final ApiClient? api;
  const KnowledgeDocumentsPanel({super.key, this.api});

  @override
  State<KnowledgeDocumentsPanel> createState() =>
      _KnowledgeDocumentsPanelState();
}

class _KnowledgeDocumentsPanelState extends State<KnowledgeDocumentsPanel> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final PaginationController<Map<String, dynamic>> _controller;
  Timer? _poll;
  bool _uploading = false;
  bool _polling = false;
  String _current = '';
  double _progress = 0;
  final List<String> _results = [];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _controller = PaginationController(
      fetchPage: (page) => _api.knowledgeDocuments(page: page),
    );
    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_polling) return;
      _polling = true;
      try {
        for (final row in List<Map<String, dynamic>>.of(_controller.items)) {
          if (!mounted) return;
          if (row['status'] != 'processing') continue;
          try {
            final result = await _api.knowledgeDocument(row['id'] as String);
            if (!mounted) return;
            _controller.replaceWhere(
              (item) => item['id'] == row['id'],
              result['document'] as Map<String, dynamic>,
            );
          } catch (_) {
            /* Manual refresh shows network errors. */
          }
        }
      } finally {
        _polling = false;
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _uploading = true;
      _results.clear();
    });
    try {
      final selected = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt'],
        withData: false,
        withReadStream: true,
      );
      if (selected == null || !mounted) return;
      final files = selected.files
          .map(
            (f) => KnowledgeUpload(
              name: f.name,
              size: f.size,
              open: () {
                if (f.readStream != null) return f.readStream!;
                if (f.bytes != null) return Stream.value(f.bytes!);
                throw StateError('Не удалось прочитать файл');
              },
            ),
          )
          .toList();
      await uploadKnowledgeBatch(
        _api,
        files,
        cancelled: () => !mounted,
        onProgress: (index, value) {
          if (mounted) {
            setState(() {
              _current = '${index + 1}/${files.length}: ${files[index].name}';
              _progress = value;
            });
          }
        },
        onResult: (index, error) {
          if (mounted) {
            setState(
              () => _results.add(
                '${files[index].name}: ${error == null ? "Загружен" : "Ошибка: $error"}',
              ),
            );
          }
        },
      );
      if (mounted) await _controller.refresh();
    } catch (error) {
      if (mounted) setState(() => _results.add('Ошибка выбора файлов: $error'));
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _current = '';
        });
      }
    }
  }

  Future<void> _action(Map<String, dynamic> doc, bool retry) async {
    final id = doc['id'] as String;
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      if (retry) {
        await _api.reprocessKnowledgeDocument(id);
      } else {
        await _api.deleteKnowledgeDocument(id);
        _controller.removeWhere((item) => item['id'] == id);
      }
      if (mounted) await _controller.refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _uploading ? null : _pick,
                icon: const Icon(Icons.upload_file),
                label: const Text('Добавить файлы'),
              ),
            ),
            IconButton(
              onPressed: _controller.refresh,
              tooltip: 'Обновить список',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      const Text('PDF, DOCX, TXT · до 25 МБ на файл'),
      if (_uploading)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(_current.isEmpty ? 'Выбор файлов…' : _current),
              LinearProgressIndicator(
                value: _current.isEmpty ? null : _progress,
              ),
              if (_progress >= 1) const Text('Ожидание подтверждения сервера…'),
            ],
          ),
        ),
      if (_results.isNotEmpty)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 130),
          child: ListView(
            shrinkWrap: true,
            children: _results
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    child: Text(r),
                  ),
                )
                .toList(),
          ),
        ),
      Expanded(
        child: PaginatedListView<Map<String, dynamic>>(
          controller: _controller,
          emptyMessage: 'Документы ещё не загружены',
          itemBuilder: (context, doc, _) {
            final status = switch (doc['status']) {
              'ready' => 'Готов',
              'failed' => 'Ошибка',
              _ => 'Обрабатывается',
            };
            final date = DateTime.tryParse(doc['createdAt'] as String? ?? '');
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['title'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${((doc['size'] as num) / 1024 / 1024).toStringAsFixed(2)} МБ · ${date == null ? "" : DateFormat("dd.MM.yyyy HH:mm").format(date.toLocal())}',
                    ),
                    Text(status),
                    if ((doc['error'] as String? ?? '').isNotEmpty)
                      Text(
                        doc['error'] as String,
                        style: const TextStyle(color: Colors.red),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (doc['status'] == 'failed')
                          TextButton(
                            onPressed: _busy.contains(doc['id'])
                                ? null
                                : () => _action(doc, true),
                            child: const Text('Повторить'),
                          ),
                        IconButton(
                          tooltip: 'Удалить документ',
                          onPressed: _busy.contains(doc['id'])
                              ? null
                              : () => _action(doc, false),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
