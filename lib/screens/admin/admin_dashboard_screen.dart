import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/app_logo.dart';

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
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка API: $e')));
      }
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
    final clients = _analytics?['totalClients'] ?? 0;
    final turnover = _analytics?['monthlyTurnover'] ?? 0.0;
    final orders = _analytics?['newOrders'] ?? 0; 
    final tickets = _analytics?['openTickets'] ?? 0;
    final actions = (_analytics?['recentActions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final turnoverHistory = (_analytics?['turnoverChart'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final categoryStats = (_analytics?['categoriesChart'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const AppLogo(height: 26),
        backgroundColor: AppColors.brandBlack,
        toolbarHeight: 70,
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'КЛЮЧЕВЫЕ ПОКАЗАТЕЛИ'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _buildKpiCard('Клиенты', clients.toString(), Icons.people),
                  _buildKpiCard('Выручка', '${fmt.format(turnover)} ₽', Icons.payments),
                  _buildKpiCard('Заказы', orders.toString(), Icons.shopping_cart),
                  _buildKpiCard('Тикеты (актив)', tickets.toString(), Icons.support_agent),
                ],
              ),
              const SizedBox(height: 24),
              if (turnoverHistory.isNotEmpty) ...[
                const SectionHeader(title: 'ТРЕНД ВЫРУЧКИ (6 МЕС)'),
                const SizedBox(height: 12),
                _buildTurnoverChart(turnoverHistory),
                const SizedBox(height: 24),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (categoryStats.isNotEmpty)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'КАТЕГОРИИ'),
                          const SizedBox(height: 12),
                          _buildCategoryChart(categoryStats),
                        ],
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'ДЕЙСТВИЯ'),
                        const SizedBox(height: 12),
                        ...actions.take(5).map((a) => _buildMiniAction(a)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.brandRed),
              const SizedBox(width: 6),
              Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(color: AppColors.brandBlack, fontWeight: FontWeight.w900, fontSize: 20)),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnoverChart(List<Map<String, dynamic>> history) {
    final spots = history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['value'].toDouble())).toList();
    
    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      decoration: const ShapeDecoration(
        color: AppColors.brandBlack,
        shape: BeveledRectangleBorder(),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  if (val.toInt() < history.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(history[val.toInt()]['label'], style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.brandRed,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.brandRed.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart(List<Map<String, dynamic>> stats) {
    final colors = [AppColors.brandRed, AppColors.brandBlack, const Color(0xFF5A5A5A)];
    final total = stats.fold<double>(0, (prev, element) => prev + element['value']);
    
    if (total == 0) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.border)),
        ),
        child: const Text('Нет данных по категориям', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textHint)),
      );
    }

    return Container(
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.border)),
      ),
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 30,
          sections: stats.asMap().entries.map((e) {
            return PieChartSectionData(
              color: colors[e.key % colors.length],
              value: e.value['value'].toDouble(),
              title: e.value['label'],
              radius: 40,
              titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMiniAction(Map<String, dynamic> a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppColors.brandRed, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(a['title']!.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
              Text(a['time']!, style: const TextStyle(color: AppColors.textHint, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(a['subtitle']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
