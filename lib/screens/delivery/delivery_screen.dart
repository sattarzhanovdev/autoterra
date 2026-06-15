import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/common/status_badge.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Future<List<CourierTask>> _future;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _future = DataRepository().courierTasks();
  }

  void _reload() {
    setState(() {
      _future = DataRepository().courierTasks();
    });
  }

  Future<void> _refresh() async {
    final next = DataRepository().courierTasks();
    setState(() => _future = next);
    await next;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Доставка'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'АКТИВНЫЕ'),
            Tab(text: 'ИСТОРИЯ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildActiveTab(), _buildHistoryTab()],
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
    return FutureBuilder<List<CourierTask>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final tasks = snapshot.data!.where((t) => t.status.index < 3).toList();
        if (tasks.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 180),
                Center(
                  child: Column(
                    children: [
                      const PremiumIconBadge(
                        icon: Icons.local_shipping_outlined,
                        size: 56,
                        iconSize: 28,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Нет активных заявок',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Создайте заявку на доставку заказа',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (ctx, i) => _CourierTaskCard(
              task: tasks[i],
              onStatusChange: (newStatus) {},
              onTap: () => _showDeliveryEditSheet(context, tasks[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<List<CourierTask>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final tasks = snapshot.data!.where((t) => t.status.index >= 3).toList();
        if (tasks.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 220),
                Center(child: Text('История пуста')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (ctx, i) {
              final task = tasks[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      PremiumIconBadge(
                        icon: task.taskType == 'pickup'
                            ? Icons.call_received
                            : Icons.local_shipping_outlined,
                        size: 40,
                        iconSize: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.typeDisplay.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              task.address,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge.fromCourierStatus(task.status),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showDeliveryEditSheet(BuildContext context, CourierTask? task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveryRequestSheet(
        initialTask: task,
        onCreated: _reload,
      ),
    );
  }
}

class _DeliveryRequestSheet extends StatefulWidget {
  final CourierTask? initialTask;
  final VoidCallback onCreated;

  const _DeliveryRequestSheet({this.initialTask, required this.onCreated});

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
        await DataRepository().updateCourierTask(widget.initialTask!.id, data);
      } else {
        await DataRepository().createCourierTask(data);
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
      await DataRepository().cancelCourierTask(widget.initialTask!.id);
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
          Row(
            children: [
              _typeBtn('delivery', 'ДОСТАВКА'),
              const SizedBox(width: 8),
              _typeBtn('return', 'ВОЗВРАТ'),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _addrCtrl,
            decoration: const InputDecoration(
              labelText: 'АДРЕС *',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
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
    );
  }

  Widget _typeBtn(String val, String label) {
    final active = _selectedType == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.brandBlack : Colors.white,
            border: Border.all(color: active ? AppColors.brandBlack : AppColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: active ? Colors.white : AppColors.brandBlack,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _CourierTaskCard extends StatelessWidget {
  final CourierTask task;
  final ValueChanged<int> onStatusChange;
  final VoidCallback? onTap;

  const _CourierTaskCard({required this.task, required this.onStatusChange, this.onTap});

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Создана',
      'Назначен курьер',
      'Лючок забран',
      'В работе',
      'Готово',
    ];
    final currentStep = task.status.index;
    final canEdit = task.status == CourierTaskStatus.created;

    return GestureDetector(
      onTap: canEdit ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(color: AppColors.brandRed, width: 3),
            top: BorderSide(color: AppColors.border),
            right: BorderSide(color: AppColors.border),
            bottom: BorderSide(color: AppColors.border),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    task.taskType == 'pickup' ? 'Забор лючка' : 'Доставка',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  StatusBadge.fromCourierStatus(task.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.address,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress dots
              Row(
                children: List.generate(
                  steps.length,
                  (i) => Expanded(
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: i <= currentStep
                                    ? AppColors.brandRed
                                    : AppColors.border,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 1,
                              color: i < currentStep
                                  ? AppColors.brandRed
                                  : AppColors.border,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[currentStep.clamp(0, steps.length - 1)],
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.brandRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
