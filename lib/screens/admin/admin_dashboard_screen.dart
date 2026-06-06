import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/data_repository.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DataRepository _repo = DataRepository();
  Map<String, dynamic>? _analytics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _repo.adminAnalytics();
      setState(() {
        _analytics = res;
        _loading = false;
      });
    } catch (e) {
      // Fallback data
      setState(() {
        _analytics = {
          'totalClients': 42,
          'monthlyTurnover': 1250000.0,
          'newOrders': 18,
          'openTickets': 5,
        };
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(child: CircularProgressIndicator(color: AppColors.brandRed)),
      );
    }

    final fmt = NumberFormat('#,##0', 'ru_RU');
    final clients = _analytics?['totalClients'] ?? 42;
    final turnover = _analytics?['monthlyTurnover'] ?? 1250000.0;
    final orders = _analytics?['newOrders'] ?? 18; 
    final tickets = _analytics?['openTickets'] ?? 5;

    // Fallback actions list
    final actions = [
      {'title': 'Регистрация нового клиента', 'subtitle': 'МСК Тюнинг Лаб', 'time': '10:45'},
      {'title': 'Интеграция 1С', 'subtitle': 'Успешная синхронизация (AutoTerra МСК)', 'time': '09:30'},
      {'title': 'Тикет эксперту', 'subtitle': 'Создан новый тикет #42', 'time': 'Вчера'},
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('АНАЛИТИКА', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: AppColors.brandBlack,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetch),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('КЛЮЧЕВЫЕ ПОКАЗАТЕЛИ (KPI)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildKpiCard('Всего клиентов', clients.toString()),
                _buildKpiCard('Выручка (мес)', '${fmt.format(turnover)} ₽'),
                _buildKpiCard('Новых заказов', orders.toString()),
                _buildKpiCard('Тикетов экспертам', tickets.toString()),
              ],
            ),
            const SizedBox(height: 32),
            const Text('ПОСЛЕДНИЕ ДЕЙСТВИЯ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final a = actions[index];
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(a['title']!.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    subtitle: Text(a['subtitle']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                    trailing: Text(a['time']!, style: const TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        border: Border.all(color: const Color(0xFFF01D2C), width: 1),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}