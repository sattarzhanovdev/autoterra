import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/attachment_picker.dart';
import '../../widgets/common/status_badge.dart';

class CourierCabinetScreen extends StatefulWidget {
  const CourierCabinetScreen({super.key});

  @override
  State<CourierCabinetScreen> createState() => _CourierCabinetScreenState();
}

class _CourierCabinetScreenState extends State<CourierCabinetScreen> {
  final _api = const ApiClient();
  late Future<List<CourierTask>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = const DataRepository().courierMyTasks());
  }

  Future<void> _refresh() async {
    final next = const DataRepository().courierMyTasks();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Кабинет курьера')),
      body: FutureBuilder<List<CourierTask>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final tasks = snapshot.data!;
          if (tasks.isEmpty) return const Center(child: Text('Нет назначенных задач'));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) => _TaskCard(
                task: tasks[index],
                onStatus: (status) => _setStatus(tasks[index], status),
                onComment: () => _comment(tasks[index]),
                onProof: () => _proof(tasks[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _setStatus(CourierTask task, String status) async {
    await _api.courierUpdateTaskStatus(task.id, status);
    _toast('Статус обновлён');
    _reload();
  }

  Future<void> _comment(CourierTask task) async {
    final ctrl = TextEditingController(text: task.courierComment ?? '');
    final comment = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Комментарий курьера'),
        content: TextField(controller: ctrl, minLines: 3, maxLines: 5),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Сохранить')),
        ],
      ),
    );
    if (comment == null) return;
    await _api.courierUpdateComment(task.id, comment);
    _toast('Комментарий сохранён');
    _reload();
  }

  Future<void> _proof(CourierTask task) async {
    var files = <PlatformFile>[];
    final selected = await showModalBottomSheet<List<PlatformFile>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AttachmentPicker(
                title: 'Фото подтверждения',
                emptyText: 'Фото передачи, лючка или доставки',
                files: files,
                onChanged: (next) => setS(() => files = next),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, files),
                child: const Text('Загрузить'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || selected.isEmpty) return;
    await _api.courierUploadProof(taskId: task.id, attachments: selected);
    _toast('Фото загружено');
    _reload();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _TaskCard extends StatelessWidget {
  final CourierTask task;
  final ValueChanged<String> onStatus;
  final VoidCallback onComment;
  final VoidCallback onProof;

  const _TaskCard({
    required this.task,
    required this.onStatus,
    required this.onComment,
    required this.onProof,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.type == 'pickup' ? 'Забор лючка' : task.type == 'return' ? 'Возврат' : 'Доставка',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              StatusBadge.fromCourierStatus(task.status),
            ],
          ),
          const SizedBox(height: 8),
          _line(Icons.location_on_outlined, task.address),
          _line(Icons.schedule_outlined, '${task.scheduledTime.day}.${task.scheduledTime.month}.${task.scheduledTime.year} ${task.scheduledTime.hour.toString().padLeft(2, '0')}:${task.scheduledTime.minute.toString().padLeft(2, '0')}'),
          _line(Icons.person_outline, '${task.contactName} · ${task.contactPhone}'),
          if (task.carDescription.isNotEmpty) _line(Icons.directions_car_outlined, task.carDescription),
          if ((task.comment ?? '').isNotEmpty) _line(Icons.comment_outlined, task.comment!),
          if ((task.courierComment ?? '').isNotEmpty) _line(Icons.edit_note, task.courierComment!),
          AttachmentList(attachments: task.attachments),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusButton('Забрал', 'picked_up'),
              _statusButton('В пути', 'in_progress'),
              _statusButton('Доставлено', 'delivered'),
              _statusButton('Возвращено', 'returned'),
              _statusButton('Отмена', 'cancelled'),
              OutlinedButton.icon(onPressed: onProof, icon: const Icon(Icons.add_a_photo_outlined, size: 16), label: const Text('Фото')),
              OutlinedButton.icon(onPressed: onComment, icon: const Icon(Icons.edit_note, size: 16), label: const Text('Комментарий')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusButton(String label, String status) {
    return ElevatedButton(onPressed: () => onStatus(status), child: Text(label));
  }

  Widget _line(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}
