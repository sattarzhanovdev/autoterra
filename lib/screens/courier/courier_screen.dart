import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/brand_icon.dart';

class CourierScreen extends StatefulWidget {
  const CourierScreen({super.key});

  @override
  State<CourierScreen> createState() => _CourierScreenState();
}

class _CourierScreenState extends State<CourierScreen> {
  final DataRepository _repo = DataRepository();
  late final PaginationController<CourierTask> _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<CourierTask>(
      fetchPage: (page) => _repo.courierMyTasks(page: page),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _controller.refresh();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Маршрут курьера'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: PaginatedListView<CourierTask>(
        controller: _controller,
        emptyMessage: 'ЗАДАЧ ПОКА НЕТ',
        itemBuilder: (context, task, _) => _CourierTaskTile(
          task: task,
          onUpdate: _refresh,
        ),
      ),
    );
  }
}

class _CourierTaskTile extends StatelessWidget {
  final CourierTask task;
  final VoidCallback onUpdate;

  const _CourierTaskTile({required this.task, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _typeBadge(task.taskType, task.typeDisplay),
              _statusBadge(task.status, task.statusDisplay),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.clientName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const BrandIcon(BrandIcons.location, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.address,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                task.timeSlot,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          if (task.contactPhone != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  task.contactPhone!,
                  style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  task.comment ?? 'Без комментария',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (task.status == CourierTaskStatus.assigned || task.status == CourierTaskStatus.inProgress)
                ElevatedButton(
                  onPressed: () => _showStatusDialog(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(
                    task.status == CourierTaskStatus.assigned
                        ? 'ВЗЯТЬСЯ ЗА РАБОТУ'
                        : 'ЗАВЕРШИТЬ ДОСТАВКУ',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String type, String display) {
    Color color;
    IconData icon;
    switch (type) {
      case 'pickup':
      case 'color_lab_pickup':
        color = AppColors.brandBlack;
        icon = Icons.file_download_outlined;
        break;
      case 'delivery':
        color = AppColors.brandRed;
        icon = Icons.local_shipping_outlined;
        break;
      case 'return':
        color = AppColors.textSecondary;
        icon = Icons.assignment_return_outlined;
        break;
      default:
        color = AppColors.textHint;
        icon = Icons.help_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            display.toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(CourierTaskStatus status, String display) {
    Color color;
    switch (status) {
      case CourierTaskStatus.assigned:
        color = AppColors.brandBlack;
        break;
      case CourierTaskStatus.inProgress:
        color = AppColors.brandRed;
        break;
      case CourierTaskStatus.delivered:
      case CourierTaskStatus.returned:
        color = AppColors.brandBlack;
        break;
      case CourierTaskStatus.cancelled:
        color = AppColors.brandRed;
        break;
      default:
        color = AppColors.textHint;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        display.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showStatusDialog(BuildContext context) {
    final isAssigned = task.status == CourierTaskStatus.assigned;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAssigned ? 'Взяться за работу?' : 'Завершить доставку?'),
        content: Text(isAssigned
          ? 'Клиент увидит статус «В пути» и ваш телефон для связи.'
          : 'Клиент увидит статус «Доставлено». Отменить это действие нельзя.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final newStatus = isAssigned ? 'in_progress' : 'delivered';
                await DataRepository().updateCourierTaskStatus(task.id, status: newStatus);
                onUpdate();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
            child: const Text('ПОДТВЕРДИТЬ'),
          ),
        ],
      ),
    );
  }
}
