import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../models/paginated.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../purchases/purchases_screen.dart';
import '../../widgets/common/brand_icon.dart';

class DistributorOrdersScreen extends StatefulWidget {
  const DistributorOrdersScreen({super.key});

  @override
  State<DistributorOrdersScreen> createState() => _DistributorOrdersScreenState();
}

class _DistributorOrdersScreenState extends State<DistributorOrdersScreen> {
  late final PaginationController<Order> _controller;
  String? _status, _region, _distributor;
  String _search = '';
  DateTimeRange? _period;
  List<Map<String, dynamic>> _regions = [], _distributors = [];

  Future<void> _loadFilters() async {
    try {
      final regions = await fetchAllPages((page) => ApiClient().getRegions(page: page));
      final distributors = await fetchAllPages((page) => ApiClient().getDistributors(page: page));
      if (mounted) setState(() { _regions = regions; _distributors = distributors; });
    } catch (_) { /* Order list still exposes its own retry on failure. */ }
  }

  Future<void> _pickPeriod() async {
    final value = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)), initialDateRange: _period);
    if (!mounted || value == null) return;
    setState(() => _period = value);
    _load();
  }


  @override
  void initState() {
    super.initState();
    _controller = PaginationController<Order>(
      fetchPage: (page) => DataRepository().distributorOrders(
        page: page, status: _status, search: _search, regionId: _region, distributorId: _distributor,
        dateFrom: _period == null ? null : DateFormat('yyyy-MM-dd').format(_period!.start),
        dateTo: _period == null ? null : DateFormat('yyyy-MM-dd').format(_period!.end),
      ),
    );
    if (authService.currentRole == UserRole.admin) _loadFilters();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() => _controller.refresh();

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ru_RU');

    return Scaffold(
      appBar: AppBar(title: const Text('ЗАКАЗЫ')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          decoration: const InputDecoration(labelText: 'Номер заказа / клиент / ИНН', prefixIcon: Icon(Icons.search)),
          onChanged: (value) { _search = value; _controller.refreshDebounced(); },
        )),
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
          DropdownButton<String>(value: _status, hint: const Text('Все статусы'), items: [
            const DropdownMenuItem<String>(value: null, child: Text('Все статусы')),
            for (final entry in const {'new':'Новые','confirmed':'Подтверждены','adjusted':'Скорректированы','paid':'Оплачены','shipped':'Отправлены','fulfilled':'Доставлены','cancelled':'Отменены','rejected':'Отклонены'}.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ], onChanged: (v) { setState(() => _status = v); _load(); }),
          const SizedBox(width: 12),
          if (authService.currentRole == UserRole.admin) ...[
            DropdownButton<String>(value: _region, hint: const Text('Все регионы'), items: [
              const DropdownMenuItem<String>(value: null, child: Text('Все регионы')),
              for (final r in _regions) DropdownMenuItem(value: r['id'].toString(), child: Text(r['name'].toString())),
            ], onChanged: (v) { setState(() => _region = v); _load(); }),
            const SizedBox(width: 12),
            DropdownButton<String>(value: _distributor, hint: const Text('Все дилеры'), items: [
              const DropdownMenuItem<String>(value: null, child: Text('Все дилеры')),
              for (final d in _distributors) DropdownMenuItem(value: d['id'].toString(), child: Text(d['name'].toString())),
            ], onChanged: (v) { setState(() => _distributor = v); _load(); }),
          ],
          TextButton.icon(onPressed: _pickPeriod, icon: const Icon(Icons.date_range), label: Text(_period == null ? 'Период' : '${DateFormat('dd.MM').format(_period!.start)}–${DateFormat('dd.MM').format(_period!.end)}')),
          if (_period != null) IconButton(onPressed: () { setState(() => _period = null); _load(); }, icon: const Icon(Icons.clear)),
        ])),
        Expanded(child: PaginatedListView<Order>(
        controller: _controller,
        emptyBuilder: Column(
          children: const [
            PremiumIconBadge(
              icon: BrandIcons.cart,
              size: 56,
              iconSize: 28,
            ),
            SizedBox(height: 16),
            Text(
              'Нет заказов',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        itemBuilder: (context, order, _) => OrderCard(
          order: order,
          fmt: fmt,
          isDistributor: true,
          onUpdate: _load,
        ),
      )),
      ]),
    );
  }
}
