import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/data_repository.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final void Function(String? filter) openClients;
  final void Function(String? filter) openOrders;
  final DataRepository? repository;
  const ManagerDashboardScreen({super.key, required this.openClients, required this.openOrders, this.repository});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  late final DataRepository _repo = widget.repository ?? DataRepository();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _repo.managerDashboard();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.brandWhite,
    appBar: AppBar(title: const Text('КАБИНЕТ МЕНЕДЖЕРА'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Не удалось загрузить показатели: $_error'), TextButton(onPressed: _load, child: const Text('ПОВТОРИТЬ')),
        ]))
      : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
          _card('КЛИЕНТЫ', _data?['totalClients'], Icons.people_outline, () => widget.openClients(null)),
          _card('НОВЫЕ РЕГИСТРАЦИИ', _data?['newRegistrations'], Icons.person_add_alt, () => widget.openClients('pending')),
          _card('АКТИВНЫЕ ЗАКАЗЫ', _data?['activeOrders'], Icons.local_shipping_outlined, () => widget.openOrders('active')),
          _card('ВСЕ ЗАКАЗЫ', _data?['totalOrders'], Icons.receipt_long_outlined, () => widget.openOrders(null)),
          _card('ВЫПОЛНЕННЫЕ ЗАКАЗЫ', _data?['fulfilledOrders'], Icons.check_circle_outline, () => widget.openOrders('fulfilled')),
          _card('ОБОРОТ ВЫПОЛНЕННЫХ ЗАКАЗОВ', '${_data?['totalTurnover'] ?? 0} ₽', Icons.payments_outlined, () => widget.openOrders('fulfilled')),
        ])),
  );

  Widget _card(String title, Object? value, IconData icon, VoidCallback onTap) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppColors.brandRed),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
      subtitle: Text('${value ?? 0}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.chevron_right), onTap: onTap,
    ),
  );
}
