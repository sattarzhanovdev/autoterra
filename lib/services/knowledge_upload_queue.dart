import 'api_client.dart';

class KnowledgeUpload {
  final String name;
  final int size;
  final Stream<List<int>> Function() open;
  KnowledgeUpload({required this.name, required this.size, required this.open});
}

/// Each file has an independent outcome; only one file is streamed at a time.
Future<void> uploadKnowledgeBatch(
  ApiClient api,
  List<KnowledgeUpload> files, {
  required void Function(int index, double progress) onProgress,
  required void Function(int index, Object? error) onResult,
  bool Function()? cancelled,
}) async {
  for (var i = 0; i < files.length; i++) {
    if (cancelled?.call() ?? false) break;
    final file = files[i];
    try {
      if (file.size > 25 * 1024 * 1024) {
        throw ArgumentError('Размер файла превышает 25 МБ');
      }
      onProgress(i, 0);
      await api.uploadKnowledgeDocument(
        file.open(),
        file.size,
        file.name,
        onProgress: (sent, total) =>
            onProgress(i, total == 0 ? 1 : sent / total),
      );
      onResult(i, null);
    } catch (error) {
      onResult(i, error);
    }
  }
}
