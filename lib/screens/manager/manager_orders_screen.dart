import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';

class ManagerOrdersScreen extends StatefulWidget {
  final String? statusFilter;
  const ManagerOrdersScreen({super.key, this.statusFilter});
  @override
  State<ManagerOrdersScreen> createState() => _ManagerOrdersScreenState();
}

class _ManagerOrdersScreenState extends State<ManagerOrdersScreen> {
  final _repo = DataRepository();
  late final PaginationController<Order> _controller;
  @override
  void initState() {
    super.initState();
    _controller = PaginationController<Order>(fetchPage: (page) => _repo.managerOrders(page: page, status: widget.statusFilter));
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.statusFilter == 'active' ? 'АКТИВНЫЕ ЗАКАЗЫ' : 'ЗАКАЗЫ'),
      actions: [IconButton(onPressed: _controller.refresh, icon: const Icon(Icons.refresh))]),
    body: PaginatedListView<Order>(controller: _controller, emptyMessage: 'ЗАКАЗОВ НЕТ',
      itemBuilder: (_, order, _) => Card(child: ListTile(
        title: Text('${order.documentNumber} · ${order.clientName ?? ''}'),
        subtitle: Text('${DateFormat('dd.MM.yyyy').format(order.date)} · ${order.status.name} · ${order.totalAmount.toStringAsFixed(2)} ₽'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/manager/orders/${order.id}'),
      ))),
  );
}

class ManagerOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const ManagerOrderDetailScreen({super.key, required this.orderId});
  @override
  State<ManagerOrderDetailScreen> createState() => _ManagerOrderDetailScreenState();
}

class _ManagerOrderDetailScreenState extends State<ManagerOrderDetailScreen> {
  final _repo = DataRepository();
  late Future<Order> _future;
  @override
  void initState() { super.initState(); _future = _repo.orderDetail(widget.orderId); }
  void _reload() => setState(() => _future = _repo.orderDetail(widget.orderId));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.brandWhite,
    appBar: AppBar(title: const Text('СОСТАВ ЗАКАЗА'), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<Order>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) { return const Center(child: CircularProgressIndicator()); }
      if (snapshot.hasError) { return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Ошибка: ${snapshot.error}'), TextButton(onPressed: _reload, child: const Text('ПОВТОРИТЬ')),
      ])); }
      final order = snapshot.data!;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text(order.documentNumber, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Text('Клиент: ${order.clientName ?? '—'}'),
        Text('Статус: ${order.status.name}'),
        Text('Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt)}'),
        Text('Сумма: ${order.totalAmount.toStringAsFixed(2)} ₽'),
        const Divider(),
        const Text('ПОЗИЦИИ', style: TextStyle(fontWeight: FontWeight.w900)),
        if (order.items.isEmpty) const Text('Позиций нет'),
        for (final item in order.items) ListTile(
          title: Text(item.name), subtitle: Text('Артикул: ${item.sku} · ${item.quantity} шт.'),
          trailing: Text('${item.total.toStringAsFixed(2)} ₽'),
        ),
      ]);
    }),
  );
}
