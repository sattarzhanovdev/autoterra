import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';

class DistributorReportsScreen extends StatefulWidget {
  const DistributorReportsScreen({super.key});
  @override
  State<DistributorReportsScreen> createState() => _DistributorReportsScreenState();
}

class _DistributorReportsScreenState extends State<DistributorReportsScreen> {
  late Future<Map<String, dynamic>> _report;
  @override
  void initState() { super.initState(); _report = ApiClient().distributorReports(); }
  void _refresh() => setState(() => _report = ApiClient().distributorReports());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ОТЧЁТЫ'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<Map<String, dynamic>>(future: _report, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Не удалось загрузить отчёт: ${snapshot.error}'), TextButton(onPressed: _refresh, child: const Text('ПОВТОРИТЬ'))]));
      final data = snapshot.data;
      if (data == null) return const Center(child: CircularProgressIndicator());
      return ListView(padding: const EdgeInsets.all(16), children: [
        for (final e in const {'clients':'Клиенты', 'orders':'Все заказы', 'newOrders':'Новые заказы', 'paidOrders':'Оплаченные заказы', 'turnover':'Оборот по оплаченным заказам, ₽', 'products':'Товары', 'stockQuantity':'Остаток, шт.', 'pendingPurchases':'Покупки на проверке'}.entries)
          Card(child: ListTile(title: Text(e.value), trailing: Text(NumberFormat('#,##0.##', 'ru_RU').format(data[e.key] ?? 0)))),
      ]);
    }),
  );
}
