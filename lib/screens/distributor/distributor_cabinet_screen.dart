import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

class DistributorCabinetScreen extends StatefulWidget {
  const DistributorCabinetScreen({super.key});

  @override
  State<DistributorCabinetScreen> createState() => _DistributorCabinetScreenState();
}

class _DistributorCabinetScreenState extends State<DistributorCabinetScreen> {
  final _api = const ApiClient();
  int _tab = 0;
  Future<Map<String, dynamic>>? _dashboard;
  Future<List<Map<String, dynamic>>>? _clients;
  Future<List<Map<String, dynamic>>>? _purchases;
  Future<List<Map<String, dynamic>>>? _orders;
  Future<List<Map<String, dynamic>>>? _stock;
  Future<Map<String, dynamic>>? _reports;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _dashboard = _api.distributorDashboard();
      _clients = _api.distributorClients();
      _purchases = _api.distributorPurchases();
      _orders = _api.distributorOrders();
      _stock = _api.distributorStock();
      _reports = _api.distributorReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['Dashboard', 'Клиенты', 'Покупки', 'Заказы', 'Остатки', 'Отчеты'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кабинет дистрибьютора'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _switchRole,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'client', child: Text('body shop / client')),
              PopupMenuItem(value: 'distributor', child: Text('distributor')),
              PopupMenuItem(value: 'manager', child: Text('manager')),
              PopupMenuItem(value: 'admin', child: Text('admin')),
              PopupMenuItem(value: 'courier', child: Text('courier')),
              PopupMenuItem(value: 'ai', child: Text('AI / knowledge-base')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.account_tree_outlined),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: tabs.asMap().entries.map((entry) {
                final active = _tab == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    onPressed: () => setState(() => _tab = entry.key),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: active ? AppColors.brandBlack : Colors.white,
                      foregroundColor: active ? Colors.white : AppColors.brandBlack,
                    ),
                    child: Text(entry.value),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _content() {
    switch (_tab) {
      case 1:
        return _list(_clients!, _clientTile);
      case 2:
        return _list(_purchases!, _purchaseTile);
      case 3:
        return _list(_orders!, _orderTile);
      case 4:
        return _stockUpload();
      case 5:
        return _reportsView();
      default:
        return _dashboardView();
    }
  }

  Widget _dashboardView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final metrics = snapshot.data!['metrics'] as Map<String, dynamic>;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _metric('Клиенты', metrics['clients']),
              _metric('Новые заявки', metrics['newClients']),
              _metric('Покупки на проверку', metrics['purchasesToVerify']),
              _metric('Заказы в работе', metrics['ordersToProcess']),
              _metric('SKU в остатках', metrics['stockItems']),
              _metric('Низкий остаток', metrics['lowStock']),
            ],
          ),
        );
      },
    );
  }

  Widget _list(Future<List<Map<String, dynamic>>> future, Widget Function(Map<String, dynamic>) tile) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('Нет данных'));
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) => tile(items[index]),
          ),
        );
      },
    );
  }

  Widget _clientTile(Map<String, dynamic> item) {
    return _panel(
      title: item['name']?.toString() ?? 'Клиент',
      subtitle: 'ИНН ${item['inn']} · ${item['region']}',
      trailing: item['status']?.toString(),
    );
  }

  Widget _purchaseTile(Map<String, dynamic> item) {
    return _panel(
      title: item['documentNumber']?.toString() ?? 'Документ',
      subtitle: '${item['clientInn'] ?? ''} · ${item['totalAmount']} ₽ · ${item['date']}',
      trailing: item['status']?.toString(),
      actions: [
        TextButton(onPressed: () => _confirmPurchase(item['id'].toString()), child: const Text('Подтвердить')),
        TextButton(onPressed: () => _rejectPurchase(item['id'].toString()), child: const Text('Отклонить')),
      ],
    );
  }

  Widget _orderTile(Map<String, dynamic> item) {
    return _panel(
      title: item['documentNumber']?.toString() ?? 'Заказ',
      subtitle: '${item['clientName'] ?? ''} · ${item['totalAmount']} ₽',
      trailing: item['orderStatus']?.toString(),
      actions: [
        TextButton(onPressed: () => _acceptOrder(item['id'].toString()), child: const Text('Принять')),
        TextButton(onPressed: () => _doneOrder(item['id'].toString()), child: const Text('Готово')),
        TextButton(onPressed: () => _rejectOrder(item['id'].toString()), child: const Text('Отклонить')),
      ],
    );
  }

  Widget _stockUpload() {
    final skuCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Загрузка остатка SKU', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'SKU')),
        const SizedBox(height: 8),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название')),
        const SizedBox(height: 8),
        TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Остаток')),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            await _api.distributorUploadStock([
              {
                'sku': skuCtrl.text,
                'name': nameCtrl.text,
                'quantity': int.tryParse(qtyCtrl.text) ?? 0,
                'status': 'inStock',
              }
            ]);
            _toast('Остаток загружен');
            _reload();
          },
          child: const Text('Загрузить'),
        ),
        const SizedBox(height: 20),
        const Text('Текущие остатки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _stock,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final items = snapshot.data!;
            if (items.isEmpty) return const Text('Остатки пока не загружены');
            return Column(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _panel(
                        title: '${item['sku']} · ${item['name']}',
                        subtitle: '${item['category']} · остаток ${item['quantity']} · ${item['status']}',
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _reportsView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _reports,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: data.entries.map((entry) => _panel(title: entry.key, subtitle: entry.value.toString())).toList(),
        );
      },
    );
  }

  Widget _metric(String label, Object? value) {
    return _panel(title: label, subtitle: value?.toString() ?? '0');
  }

  Widget _panel({
    required String title,
    required String subtitle,
    String? trailing,
    List<Widget> actions = const [],
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
              if (trailing != null) Text(trailing, style: const TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: actions),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmPurchase(String id) async {
    await _api.distributorConfirmPurchase(id);
    _toast('Покупка подтверждена');
    _reload();
  }

  Future<void> _rejectPurchase(String id) async {
    final reason = await _reason();
    if (reason == null) return;
    await _api.distributorRejectPurchase(id, reason);
    _toast('Покупка отклонена');
    _reload();
  }

  Future<void> _acceptOrder(String id) async {
    await _api.distributorAcceptOrder(id);
    _toast('Заказ принят');
    _reload();
  }

  Future<void> _doneOrder(String id) async {
    await _api.distributorUpdateOrderStatus(id, 'done');
    _toast('Заказ завершён');
    _reload();
  }

  Future<void> _rejectOrder(String id) async {
    final reason = await _reason();
    if (reason == null) return;
    await _api.distributorRejectOrder(id, reason);
    _toast('Заказ отклонён');
    _reload();
  }

  Future<String?> _reason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Причина отклонения'),
        content: TextField(controller: ctrl, minLines: 2, maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Сохранить')),
        ],
      ),
    );
  }

  void _switchRole(String role) {
    switch (role) {
      case 'client':
        context.go(AppRoutes.home);
        break;
      case 'courier':
        context.go(AppRoutes.courierCabinet);
        break;
      case 'ai':
        context.go(AppRoutes.aiAssistant);
        break;
      case 'distributor':
        break;
      default:
        _toast('Демо-роль "$role": интерфейс будет добавлен отдельным модулем');
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
