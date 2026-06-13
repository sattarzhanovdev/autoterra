import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../services/data_repository.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../models/models.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/app_logo.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DataRepository _repo = DataRepository();
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _distributors = [];
  String? _selectedRegionId;
  String? _selectedDistributorId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        _repo.adminAnalytics(regionId: _selectedRegionId, distributorId: _selectedDistributorId),
        _api.getRegions(),
        _api.getDistributors(),
      ]);
      setState(() {
        _analytics = res[0] as Map<String, dynamic>;
        _regions = (res[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _distributors = (res[2] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('AdminDashboard Init Error: $e');
      if (mounted) {
        setState(() {
          _analytics = {
            'totalClients': 0,
            'monthlyTurnover': 0.0,
            'newOrders': 0,
            'openTickets': 0,
          };
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка API: $e')));
      }
    }
  }

  Future<void> _fetch() async {
    try {
      final res = await _repo.adminAnalytics(regionId: _selectedRegionId, distributorId: _selectedDistributorId);
      setState(() {
        _analytics = res;
      });
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final role = authService.currentRole;
    final isGlobal = role == UserRole.admin;

    if (_loading && _analytics == null) {
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
    final system = _analytics?['system'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const AppLogo(height: 32),
        centerTitle: true,
        backgroundColor: AppColors.brandBlack,
        toolbarHeight: 70,
      ),
      body: RefreshIndicator(
        onRefresh: _initData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isGlobal && system != null) ...[
                const SectionHeader(title: 'СТРУКТУРА СИСТЕМЫ'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSystemCard('МЕНЕДЖЕРЫ', system['totalManagers'].toString(), Icons.admin_panel_settings)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSystemCard('ДИСТРИБЬЮТОРЫ', system['totalDistributors'].toString(), Icons.hub)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSystemCard('РЕГИОНЫ', system['totalRegions'].toString(), Icons.map_outlined)),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              _buildFilters(),
              const SizedBox(height: 24),
              const SectionHeader(title: 'ЭФФЕКТИВНОСТЬ (KPI)'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _buildKpiCard('Клиенты', clients.toString(), Icons.people, highlight: isGlobal),
                  _buildKpiCard('Выручка', '${fmt.format(turnover)} ₽', Icons.payments, highlight: isGlobal),
                  _buildKpiCard('Заказы', orders.toString(), Icons.shopping_cart),
                  _buildKpiCard('Тикеты (актив)', tickets.toString(), Icons.support_agent),
                ],
              ),
              const SizedBox(height: 24),
              if (isGlobal && system?['topDistributors'] != null) ...[
                const SectionHeader(title: 'АНАЛИЗ ЛИДЕРОВ РЫНКА'),
                const SizedBox(height: 12),
                _buildDistributorPerformanceChart(system!['topDistributors'] as List),
                const SizedBox(height: 16),
                ...((system['topDistributors'] as List).cast<Map<String, dynamic>>()).asMap().entries.map((e) => _buildTopPerformerRow(e.value, fmt, e.key)),
                const SizedBox(height: 24),
              ],
              if (turnoverHistory.isNotEmpty) ...[
                const SectionHeader(title: 'ДИНАМИКА ПРОДАЖ (6 МЕС)'),
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

  Widget _buildKpiCard(String label, String value, IconData icon, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? AppColors.brandRed.withValues(alpha: 0.03) : Colors.white,
        border: Border.all(color: highlight ? AppColors.brandRed : AppColors.border, width: highlight ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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

  Widget _buildDistributorPerformanceChart(List stats) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(20),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.border)),
      ),
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: stats.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value['value'].toDouble(),
                  color: AppColors.brandRed,
                  width: 30,
                  borderRadius: BorderRadius.zero,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSystemCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const ShapeDecoration(
        color: AppColors.brandBlack,
        shape: BeveledRectangleBorder(),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.brandRed, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildTopPerformerRow(Map<String, dynamic> d, NumberFormat fmt, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
          right: BorderSide(color: AppColors.border, width: 0.5),
          bottom: BorderSide(color: AppColors.border, width: 0.5),
          left: BorderSide(color: AppColors.brandBlack, width: 3),
        ),
      ),
      child: Row(
        children: [
          Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.textHint)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(d['name'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ),
          Text('${fmt.format(d['value'])} ₽', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.brandRed, fontSize: 12)),
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

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ФИЛЬТРЫ ДАННЫХ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.brandRed)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedRegionId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'РЕГИОН', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все регионы')),
                    ..._regions.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['name']))),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedRegionId = v);
                    _fetch();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedDistributorId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'ДИСТРИБЬЮТОР', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все дистрибьюторы')),
                    ..._distributors.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['name']))),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedDistributorId = v);
                    _fetch();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
