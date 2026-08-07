import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/brand_icon.dart';

class DeliveryScreen extends StatefulWidget {
  /// Подменяется в тестах; в приложении создаётся сам.
  final DataRepository? repository;

  const DeliveryScreen({super.key, this.repository});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  late final DataRepository _repo;
  late final PaginationController<CourierTask> _controller;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DataRepository();
    // Завершённые заявки отсекает сервер: фильтровать уже загруженную страницу
    // на клиенте нельзя — активные заявки с других страниц потерялись бы.
    _controller = PaginationController<CourierTask>(
      fetchPage: (page) => _repo.courierTasks(page: page, activeOnly: true),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reload() {
    _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Доставка'),
      ),
      body: SafeArea(
        child: _buildActiveTab(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDeliveryEditSheet(context, null),
        icon: const Icon(Icons.add),
        label: const Text(
          'Заявка на доставку',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildActiveTab() {
    return PaginatedListView<CourierTask>(
      controller: _controller,
      emptyBuilder: Column(
        children: const [
          PremiumIconBadge(
            icon: Icons.local_shipping_outlined,
            size: 56,
            iconSize: 28,
          ),
          SizedBox(height: 16),
          Text(
            'Нет активных заявок',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Создайте заявку на доставку заказа',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      itemBuilder: (ctx, task, _) => _CourierTaskCard(
        task: task,
        onStatusChange: (newStatus) {},
        onTap: () => _showDeliveryEditSheet(context, task),
      ),
    );
  }

  void _showDeliveryEditSheet(BuildContext context, CourierTask? task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveryRequestSheet(
        repository: _repo,
        initialTask: task,
        onCreated: _reload,
      ),
    );
  }
}

class _DeliveryRequestSheet extends StatefulWidget {
  final DataRepository repository;
  final CourierTask? initialTask;
  final VoidCallback onCreated;

  const _DeliveryRequestSheet({
    required this.repository,
    this.initialTask,
    required this.onCreated,
  });

  @override
  State<_DeliveryRequestSheet> createState() => _DeliveryRequestSheetState();
}

class _DeliveryRequestSheetState extends State<_DeliveryRequestSheet> {
  final _addrCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _timeSlotCtrl = TextEditingController(text: '10:00 - 18:00');
  final _commentCtrl = TextEditingController();
  String _selectedType = 'delivery';
  bool _saving = false;

  bool get _hasChanges {
    if (widget.initialTask == null) {
      return _addrCtrl.text.isNotEmpty;
    }
    final t = widget.initialTask!;
    if (_selectedType != t.taskType) return true;
    if (_addrCtrl.text != t.address) return true;
    if (_contactCtrl.text != (t.contactName ?? '')) return true;
    if (_phoneCtrl.text != (t.contactPhone ?? '')) return true;
    if (_timeSlotCtrl.text != t.timeSlot) return true;
    if (_commentCtrl.text != (t.comment ?? '')) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTask != null) {
      final t = widget.initialTask!;
      _selectedType = t.taskType;
      _addrCtrl.text = t.address;
      _contactCtrl.text = t.contactName ?? '';
      _phoneCtrl.text = t.contactPhone ?? '';
      _timeSlotCtrl.text = t.timeSlot;
      _commentCtrl.text = t.comment ?? '';
    }

    for (final controller in [_addrCtrl, _contactCtrl, _phoneCtrl, _timeSlotCtrl, _commentCtrl]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [_addrCtrl, _contactCtrl, _phoneCtrl, _timeSlotCtrl, _commentCtrl]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_addrCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите адрес')));
      return;
    }

    setState(() => _saving = true);
    try {
      final data = {
        'type': _selectedType,
        'address': _addrCtrl.text.trim(),
        'contactName': _contactCtrl.text.trim(),
        'contactPhone': _phoneCtrl.text.trim(),
        'timeSlot': _timeSlotCtrl.text.trim(),
        'comment': _commentCtrl.text.trim(),
      };

      if (widget.initialTask != null) {
        await widget.repository.updateCourierTask(widget.initialTask!.id, data);
      } else {
        await widget.repository.createCourierTask(data);
      }

      if (!mounted) return;
      widget.onCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.initialTask != null ? 'Заявка обновлена' : 'Заявка успешно создана'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить заявку?'),
        content: const Text('Заявка на доставку будет аннулирована.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('НЕТ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('ОТМЕНИТЬ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await widget.repository.cancelCourierTask(widget.initialTask!.id);
      if (!mounted) return;
      widget.onCreated();
      Navigator.pop(context);
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
      child: SafeArea(
        top: false, // Scaffold already handles top
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16, 20, 16, 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.initialTask != null ? 'ИЗМЕНЕНИЕ ЗАЯВКИ' : 'НОВАЯ ЗАЯВКА КУРЬЕРУ',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              // Выбора типа больше нет: «Возврат» означал возврат образца, а
              // готовое маляр теперь забирает сам. Остаётся доставка; забор
              // лючка на подбор заказывается через Color Lab и создаётся там
              // автоматически. При редактировании тип берётся из заявки.
              if (widget.initialTask != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    color: AppColors.brandBlack,
                    child: Text(
                      (widget.initialTask!.typeDisplay.isNotEmpty
                              ? widget.initialTask!.typeDisplay
                              : 'Доставка')
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              TextField(
                controller: _addrCtrl,
                decoration: const InputDecoration(
                  labelText: 'АДРЕС *',
                  prefixIcon: BrandIcon(BrandIcons.location, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _contactCtrl,
                      decoration: const InputDecoration(labelText: 'КОНТАКТНОЕ ЛИЦО'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'ТЕЛЕФОН'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _timeSlotCtrl,
                decoration: const InputDecoration(
                  labelText: 'ВРЕМЕННОЙ ИНТЕРВАЛ',
                  prefixIcon: Icon(Icons.access_time, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'КОММЕНТАРИЙ',
                  prefixIcon: Icon(Icons.comment_outlined, size: 20),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              if (widget.initialTask != null)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          onPressed: _saving ? null : _handleDelete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          child: const Text('ОТМЕНИТЬ'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: (_saving || !_hasChanges) ? null : _submit,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                          child: Text(_saving ? 'СОХРАНЕНИЕ...' : 'ПОДТВЕРДИТЬ'),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_saving || !_hasChanges) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandBlack,
                      shape: const BeveledRectangleBorder(),
                    ),
                    child: _saving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('ОТПРАВИТЬ ЗАЯВКУ', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}

/// Этап доставки, который видит клиент. Статусы «возвращено» и «отменено»
/// сюда не попадают — это не продолжение пути, а его исход, и показываются
/// отдельной плашкой.
enum _DeliveryStage { created, assigned, onTheWay, done }

class _CourierTaskCard extends StatelessWidget {
  final CourierTask task;
  final ValueChanged<int> onStatusChange;
  final VoidCallback? onTap;

  const _CourierTaskCard({required this.task, required this.onStatusChange, this.onTap});

  static final _dateFmt = DateFormat('d MMM, HH:mm', 'ru_RU');
  static final _timeFmt = DateFormat('HH:mm', 'ru_RU');

  bool get _isCancelled => task.status == CourierTaskStatus.cancelled;
  bool get _isReturned => task.status == CourierTaskStatus.returned;

  /// До какого этапа дошла заявка.
  _DeliveryStage get _stage {
    switch (task.status) {
      case CourierTaskStatus.created:
        return _DeliveryStage.created;
      case CourierTaskStatus.assigned:
        return _DeliveryStage.assigned;
      case CourierTaskStatus.inProgress:
        return _DeliveryStage.onTheWay;
      case CourierTaskStatus.delivered:
      case CourierTaskStatus.returned:
        return _DeliveryStage.done;
      case CourierTaskStatus.cancelled:
        return _DeliveryStage.created;
    }
  }

  /// Название последнего этапа зависит от типа заявки: заказ «доставлен»,
  /// а лючок — «забран».
  String get _finalStageLabel {
    if (_isReturned) return 'Возвращено';
    switch (task.taskType) {
      case 'pickup':
      case 'color_lab_pickup':
        return 'Забрано';
      case 'return':
        return 'Возвращено';
      default:
        return 'Доставлено';
    }
  }

  String get _title {
    final type = task.typeDisplay.isNotEmpty ? task.typeDisplay : 'Доставка';
    return task.orderId == null ? type : '$type · Заказ №${task.orderId}';
  }

  /// Что происходит прямо сейчас — человеческим языком, без статус-кодов.
  String get _hint {
    final slot = task.timeSlot.isEmpty ? '' : ', ${task.timeSlot}';
    switch (task.status) {
      case CourierTaskStatus.created:
        return 'Заявка принята. Назначаем курьера — как только он появится, '
            'здесь будут его имя и телефон.';
      case CourierTaskStatus.assigned:
        final name = task.courierName == null ? 'Курьер' : task.courierName!;
        return '$name назначен и скоро выедет к вам$slot.';
      case CourierTaskStatus.inProgress:
        return 'Курьер уже в пути. Ожидайте по адресу$slot — держите телефон под рукой.';
      case CourierTaskStatus.delivered:
        final at = task.reachedAt(CourierTaskStatus.delivered);
        return at == null ? 'Заказ доставлен.' : 'Заказ доставлен ${_dateFmt.format(at)}.';
      case CourierTaskStatus.returned:
        return 'Заказ возвращён на склад. Если это ошибка — свяжитесь с дистрибьютором.';
      case CourierTaskStatus.cancelled:
        return 'Заявка отменена. Чтобы вызвать курьера снова, создайте новую заявку.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = task.status == CourierTaskStatus.created;

    return GestureDetector(
      onTap: canEdit ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(
              color: _isCancelled ? AppColors.border : AppColors.brandRed,
              width: 3,
            ),
            top: const BorderSide(color: AppColors.border),
            right: const BorderSide(color: AppColors.border),
            bottom: const BorderSide(color: AppColors.border),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge.fromCourierStatus(task.status),
                ],
              ),
              const SizedBox(height: 8),
              _infoRow(Icons.location_on_outlined, task.address),
              if (task.timeSlot.isNotEmpty) _infoRow(Icons.access_time, _whenText()),
              if (task.contactName != null && task.contactName!.isNotEmpty)
                _infoRow(Icons.person_outline, 'Получатель: ${task.contactName}'),
              const SizedBox(height: 14),
              if (_isCancelled)
                _banner(Icons.cancel_outlined, _hint, AppColors.textSecondary)
              else ...[
                _stepper(),
                const SizedBox(height: 12),
                _banner(
                  task.status == CourierTaskStatus.inProgress
                      ? Icons.local_shipping_outlined
                      : Icons.info_outline,
                  _hint,
                  _isReturned ? AppColors.textSecondary : AppColors.brandRed,
                ),
              ],
              if (task.courierName != null) ...[
                const SizedBox(height: 10),
                _courierRow(context),
              ],
              if (canEdit) ...[
                const SizedBox(height: 10),
                const Text(
                  'Нажмите, чтобы изменить или отменить заявку',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Когда ждать курьера: точное время, если оно назначено, иначе интервал.
  String _whenText() {
    final scheduled = task.scheduledTime;
    if (scheduled == null) return task.timeSlot;
    return '${_dayPrefix(scheduled)}, ${task.timeSlot}';
  }

  /// «Сегодня»/«Завтра» читается быстрее, чем дата.
  String _dayPrefix(DateTime moment) {
    final now = DateTime.now();
    final days = DateTime(moment.year, moment.month, moment.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days == 0) return 'Сегодня';
    if (days == 1) return 'Завтра';
    return DateFormat('d MMMM', 'ru_RU').format(moment);
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Горизонтальная шкала с подписанными этапами и временем каждого перехода:
  /// без подписей точки не говорят клиенту ничего.
  Widget _stepper() {
    final steps = <(_DeliveryStage, String, DateTime?)>[
      (_DeliveryStage.created, 'Создана', task.reachedAt(CourierTaskStatus.created)),
      (_DeliveryStage.assigned, 'Курьер назначен', task.reachedAt(CourierTaskStatus.assigned)),
      (_DeliveryStage.onTheWay, 'В пути', task.reachedAt(CourierTaskStatus.inProgress)),
      (
        _DeliveryStage.done,
        _finalStageLabel,
        task.reachedAt(_isReturned ? CourierTaskStatus.returned : CourierTaskStatus.delivered),
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          if (i < steps.length - 1)
            Expanded(child: _stepCell(steps[i], withLine: true, lineDone: _stage.index > i))
          else
            SizedBox(width: 76, child: _stepCell(steps[i], withLine: false, alignRight: true)),
      ],
    );
  }

  Widget _stepCell(
    (_DeliveryStage, String, DateTime?) step, {
    required bool withLine,
    bool lineDone = false,
    bool alignRight = false,
  }) {
    final (stage, label, at) = step;
    final reached = _stage.index >= stage.index;
    final isCurrent = _stage == stage;
    final color = reached ? AppColors.brandRed : AppColors.border;

    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 14,
          child: Row(
            children: [
              Container(
                width: isCurrent ? 14 : 10,
                height: isCurrent ? 14 : 10,
                decoration: BoxDecoration(
                  color: isCurrent ? Colors.white : color,
                  border: Border.all(color: color, width: isCurrent ? 4 : 1),
                  shape: BoxShape.circle,
                ),
              ),
              if (withLine)
                Expanded(
                  child: Container(
                    height: 1,
                    color: lineDone ? AppColors.brandRed : AppColors.border,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 10,
            height: 1.2,
            fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
            color: reached ? AppColors.textPrimary : AppColors.textHint,
          ),
        ),
        if (at != null)
          Text(
            _stepTime(at),
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
      ],
    );
  }

  /// В пределах сегодняшнего дня достаточно времени, иначе нужна дата.
  String _stepTime(DateTime moment) {
    final now = DateTime.now();
    final sameDay = moment.year == now.year && moment.month == now.month && moment.day == now.day;
    return sameDay ? _timeFmt.format(moment) : _dateFmt.format(moment);
  }

  Widget _banner(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: color.withValues(alpha: 0.07),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  /// Кто везёт и как до него дозвониться — главное, чего не хватало клиенту.
  Widget _courierRow(BuildContext context) {
    final phone = task.courierPhone;
    return Row(
      children: [
        const Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.brandBlack),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            task.courierName!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        if (phone != null && phone.isNotEmpty)
          TextButton.icon(
            onPressed: () => _call(context, phone),
            icon: const Icon(Icons.phone, size: 16),
            label: const Text('ПОЗВОНИТЬ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandRed,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    final messenger = ScaffoldMessenger.of(context);
    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        messenger.showSnackBar(SnackBar(content: Text('Не удалось позвонить. Телефон: $phone')));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось позвонить. Телефон: $phone')));
    }
  }
}
