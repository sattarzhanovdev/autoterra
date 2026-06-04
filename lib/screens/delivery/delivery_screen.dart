import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/attachment_picker.dart';

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
    _future = const DataRepository().courierTasks();
  }

  void _reload() {
    setState(() {
      _future = const DataRepository().courierTasks();
    });
  }

  Future<void> _refresh() async {
    final next = const DataRepository().courierTasks();
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
        title: const Text('ДОСТАВКА'),
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
        icon: const Icon(Icons.add_sharp),
        label: const Text(
          'ЗАЯВКА НА ДОСТАВКУ',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
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
          return Center(child: Text(snapshot.error.toString().toUpperCase()));
        }
        final tasks = snapshot.data!
            .where(
              (t) =>
                  t.status != CourierTaskStatus.delivered &&
                  t.status != CourierTaskStatus.returned &&
                  t.status != CourierTaskStatus.cancelled,
            )
            .toList();
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
                          Icons.local_shipping_sharp,
                          color: AppColors.brandRed,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'НЕТ АКТИВНЫХ ЗАЯВОК',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'СОЗДАЙТЕ ЗАЯВКУ НА ДОСТАВКУ ЗАКАЗА',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
              onAddProof: () => _showProofDialog(tasks[i]),
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
          return Center(child: Text(snapshot.error.toString().toUpperCase()));
        }
        final tasks = snapshot.data!
            .where(
              (t) =>
                  t.status == CourierTaskStatus.delivered ||
                  t.status == CourierTaskStatus.returned ||
                  t.status == CourierTaskStatus.cancelled,
            )
            .toList();
        if (tasks.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 220),
                Center(child: Text('ИСТОРИЯ ПУСТА', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textSecondary))),
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
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            color: AppColors.brandWhite,
                            child: Icon(
                              task.type == 'pickup'
                                  ? Icons.call_received_sharp
                                  : Icons.local_shipping_sharp,
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
                                      ? 'ЗАБОР ЛЮЧКА'
                                      : 'ДОСТАВКА ЗАКАЗА',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  task.address.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge.fromCourierStatus(task.status),
                        ],
                      ),
                      AttachmentList(attachments: task.attachments),
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
    final carCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    String selectedType = 'delivery';
    DateTime? scheduledTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.zero),
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
              const Text(
                'НОВАЯ ЗАЯВКА',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 2, color: AppColors.brandBlack),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => selectedType = 'delivery'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selectedType == 'delivery'
                              ? AppColors.brandBlack
                              : Colors.white,
                          border: Border.all(
                            color: AppColors.brandBlack,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'ДОСТАВКА ЗАКАЗА',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                            color: selectedType == 'delivery'
                                ? Colors.white
                                : AppColors.brandBlack,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => selectedType = 'return'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selectedType == 'return'
                              ? AppColors.brandBlack
                              : Colors.white,
                          border: Border.all(
                            color: AppColors.brandBlack,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'ВОЗВРАТ ЛЮЧКА',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                            color: selectedType == 'return'
                                ? Colors.white
                                : AppColors.brandBlack,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(
                  labelText: 'АДРЕС *',
                  prefixIcon: Icon(Icons.location_on_sharp),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date == null || !ctx.mounted) return;
                  final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                  if (time == null) return;
                  setS(() {
                    scheduledTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                  });
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'ДАТА И ВРЕМЯ',
                    prefixIcon: Icon(Icons.schedule_sharp),
                  ),
                  child: Text(
                    scheduledTime == null
                        ? 'ВЫБЕРИТЕ ДАТУ И ВРЕМЯ'
                        : '${scheduledTime!.day.toString().padLeft(2, '0')}.${scheduledTime!.month.toString().padLeft(2, '0')}.${scheduledTime!.year} ${scheduledTime!.hour.toString().padLeft(2, '0')}:${scheduledTime!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(
                  labelText: 'КОНТАКТНОЕ ЛИЦО *',
                  prefixIcon: Icon(Icons.person_sharp),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'ТЕЛЕФОН *',
                  prefixIcon: Icon(Icons.phone_sharp),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: carCtrl,
                decoration: const InputDecoration(
                  labelText: 'АВТО / ОПИСАНИЕ',
                  prefixIcon: Icon(Icons.directions_car_sharp),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'КОММЕНТАРИЙ',
                  prefixIcon: Icon(Icons.comment_sharp),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);
                  await const ApiClient().createCourierTask({
                    'type': selectedType,
                    'address': addrCtrl.text,
                    if (scheduledTime != null) 'scheduledTime': scheduledTime!.toIso8601String(),
                    'contactName': contactCtrl.text,
                    'contactPhone': phoneCtrl.text,
                    'carDescription': carCtrl.text,
                    'comment': commentCtrl.text,
                  });
                  if (!context.mounted) return;
                  _reload();
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('ЗАЯВКА НА ДОСТАВКУ СОЗДАНА')),
                  );
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                child: const Text('ОТПРАВИТЬ ЗАЯВКУ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showProofDialog(CourierTask task) {
    var files = <PlatformFile>[];
    var saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.zero),
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
              const Text(
                'ПОДТВЕРЖДЕНИЕ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 2, color: AppColors.brandBlack),
              const SizedBox(height: 16),
              AttachmentPicker(
                title: 'ФОТО ПОДТВЕРЖДЕНИЯ',
                emptyText: 'ЗАГРУЗИТЕ ФОТО ДОКУМЕНТА ИЛИ ЗАКАЗА',
                files: files,
                onChanged: (next) => setS(() => files = next),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (files.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ДОБАВЬТЕ ФОТО ПОДТВЕРЖДЕНИЯ')),
                          );
                          return;
                        }
                        setS(() => saving = true);
                        try {
                          await const ApiClient().uploadCourierProof(
                            taskId: task.id,
                            attachments: files,
                          );
                          if (!context.mounted) return;
                          _reload();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ФОТО ПОДТВЕРЖДЕНИЯ ЗАГРУЖЕНО')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().toUpperCase()), backgroundColor: AppColors.error),
                          );
                        } finally {
                          if (ctx.mounted) setS(() => saving = false);
                        }
                      },
                child: Text(saving ? 'ЗАГРУЗКА...' : 'ЗАГРУЗИТЬ ПОДТВЕРЖДЕНИЕ', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourierTaskCard extends StatelessWidget {
  final CourierTask task;
  final ValueChanged<int> onStatusChange;
  final VoidCallback onAddProof;

  const _CourierTaskCard({
    required this.task,
    required this.onStatusChange,
    required this.onAddProof,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      'СОЗДАНА',
      'НАЗНАЧЕН КУРЬЕР',
      'ОБЪЕКТ ЗАБРАН',
      'В РАБОТЕ',
      'ГОТОВО',
    ];
    final currentStep = switch (task.status) {
      CourierTaskStatus.created => 0,
      CourierTaskStatus.assigned => 1,
      CourierTaskStatus.pickedUp => 2,
      CourierTaskStatus.inProgress => 3,
      CourierTaskStatus.delivered || CourierTaskStatus.returned => 4,
      CourierTaskStatus.cancelled => 0,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: AppColors.brandRed, width: 4),
          top: BorderSide(color: AppColors.border, width: 1.5),
          right: BorderSide(color: AppColors.border, width: 1.5),
          bottom: BorderSide(color: AppColors.border, width: 1.5),
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
                  (task.type == 'pickup' ? 'ЗАБОР ЛЮЧКА' : 'ДОСТАВКА').toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                StatusBadge.fromCourierStatus(task.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on_sharp,
                  size: 14,
                  color: AppColors.brandBlack,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.address.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.person_sharp,
                  size: 14,
                  color: AppColors.brandBlack,
                ),
                const SizedBox(width: 6),
                Text(
                  '${task.contactName} · ${task.contactPhone}'.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Progress dots (squares)
            Row(
              children: List.generate(
                steps.length,
                (i) => Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: i <= currentStep
                              ? AppColors.brandRed
                              : AppColors.border,
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
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
            const SizedBox(height: 8),
            Text(
              steps[currentStep.clamp(0, steps.length - 1)],
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.brandRed,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            AttachmentList(attachments: task.attachments),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddProof,
                icon: const Icon(Icons.add_a_photo_sharp, size: 16),
                label: const Text('ЗАГРУЗИТЬ ПОДТВЕРЖДЕНИЕ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
