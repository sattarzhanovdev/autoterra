import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/premium_icon_badge.dart';

/// Обучающие материалы (п. 10 ТЗ): уроки, чек-листы, видео, инструкции и
/// записи вебинаров. Клиент их только читает — ведутся они из админки.
class LearningMaterialsScreen extends StatefulWidget {
  const LearningMaterialsScreen({super.key});

  @override
  State<LearningMaterialsScreen> createState() => _LearningMaterialsScreenState();
}

class _LearningMaterialsScreenState extends State<LearningMaterialsScreen> {
  late PaginationController<LearningMaterial> _controller;

  /// Пусто — показываем все типы.
  String _kind = '';

  static const _kinds = <String, String>{
    '': 'ВСЕ',
    'lesson': 'УРОКИ',
    'video': 'ВИДЕО',
    'checklist': 'ЧЕК-ЛИСТЫ',
    'manual': 'ИНСТРУКЦИИ',
    'webinar': 'ВЕБИНАРЫ',
  };

  @override
  void initState() {
    super.initState();
    _controller = _build();
  }

  PaginationController<LearningMaterial> _build() {
    return PaginationController<LearningMaterial>(
      fetchPage: (page) => DataRepository().learningMaterials(
        page: page,
        kind: _kind.isEmpty ? null : _kind,
      ),
    );
  }

  void _selectKind(String kind) {
    if (kind == _kind) return;
    final previous = _controller;
    setState(() {
      _kind = kind;
      _controller = _build();
    });
    previous.dispose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ОБУЧЕНИЕ')),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: PaginatedListView<LearningMaterial>(
              controller: _controller,
              emptyMessage: 'МАТЕРИАЛОВ ПОКА НЕТ',
              itemBuilder: (context, material, _) => _MaterialCard(material: material),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: _kinds.entries.map((entry) {
          final active = entry.key == _kind;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _selectKind(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.brandBlack : Colors.white,
                  border: Border.all(
                    color: active ? AppColors.brandBlack : AppColors.border,
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final LearningMaterial material;
  const _MaterialCard({required this.material});

  IconData get _icon {
    switch (material.kind) {
      case 'video':
      case 'webinar':
        return Icons.play_circle_outline;
      case 'checklist':
        return Icons.checklist_rtl;
      case 'manual':
        return Icons.menu_book_outlined;
      default:
        return Icons.school_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumIconBadge(icon: _icon, size: 42, iconSize: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        material.kindLabel.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: AppColors.brandRed,
                        ),
                      ),
                      if (material.durationMinutes != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${material.durationMinutes} МИН',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    material.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  if (material.summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      material.summary,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      builder: (_) => _MaterialSheet(material: material),
    );
  }
}

class _MaterialSheet extends StatelessWidget {
  final LearningMaterial material;
  const _MaterialSheet({required this.material});

  Future<void> _launch(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('НЕ УДАЛОСЬ ОТКРЫТЬ ССЫЛКУ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            material.kindLabel.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: AppColors.brandRed,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            material.title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          if (material.category.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              material.category.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const Divider(height: 28),
          if (material.summary.isNotEmpty) ...[
            Text(
              material.summary,
              style: const TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
          ],
          if (material.body.isNotEmpty)
            Text(material.body, style: const TextStyle(fontSize: 13, height: 1.6)),
          if (material.videoUrl != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _launch(context, material.videoUrl!),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('СМОТРЕТЬ ВИДЕО'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  shape: const BeveledRectangleBorder(),
                ),
              ),
            ),
          ],
          if (material.fileUrl != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launch(context, material.fileUrl!),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('СКАЧАТЬ ФАЙЛ'),
                style: OutlinedButton.styleFrom(shape: const BeveledRectangleBorder()),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
