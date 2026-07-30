import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/delivery/assign_courier_sheet.dart';

class DistributorColorLabScreen extends StatefulWidget {
  /// Подменяется в тестах; в приложении создаётся сам.
  final DataRepository? repository;

  const DistributorColorLabScreen({super.key, this.repository});

  @override
  State<DistributorColorLabScreen> createState() => _DistributorColorLabScreenState();
}

// No SingleTickerProviderStateMixin — Historia tab removed entirely.
class _DistributorColorLabScreenState extends State<DistributorColorLabScreen> {
  late final DataRepository _repo;
  late final PaginationController<ColorRequest> _controller;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DataRepository();
    // Завершённые и отменённые заявки отсекает сервер — на клиенте фильтровать
    // страницу нельзя, она может целиком состоять из завершённых.
    _controller = PaginationController<ColorRequest>(
      fetchPage: (page) => _repo.distributorColorRequests(page: page, activeOnly: true),
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
      appBar: AppBar(title: const Text('COLOR LAB (ПОДБОР)')),
      body: PaginatedListView<ColorRequest>(
        controller: _controller,
        separator: const SizedBox(height: 12),
        emptyMessage: 'НЕТ АКТИВНЫХ ЗАЯВОК',
        itemBuilder: (context, request, _) =>
            _ColorLabCard(request: request, onUpdate: _load),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card
// ─────────────────────────────────────────────────────────────────────────────

class _ColorLabCard extends StatelessWidget {
  final ColorRequest request;
  final VoidCallback onUpdate;
  const _ColorLabCard({required this.request, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final status = request.status;

    // "Завершить подбор" — when color matching is still in progress.
    final canProcess = status == ColorRequestStatus.created ||
        status == ColorRequestStatus.pickedUp ||
        status == ColorRequestStatus.inProgress;

    // Курьер участвует только в ЗАБОРЕ лючка. Готовую краску и лючок маляр
    // забирает сам: оттенок сверяют на месте и нередко сразу отдают в
    // переделку, объясняя колористу, что не так. Поэтому кнопки назначения
    // курьера на возврат здесь больше нет.
    //
    // "Назначить курьера за лючком" — pickup leg: client asked for courier
    // pickup but nobody has been assigned yet to collect the sample.
    CourierTask? pickupTask;
    for (final t in request.courierTasks) {
      if (t.taskType == 'color_lab_pickup') {
        pickupTask = t;
        break;
      }
    }
    final needsPickupCourier = pickupTask != null && pickupTask.status == CourierTaskStatus.created;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────────
          Row(
            children: [
              const PremiumIconBadge(
                icon: Icons.colorize_outlined,
                size: 36,
                iconSize: 18,
                iconColor: AppColors.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.carBrand} ${request.carModel}'.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    Text(
                      'Код: ${request.colorCode} · ${request.clientName ?? "Клиент"}'.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge.fromColorStatus(status),
            ],
          ),

          // ── Urgent badge ───────────────────────────────────────────────────
          if (request.urgent) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: AppColors.brandRed,
              child: const Text(
                '⚡ СРОЧНАЯ ЗАЯВКА',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ],

          // ── All client-filled details ──────────────────────────────────────
          const Divider(height: 24, thickness: 0.5),
          if (request.colorName.isNotEmpty)
            _DetailRow(icon: Icons.color_lens_outlined, label: 'Цвет', value: request.colorName),
          if (request.vin.isNotEmpty)
            _DetailRow(icon: Icons.tag_outlined, label: 'VIN/Госномер', value: request.vin),
          if (request.carYear.isNotEmpty)
            _DetailRow(icon: Icons.event_outlined, label: 'Год', value: request.carYear),
          _DetailRow(
            icon: Icons.local_shipping_outlined,
            label: 'Передача',
            value: request.transferMethod == 'self_delivery' ? 'Сам привезу' : 'Курьер',
          ),
          if (request.pickupAddress != null && request.pickupAddress!.isNotEmpty)
            _DetailRow(icon: Icons.location_on_outlined, label: 'Адрес забора', value: request.pickupAddress!),
          if (request.pickupTime != null)
            _DetailRow(
              icon: Icons.schedule_outlined,
              label: 'Время забора',
              value: DateFormat('dd.MM HH:mm').format(request.pickupTime!),
            ),
          // Дедлайн приезда курьера — курьеру и колористу нужно понимать,
          // до какого часа маляр вообще на месте.
          if (request.courierArriveUntil != null && request.transferMethod != 'self_delivery')
            _DetailRow(
              icon: Icons.timer_outlined,
              label: 'Забрать до',
              value: request.courierArriveUntil!,
              highlight: true,
            ),
          if (request.contactPerson != null && request.contactPerson!.isNotEmpty)
            _DetailRow(icon: Icons.person_outline, label: 'Контакт', value: request.contactPerson!),
          if (request.contactPhone != null && request.contactPhone!.isNotEmpty)
            _DetailRow(icon: Icons.phone_outlined, label: 'Телефон', value: request.contactPhone!),
          if (request.comment != null && request.comment!.isNotEmpty)
            _DetailRow(icon: Icons.comment_outlined, label: 'Комментарий', value: request.comment!),

          // ── Recipe preview ────────────────────────────────────────────────
          if (request.recipe != null && request.recipe!.isNotEmpty) ...[
            const Divider(height: 24, thickness: 0.5),
            Row(
              children: [
                const Icon(Icons.science_outlined, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                const Text(
                  'РЕЦЕПТ:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              request.recipe!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // ── Action: assign courier to pick up the sample from the client ────
          if (needsPickupCourier) ...[
            const Divider(height: 24, thickness: 0.5),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _assignCourierToTask(context, pickupTask!),
                icon: const Icon(Icons.delivery_dining_outlined, size: 16),
                label: const Text(
                  'НАЗНАЧИТЬ КУРЬЕРА ЗА ЛЮЧКОМ',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],

          // ── Action: complete colour matching ───────────────────────────────
          if (canProcess) ...[
            const Divider(height: 24, thickness: 0.5),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showCompleteSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlack,
                  minimumSize: const Size(0, 34),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'ЗАВЕРШИТЬ ПОДБОР',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],

          // ── Готовое забирает клиент ───────────────────────────────────────
          if (status == ColorRequestStatus.ready) ...[
            const Divider(height: 24, thickness: 0.5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: AppColors.brandBlack.withValues(alpha: 0.06),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.storefront_outlined, size: 14, color: AppColors.brandBlack),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Клиент забирает готовую краску и лючок сам — оттенок проверяют на месте.',
                      style: TextStyle(fontSize: 11, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Забор лючка назначается через общий шит (→ updateDeliveryStatus), поэтому
  // экран «Доставка» и Color Lab всегда показывают одну и ту же задачу.
  Future<void> _assignCourierToTask(BuildContext context, CourierTask task) async {
    final assigned = await showAssignCourierSheet(context, task);
    if (assigned == true) onUpdate();
  }

  void _showCompleteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompleteSheet(request: request, onUpdate: onUpdate),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Complete colour-matching sheet (existing, unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _CompleteSheet extends StatefulWidget {
  final ColorRequest request;
  final VoidCallback onUpdate;
  const _CompleteSheet({required this.request, required this.onUpdate});

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  final _recipeCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _recipeCtrl.text = widget.request.recipe ?? '';
  }

  @override
  void dispose() {
    _recipeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_recipeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Введите формулу/рецепт')));
      return;
    }
    setState(() => _saving = true);
    try {
      await DataRepository().distributorUpdateColorRequest(widget.request.id, {
        'status': 'ready',
        'recipe': _recipeCtrl.text.trim(),
      });
      if (mounted) {
        widget.onUpdate();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Подбор завершен, клиент уведомлен'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ЗАВЕРШЕНИЕ ПОДБОРА',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.request.carBrand} ${widget.request.carModel} · ${widget.request.colorCode}'
                .toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          if (widget.request.clientName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Клиент: ${widget.request.clientName}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _recipeCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'РЕЦЕПТ / ФОРМУЛА КРАСКИ',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'ГОТОВО (УВЕДОМИТЬ КЛИЕНТА)',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card detail row (client-filled fields) ────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// Выделяет строку красным — для дедлайнов, которые нельзя проглядеть.
  final bool highlight;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: highlight ? AppColors.brandRed : AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
                color: highlight ? AppColors.brandRed : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

