import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
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
      ),
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
