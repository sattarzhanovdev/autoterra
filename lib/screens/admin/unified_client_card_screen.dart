import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/data_repository.dart';

class UnifiedClientCardScreen extends StatefulWidget {
  final String clientId;
  const UnifiedClientCardScreen({super.key, required this.clientId});

  @override
  State<UnifiedClientCardScreen> createState() => _UnifiedClientCardScreenState();
}

class _UnifiedClientCardScreenState extends State<UnifiedClientCardScreen> {
  final DataRepository _repo = DataRepository();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _repo.managerClientUnified(widget.clientId);
      setState(() {
        _data = res;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.brandRed)));
    if (_data == null) return const Scaffold(body: Center(child: Text('ОШИБКА ЗАГРУЗКИ')));

    final client = _data!['client'];
    final purchases = _data!['purchases'] as List;
    final orders = _data!['orders'] as List;
    final colorReqs = _data!['colorRequests'] as List;
    final tickets = _data!['tickets'] as List;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.brandBlack,
          title: Text(client['name'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'ПОКУПКИ'),
              Tab(text: 'ЗАКАЗЫ'),
              Tab(text: 'ЦВЕТ'),
              Tab(text: 'AI/QA'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(purchases, 'ПОКУПКИ'),
            _buildList(orders, 'ЗАКАЗЫ'),
            _buildList(colorReqs, 'КОЛЕРОВКА'),
            _buildList(tickets, 'ТИКЕТЫ'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showSendNotification(client['userId']?.toString() ?? ''),
          backgroundColor: AppColors.brandRed,
          icon: const Icon(Icons.send, color: Colors.white),
          label: const Text('ОТПРАВИТЬ СОВЕТ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _showSendNotification(String userId) {
    if (userId.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => _SendNotificationDialog(userId: userId),
    );
  }

  Widget _buildList(List items, String title) {
    if (items.isEmpty) return Center(child: Text('НЕТ ДАННЫХ ($title)'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final it = items[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
          child: ListTile(
            title: Text(it['documentNumber'] ?? it['question'] ?? it['carBrand'] ?? 'ОБЪЕКТ #${it['id']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            subtitle: Text(it['status'] ?? 'В ОБРАБОТКЕ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary)),
            trailing: Text('${it['totalAmount'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        );
      },
    );
  }
}

class _SendNotificationDialog extends StatefulWidget {
  final String userId;
  const _SendNotificationDialog({required this.userId});

  @override
  State<_SendNotificationDialog> createState() => _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<_SendNotificationDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _type = 'recommendation';
  bool _loading = false;

  final _types = [
    {'id': 'info', 'label': 'Инфо'},
    {'id': 'recommendation', 'label': 'Рекомендация'},
    {'id': 'action_required', 'label': 'Требуется действие'},
    {'id': 'ai', 'label': 'AI Совет'},
  ];

  Future<void> _send() async {
    if (_titleCtrl.text.isEmpty || _bodyCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await DataRepository().sendNotification(
        userId: widget.userId,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        type: _type,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Уведомление отправлено')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ОТПРАВИТЬ СОВЕТ / PUSH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'ТИП'),
              items: _types.map((t) => DropdownMenuItem(value: t['id'], child: Text(t['label']!))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'ЗАГОЛОВОК', hintText: 'Например: Совет по технологии')),
            const SizedBox(height: 16),
            TextField(controller: _bodyCtrl, decoration: const InputDecoration(labelText: 'ТЕКСТ', alignLabelWithHint: true), maxLines: 4),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОТМЕНА')),
        ElevatedButton(
          onPressed: _loading ? null : _send,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
          child: Text(_loading ? 'ОТПРАВКА...' : 'ОТПРАВИТЬ'),
        ),
      ],
    );
  }
}

