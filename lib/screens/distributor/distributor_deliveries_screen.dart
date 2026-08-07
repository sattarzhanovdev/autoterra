import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/delivery/assign_courier_sheet.dart';
import '../../widgets/common/brand_icon.dart';

class DistributorDeliveriesScreen extends StatefulWidget {
  const DistributorDeliveriesScreen({super.key});

  @override
  State<DistributorDeliveriesScreen> createState() => _DistributorDeliveriesScreenState();
}

class _DistributorDeliveriesScreenState extends State<DistributorDeliveriesScreen> {
  late final PaginationController<CourierTask> _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<CourierTask>(
      fetchPage: (page) => DataRepository().distributorDeliveryTasks(page: page),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() => _controller.refresh();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ДОСТАВКИ')),
      body: PaginatedListView<CourierTask>(
        controller: _controller,
        separator: const SizedBox(height: 8),
        emptyBuilder: Column(
          children: const [
            PremiumIconBadge(
              icon: Icons.local_shipping_outlined,
              size: 56,
              iconSize: 28,
            ),
            SizedBox(height: 16),
            Text(
              'Нет заявок на доставку',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        itemBuilder: (context, task, _) =>
            _DeliveryCard(task: task, onUpdate: _load),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card
// ─────────────────────────────────────────────────────────────────────────────
class _DeliveryCard extends StatelessWidget {
  final CourierTask task;
  final VoidCallback onUpdate;
  const _DeliveryCard({required this.task, required this.onUpdate});

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveryDetailSheet(task: task, onUpdate: onUpdate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const PremiumIconBadge(icon: Icons.local_shipping_outlined, size: 36, iconSize: 18, iconColor: AppColors.info),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.typeDisplay.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  Text(
                    task.clientName.toUpperCase(),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge.fromCourierStatus(task.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delivery task detail sheet
// ─────────────────────────────────────────────────────────────────────────────
class _DeliveryDetailSheet extends StatelessWidget {
  final CourierTask task;
  final VoidCallback onUpdate;
  const _DeliveryDetailSheet({required this.task, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isNew = task.status == CourierTaskStatus.created;

    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PremiumIconBadge(icon: Icons.local_shipping_outlined, size: 40, iconSize: 20, iconColor: AppColors.info),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.typeDisplay.toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    StatusBadge.fromCourierStatus(task.status),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(height: 24),
          _DetailRow(icon: BrandIcons.person, label: 'Клиент', value: task.clientName),
          if (task.contactName != null)
            _DetailRow(icon: Icons.badge_outlined, label: 'Контакт', value: task.contactName!),
          if (task.contactPhone != null)
            _DetailRow(icon: Icons.phone_outlined, label: 'Телефон', value: task.contactPhone!),
          _DetailRow(icon: BrandIcons.location, label: 'Адрес', value: task.address),
          if (task.timeSlot.isNotEmpty)
            _DetailRow(icon: Icons.schedule_outlined, label: 'Время', value: task.timeSlot),
          if (task.courierName != null)
            _DetailRow(icon: Icons.delivery_dining_outlined, label: 'Курьер', value: task.courierName!),
          if (task.comment != null && task.comment!.isNotEmpty)
            _DetailRow(icon: Icons.comment_outlined, label: 'Комментарий', value: task.comment!),
          if (task.courierComment != null && task.courierComment!.isNotEmpty)
            _DetailRow(icon: Icons.chat_bubble_outline, label: 'Отчёт курьера', value: task.courierComment!),
          if (isNew) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleCancel(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('ОТМЕНИТЬ', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleAssign(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                    child: const Text('НАЗНАЧИТЬ КУРЬЕРА', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить заявку?'),
        content: const Text('Заявка на доставку будет аннулирована.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('НЕТ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('ОТМЕНИТЬ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DataRepository().updateDeliveryStatus(task.id, status: 'cancelled');
      onUpdate();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _handleAssign(BuildContext context) async {
    final assigned = await showAssignCourierSheet(context, task);
    if (assigned == true) onUpdate();
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
