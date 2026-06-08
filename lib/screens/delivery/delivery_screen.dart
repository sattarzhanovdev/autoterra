import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/data_repository.dart';
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
        onPressed: () => _showNewDeliveryDialog(context),
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
                      Container(
                        width: 72,
                        height: 72,
                        color: AppColors.brandWhite,
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: AppColors.brandRed,
                          size: 36,
                        ),
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
                      Container(
                        width: 42,
                        height: 42,
                        color: AppColors.brandWhite,
                        child: Icon(
                          task.type == 'pickup'
                              ? Icons.call_received
                              : Icons.local_shipping_outlined,
                          color: AppColors.brandBlack,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.type == 'pickup'
                                  ? 'Забор лючка'
                                  : 'Доставка заказа',
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

  void _showNewDeliveryDialog(BuildContext context) {
    final addrCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final timeSlotCtrl = TextEditingController(text: '10:00 - 18:00');
    final commentCtrl = TextEditingController();
    String selectedType = 'delivery';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(color: Colors.white),
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'НОВАЯ ЗАЯВКА КУРЬЕРУ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _typeBtn(setS, 'delivery', 'ДОСТАВКА', selectedType == 'delivery', (v) => selectedType = v),
                  const SizedBox(width: 8),
                  _typeBtn(setS, 'return', 'ВОЗВРАТ', selectedType == 'return', (v) => selectedType = v),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: addrCtrl,
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
                      controller: contactCtrl,
                      decoration: const InputDecoration(labelText: 'КОНТАКТНОЕ ЛИЦО'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'ТЕЛЕФОН'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeSlotCtrl,
                decoration: const InputDecoration(
                  labelText: 'ВРЕМЕННОЙ ИНТЕРВАЛ',
                  prefixIcon: Icon(Icons.access_time, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'КОММЕНТАРИЙ',
                  prefixIcon: Icon(Icons.comment_outlined, size: 20),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (addrCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Укажите адрес')));
                      return;
                    }
                    
                    setS(() => saving = true);
                    try {
                      await DataRepository().createCourierTask({
                        'type': selectedType,
                        'address': addrCtrl.text.trim(),
                        'contactName': contactCtrl.text.trim(),
                        'contactPhone': phoneCtrl.text.trim(),
                        'timeSlot': timeSlotCtrl.text.trim(),
                        'comment': commentCtrl.text.trim(),
                      });
                      if (!context.mounted) return;
                      _reload();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Заявка успешно создана'), backgroundColor: AppColors.success),
                      );
                    } catch (e) {
                      if (ctx.mounted) {
                        setS(() => saving = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBlack,
                    shape: const BeveledRectangleBorder(),
                  ),
                  child: saving 
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

  Widget _typeBtn(StateSetter setS, String val, String label, bool active, ValueChanged<String> onSelect) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setS(() => onSelect(val));
        },
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

  const _CourierTaskCard({required this.task, required this.onStatusChange});

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

    return Container(
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
                  task.type == 'pickup' ? 'Забор лючка' : 'Доставка',
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
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${task.contactName} · ${task.contactPhone}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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
    );
  }
}
