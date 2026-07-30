import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Куда лёг файл: путь для «Поделиться» и подпись для пользователя.
class SavedFile {
  /// Полный путь на диске. На Android при записи через MediaStore недоступен —
  /// система не отдаёт файловый путь, только запись в медиатеке.
  final String? path;

  /// Что показать человеку: «Загрузки/autoterra-clients-2026-07-30.xlsx».
  final String displayPath;

  const SavedFile({required this.displayPath, this.path});

  bool get canShare => path != null;
}

/// Сохраняет выгрузки в папку, куда пользователь ожидает — «Загрузки».
///
/// На Android это делается через MediaStore: с Android 10 писать в общие папки
/// напрямую нельзя, зато и разрешений спрашивать не нужно. На iOS системной
/// папки «Загрузки» нет, поэтому файл кладётся в документы приложения — они
/// видны в «Файлах».
class FileDownloadService {
  static const _channel = MethodChannel('autoterra/downloads');

  const FileDownloadService();

  static const _mimeTypes = {
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'pdf': 'application/pdf',
    'csv': 'text/csv',
  };

  /// Куда попадёт файл — можно показать до начала скачивания.
  String get destinationLabel {
    if (kIsWeb) return 'Папка загрузок браузера';
    if (Platform.isAndroid) return 'Загрузки';
    if (Platform.isIOS) return 'Файлы · AutoTerra';
    return 'Документы';
  }

  Future<SavedFile> save({
    required String fileName,
    required Uint8List bytes,
    required String format,
  }) async {
    if (kIsWeb) {
      throw const FileSystemException('Скачивание недоступно в веб-версии');
    }

    if (Platform.isAndroid) {
      final displayPath = await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'bytes': bytes,
        'mimeType': _mimeTypes[format] ?? 'application/octet-stream',
      });
      // MediaStore не отдаёт файловый путь — копию для «Поделиться» кладём
      // во временную папку приложения.
      final shareable = await _writeToTemp(fileName, bytes);
      return SavedFile(
        displayPath: displayPath ?? 'Загрузки/$fileName',
        path: shareable.path,
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = await File('${directory.path}/$fileName').writeAsBytes(bytes, flush: true);
    return SavedFile(displayPath: '$destinationLabel/$fileName', path: file.path);
  }

  Future<File> _writeToTemp(String fileName, Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    return File('${directory.path}/$fileName').writeAsBytes(bytes, flush: true);
  }
}
