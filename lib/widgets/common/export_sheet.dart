import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/file_download_service.dart';

/// Формат выгрузки: что показать в списке и как назвать файл.
class ExportFormat {
  final String code;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;

  const ExportFormat({
    required this.code,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
  });
}

const kExportFormats = <ExportFormat>[
  ExportFormat(
    code: 'xlsx',
    label: 'Excel',
    hint: 'Таблица с фильтрами — для работы с данными',
    icon: Icons.table_chart_outlined,
    color: Color(0xFF1D6F42),
  ),
  ExportFormat(
    code: 'docx',
    label: 'Word',
    hint: 'Документ с таблицей — для печати и отправки',
    icon: Icons.description_outlined,
    color: Color(0xFF2B579A),
  ),
  ExportFormat(
    code: 'pdf',
    label: 'PDF',
    hint: 'Готов к печати, открывается везде',
    icon: Icons.picture_as_pdf_outlined,
    color: Color(0xFFB30B00),
  ),
  ExportFormat(
    code: 'csv',
    label: 'CSV',
    hint: 'Для загрузки в 1С и другие системы',
    icon: Icons.list_alt_outlined,
    color: Color(0xFF555555),
  ),
];

/// Состояние загрузки одного формата.
enum _Stage { idle, loading, done, failed }

/// Показывает выбор формата и скачивает список клиентов в файл.
///
/// Что попадёт в файл, решает сервер по роли: дистрибьютору — его клиенты,
/// менеджеру региона — его регионы, главному менеджеру — все. [search] и
/// [status] передаются как есть, чтобы выгрузка совпала с тем, что человек
/// видит на экране.
Future<void> showClientExportSheet(
  BuildContext context, {
  String? search,
  String? status,
  String? partnerStatus,
  int? visibleCount,
  ApiClient? api,
  FileDownloadService? downloader,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ClientExportSheet(
      search: search,
      status: status,
      partnerStatus: partnerStatus,
      visibleCount: visibleCount,
      api: api ?? ApiClient(),
      downloader: downloader ?? const FileDownloadService(),
    ),
  );
}

class _ClientExportSheet extends StatefulWidget {
  final String? search;
  final String? status;
  final String? partnerStatus;
  final int? visibleCount;
  final ApiClient api;
  final FileDownloadService downloader;

  const _ClientExportSheet({
    this.search,
    this.status,
    this.partnerStatus,
    this.visibleCount,
    required this.api,
    required this.downloader,
  });

  @override
  State<_ClientExportSheet> createState() => _ClientExportSheetState();
}

class _ClientExportSheetState extends State<_ClientExportSheet> {
  final Map<String, _Stage> _stages = {};
  final Map<String, SavedFile> _saved = {};
  final Map<String, String> _errors = {};

  bool get _busy => _stages.values.contains(_Stage.loading);

  bool get _hasFilters =>
      (widget.search?.isNotEmpty ?? false) ||
      (widget.status?.isNotEmpty ?? false) ||
      (widget.partnerStatus?.isNotEmpty ?? false);

  Future<void> _download(ExportFormat format) async {
    setState(() {
      _stages[format.code] = _Stage.loading;
      _errors.remove(format.code);
    });

    try {
      final result = await widget.api.exportClients(
        format: format.code,
        search: widget.search,
        status: widget.status,
        partnerStatus: widget.partnerStatus,
      );
      final saved = await widget.downloader.save(
        fileName: result.fileName,
        bytes: result.bytes,
        format: format.code,
      );

      if (!mounted) return;
      setState(() {
        _stages[format.code] = _Stage.done;
        _saved[format.code] = saved;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stages[format.code] = _Stage.failed;
        _errors[format.code] = '$e'
            .replaceFirst('ApiException: ', '')
            .replaceFirst('FileSystemException: ', '')
            .replaceFirst('PlatformException(save_failed, ', '')
            .replaceFirst(RegExp(r', null, null\)$'), '');
      });
    }
  }

  Future<void> _share(String code) async {
    final saved = _saved[code];
    if (saved?.path == null) return;
    await Share.shareXFiles(
      [XFile(saved!.path!)],
      subject: 'Список клиентов AutoTerra',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Отступ снизу — под системную навигацию Android, иначе последний формат
    // уезжает под кнопки. useSafeArea прикрывает только верх.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // Лист не должен занимать весь экран: список под ним остаётся виден.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _header(),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
              children: [
                for (final format in kExportFormats) ...[
                  _FormatTile(
                    format: format,
                    stage: _stages[format.code] ?? _Stage.idle,
                    saved: _saved[format.code],
                    error: _errors[format.code],
                    enabled: !_busy,
                    onDownload: () => _download(format),
                    onShare: () => _share(format.code),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'СКАЧАТЬ СПИСОК КЛИЕНТОВ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Text(
                _subtitle(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Куда сохранится файл — видно до начала скачивания.
        _DestinationBadge(label: widget.downloader.destinationLabel),
      ],
    );
  }

  String _subtitle() {
    final count = widget.visibleCount;
    if (_hasFilters) {
      return count == null
          ? 'Выгрузятся клиенты по текущему фильтру.'
          : 'Выгрузятся клиенты по текущему фильтру — $count шт.';
    }
    return count == null
        ? 'Выгрузятся все доступные вам клиенты.'
        : 'Выгрузятся все доступные вам клиенты — $count шт.';
  }
}

/// Плашка «куда сохранится» в правом верхнем углу листа.
class _DestinationBadge extends StatelessWidget {
  final String label;

  const _DestinationBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandBlack.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'СОХРАНИТСЯ В',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.folder_outlined, size: 12, color: AppColors.brandBlack),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final ExportFormat format;
  final _Stage stage;
  final SavedFile? saved;
  final String? error;
  final bool enabled;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  const _FormatTile({
    required this.format,
    required this.stage,
    required this.saved,
    required this.error,
    required this.enabled,
    required this.onDownload,
    required this.onShare,
  });

  bool get _tappable => enabled || stage == _Stage.done || stage == _Stage.failed;

  @override
  Widget build(BuildContext context) {
    final done = stage == _Stage.done;
    final failed = stage == _Stage.failed;

    return Opacity(
      opacity: _tappable ? 1 : 0.4,
      child: Material(
        color: done ? AppColors.success.withValues(alpha: 0.05) : Colors.white,
        child: InkWell(
          onTap: _tappable ? onDownload : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: done
                    ? AppColors.success
                    : failed
                        ? AppColors.error
                        : AppColors.border,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _leading(),
                    const SizedBox(width: 12),
                    Expanded(child: _title()),
                    _trailing(),
                  ],
                ),
                if (done && saved != null) ...[
                  const SizedBox(height: 10),
                  _savedRow(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading() {
    if (stage == _Stage.loading) {
      return Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        color: format.color.withValues(alpha: 0.12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: format.color),
        ),
      );
    }
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      color: format.color.withValues(alpha: 0.12),
      child: Icon(format.icon, size: 18, color: format.color),
    );
  }

  Widget _title() {
    final subtitle = switch (stage) {
      _Stage.loading => 'Скачиваем…',
      _Stage.done => 'Скачано',
      _Stage.failed => error ?? 'Не удалось скачать',
      _Stage.idle => format.hint,
    };
    final subtitleColor = switch (stage) {
      _Stage.done => AppColors.success,
      _Stage.failed => AppColors.error,
      _ => AppColors.textSecondary,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          format.label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: subtitleColor,
            fontWeight: stage == _Stage.idle ? FontWeight.normal : FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Индикатор состояния: скачано / ошибка / готово к скачиванию.
  Widget _trailing() {
    return switch (stage) {
      _Stage.loading => const SizedBox(width: 18),
      _Stage.done => Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 14, color: Colors.white),
        ),
      _Stage.failed => const Icon(Icons.refresh, size: 18, color: AppColors.error),
      _Stage.idle => const Icon(Icons.download_outlined, size: 18, color: AppColors.textSecondary),
    };
  }

  Widget _savedRow() {
    return Row(
      children: [
        const Icon(Icons.folder_open_outlined, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            saved!.displayPath,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (saved!.canShare)
          TextButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined, size: 14),
            label: const Text('ОТПРАВИТЬ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }
}
