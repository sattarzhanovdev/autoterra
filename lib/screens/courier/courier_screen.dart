import '../clients/cash_payment_widgets.dart';
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

class _CourierTaskTile extends StatefulWidget {
  final CourierTask task;
  final VoidCallback onUpdate;

  const _CourierTaskTile({required this.task, required this.onUpdate});

  @override
  State<_CourierTaskTile> createState() => _CourierTaskTileState();
}

class _CourierTaskTileState extends State<_CourierTaskTile> {
  late CourierTask task;
  String? _pickingId;
  bool _statusBusy = false;

  @override
  void initState() {
    super.initState();
    task = widget.task;
  }

  @override
  void didUpdateWidget(covariant _CourierTaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task != widget.task) task = widget.task;
  }

  Future<void> _pick(CourierOrderItem item) async {
    if (_pickingId != null || item.picked) return;
    setState(() => _pickingId = item.id);
    try {
      final updated = await DataRepository().courierPickItem(task.id, item.id);
      if (!mounted) return;
      setState(() => task = updated);
      widget.onUpdate();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сборки: $error')));
    } finally {
      if (mounted) setState(() => _pickingId = null);
    }
  }

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
          if (task.orderNumber != null) ...[
            const SizedBox(height: 4),
            Text('ЗАКАЗ № ${task.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(BrandIcons.location, size: 14, color: AppColors.textSecondary),
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
          CourierCashCollection(task: task, repository: DataRepository(), onChanged: (updated) { setState(() => task = updated); widget.onUpdate(); }),
          if (task.taskType == 'delivery' && task.orderId != null) ...[
            const Divider(height: 24),
            const Text('СБОРКА ЗАКАЗА', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            if (task.orderItems.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('В заказе нет позиций. Обратитесь к оператору.')),
            for (final item in task.orderItems)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text('Артикул: ${item.sku} · ${item.quantity} шт.'),
                trailing: item.picked
                    ? const Chip(label: Text('СОБРАНО'))
                    : OutlinedButton(
                        onPressed: task.status == CourierTaskStatus.assigned && _pickingId == null ? () => _pick(item) : null,
                        child: _pickingId == item.id
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('СОБРАНО'),
                      ),
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
                  onPressed: _statusBusy || (task.status == CourierTaskStatus.inProgress && task.paymentMethod == 'cash' && !task.cashCollected) || (task.status == CourierTaskStatus.assigned && task.orderId != null && !task.allItemsPicked)
                      ? null : () => _showStatusDialog(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(
                    task.status == CourierTaskStatus.assigned
                        ? (task.orderId != null ? 'ЗАБРАЛ ЗАКАЗ / В ПУТЬ' : 'ВЗЯТЬСЯ ЗА РАБОТУ')
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
        title: Text(isAssigned ? 'Забрали заказ и выезжаете?' : 'Завершить доставку?'),
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
              if (_statusBusy) return;
              setState(() => _statusBusy = true);
              try {
                final newStatus = isAssigned ? 'in_progress' : 'delivered';
                final updated = await DataRepository().updateCourierTaskStatus(task.id, status: newStatus);
                if (mounted) setState(() => task = updated);
                widget.onUpdate();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _statusBusy = false);
              }
            },
            child: const Text('ПОДТВЕРДИТЬ'),
          ),
        ],
      ),
    );
  }
}
