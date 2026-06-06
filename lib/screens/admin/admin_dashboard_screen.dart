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
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _distributors = [];

  String? _selectedRegion;
  String? _selectedDistributor;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        _repo.managerDashboard(),
        _repo.getRegions(),
        _repo.getDistributors(),
      ]);
      setState(() {
        _stats = res[0] as Map<String, dynamic>;
        _regions = (res[1] as List<dynamic>).cast<Map<String, dynamic>>();
        _distributors = (res[2] as List<dynamic>).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final data = await _repo.managerDashboard(
        regionId: _selectedRegion,
        distributorId: _selectedDistributor,
      );
      setState(() => _stats = data);
    } catch (e) {
      // Error
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ru_RU');

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('АНАЛИТИКА (ИМПОРТЕР)'),
        backgroundColor: AppColors.brandBlack,
        actions: [
          IconButton(icon: const Icon(Icons.file_download_outlined, color: Colors.white), onPressed: () => _repo.downloadReport(regionId: _selectedRegion)),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _refresh),
        ],
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
        : RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFilters(),
                const SizedBox(height: 24),
                if (_stats != null) ...[
                  _buildSummaryGrid(fmt),
                  const SizedBox(height: 32),
                  _sectionTitle('РЕГИОНАЛЬНЫЙ РАЗРЕЗ'),
                  const SizedBox(height: 12),
                  ...(_stats!['regionalStats'] as List).map((r) => _RegionRow(data: r, fmt: fmt)),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ФИЛЬТРАЦИЯ ДАННЫХ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedRegion,
            hint: const Text('ВСЕ РЕГИОНЫ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            isDense: true,
            decoration: const InputDecoration(labelText: 'РЕГИОН', labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
            items: [
              const DropdownMenuItem(value: null, child: Text('ВСЕ РЕГИОНЫ')),
              ..._regions.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['name'].toString().toUpperCase()))),
            ],
            onChanged: (v) {
              setState(() => _selectedRegion = v);
              _refresh();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedDistributor,
            hint: const Text('ВСЕ ДИСТРИБЬЮТОРЫ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            isDense: true,
            decoration: const InputDecoration(labelText: 'ДИСТРИБЬЮТОР', labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
            items: [
              const DropdownMenuItem(value: null, child: Text('ВСЕ ДИСТРИБЬЮТОРЫ')),
              ..._distributors.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['name'].toString().toUpperCase()))),
            ],
            onChanged: (v) {
              setState(() => _selectedDistributor = v);
              _refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(NumberFormat fmt) {
    return Column(
      children: [
        Row(
          children: [
            _statCard('КЛИЕНТЫ', _stats!['totalClients'].toString(), Icons.people),
            const SizedBox(width: 12),
            _statCard('В РАБОТЕ', _stats!['activeOrders'].toString(), Icons.shopping_cart, color: AppColors.brandRed),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _statCard('ВЫПОЛНЕНО', _stats!['fulfilledOrders'].toString(), Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 12),
            _statCard('ОБОРОТ', '${fmt.format(_stats!['totalTurnover'])} ₽', Icons.account_balance_wallet, color: AppColors.brandBlack),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5));
}

class _RegionRow extends StatelessWidget {
  final dynamic data;
  final NumberFormat fmt;
  const _RegionRow({required this.data, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(child: Text(data['region'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
          _smallStat('СТО', data['clients'].toString()),
          const SizedBox(width: 16),
          _smallStat('ЗАКАЗЫ', data['orders'].toString()),
        ],
      ),
    );
  }

  Widget _smallStat(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
      ],
    );
  }
}
