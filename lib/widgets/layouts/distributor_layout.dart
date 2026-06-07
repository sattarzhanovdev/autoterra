import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../screens/distributor/distributor_clients_screen.dart';

class DistributorLayout extends StatefulWidget {
  final Widget child;
  const DistributorLayout({super.key, required this.child});

  @override
  State<DistributorLayout> createState() => _DistributorLayoutState();
}

class _DistributorLayoutState extends State<DistributorLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DistributorOrdersTabsScreen(),
    const DistributorClientsScreen(),
    const _PlaceholderScreen(title: 'СКЛАД'),
    const DistributorReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF171717), width: 2)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF171717),
          selectedItemColor: const Color(0xFFF01D2C),
          unselectedItemColor: Colors.white.withValues(alpha: 0.5),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'ЗАКАЗЫ'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'КЛИЕНТЫ'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'СКЛАД'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'ОТЧЕТЫ'),
          ],
        ),
      ),
    );
  }
}

class DistributorOrdersTabsScreen extends StatelessWidget {
  const DistributorOrdersTabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF171717),
          title: const Text('УПРАВЛЕНИЕ ЗАКАЗАМИ', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w900)),
          bottom: const TabBar(
            indicatorColor: Color(0xFFF01D2C),
            indicatorWeight: 4,
            labelColor: Color(0xFFF01D2C),
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'ПОКУПКИ (ЧЕКИ)'),
              Tab(text: 'ЗАКАЗЫ (НОВЫЕ)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const DistributorPurchasesList(),
            const DistributorOrdersList(),
          ],
        ),
      ),
    );
  }
}

class DistributorPurchasesList extends StatefulWidget {
  const DistributorPurchasesList({super.key});

  @override
  State<DistributorPurchasesList> createState() => _DistributorPurchasesListState();
}

class _DistributorPurchasesListState extends State<DistributorPurchasesList> {
  final DataRepository _repo = DataRepository();
  List<Purchase> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.distributorPurchases();
      setState(() { _items = data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFFF01D2C)));
    if (_items.isEmpty) return const Center(child: Text('НЕТ НОВЫХ ПОКУПОК'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PurchaseVerificationCard(purchase: _items[index], onUpdate: _fetch),
      ),
    );
  }
}

class PurchaseVerificationCard extends StatelessWidget {
  final Purchase purchase;
  final VoidCallback onUpdate;

  const PurchaseVerificationCard({super.key, required this.purchase, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: Color(0xFF171717), width: 1),
          borderRadius: BorderRadius.zero,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(purchase.documentNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF01D2C))),
              Text('${purchase.totalAmount} ₽', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          Text(purchase.clientName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          const Divider(),
          ...purchase.items.map((it) => Text('• ${it.name} x ${it.quantity}', style: const TextStyle(fontSize: 12))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handle(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: const BeveledRectangleBorder(),
                  ),
                  child: const Text('ПОДТВЕРДИТЬ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handle(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF01D2C),
                    side: const BorderSide(color: Color(0xFFF01D2C)),
                    shape: const BeveledRectangleBorder(),
                  ),
                  child: const Text('ОТКЛОНИТЬ'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _handle(BuildContext context, bool verify) async {
    String? reason;
    if (!verify) {
      reason = await _showReasonDialog(context);
      if (reason == null) return;
    }
    try {
      await DataRepository().verifyPurchase(purchase.id, verify: verify, reason: reason);
      onUpdate();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<String?> _showReasonDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const BeveledRectangleBorder(),
        title: const Text('ПРИЧИНА ОТКЛОНЕНИЯ'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Укажите причину')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ОТМЕНА')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('ОТКЛОНИТЬ')),
        ],
      ),
    );
  }
}

class DistributorOrdersList extends StatefulWidget {
  const DistributorOrdersList({super.key});

  @override
  State<DistributorOrdersList> createState() => _DistributorOrdersListState();
}

class _DistributorOrdersListState extends State<DistributorOrdersList> {
  final DataRepository _repo = DataRepository();
  List<Order> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.distributorOrders();
      setState(() { _items = data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFFF01D2C)));
    if (_items.isEmpty) return const Center(child: Text('НЕТ НОВЫХ ЗАКАЗОВ'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OrderProcessCard(order: _items[index], onUpdate: _fetch),
      ),
    );
  }
}

class OrderProcessCard extends StatelessWidget {
  final Order order;
  final VoidCallback onUpdate;

  const OrderProcessCard({super.key, required this.order, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: Color(0xFF171717), width: 1),
          borderRadius: BorderRadius.zero,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ЗАКАЗ #${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF01D2C))),
              Text('${order.totalAmount} ₽', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          Text(order.clientName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          if (order.storeName.isNotEmpty)
            Text('ВЫДАЧА: ${order.storeName.toUpperCase()}', style: const TextStyle(color: Color(0xFF171717), fontSize: 10, fontWeight: FontWeight.bold)),
          const Divider(),
          ...order.items.map((it) => Text('• ${it.name} x ${it.quantity}', style: const TextStyle(fontSize: 12))),
          const SizedBox(height: 16),
          Row(
            children: [
              if (order.status == OrderStatus.newOrder) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(context, 'accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: const BeveledRectangleBorder(),
                    ),
                    child: const Text('ПРИНЯТЬ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus(context, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF01D2C),
                      side: const BorderSide(color: Color(0xFFF01D2C)),
                      shape: const BeveledRectangleBorder(),
                    ),
                    child: const Text('ОТКЛОНИТЬ'),
                  ),
                ),
              ],
              if (order.status == OrderStatus.accepted)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(context, 'fulfilled'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF01D2C),
                      shape: const BeveledRectangleBorder(),
                    ),
                    child: const Text('ВЫПОЛНЕНО'),
                  ),
                ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    try {
      await DataRepository().updateOrderStatus(order.id, status: status);
      onUpdate();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }
}

class DistributorReportsScreen extends StatelessWidget {
  const DistributorReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        title: const Text('ОТЧЕТЫ И ЭКСПОРТ', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _reportCard(
            context,
            'ОТЧЕТ ПО ПРОДАЖАМ (EXCEL)',
            'Выгрузка всех подтвержденных покупок и заказов за все время.',
            Icons.file_download_outlined,
            () => DataRepository().downloadReport(),
          ),
          const SizedBox(height: 16),
          _reportCard(
            context,
            'АКТИВНОСТЬ КЛИЕНТОВ',
            'Статистика по регистрациям и обороту в вашем регионе.',
            Icons.analytics_outlined,
            null,
          ),
        ],
      ),
    );
  }

  Widget _reportCard(BuildContext context, String title, String desc, IconData icon, VoidCallback? onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: AppColors.brandRed, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        onTap: onTap,
        trailing: onTap != null ? const Icon(Icons.chevron_right) : const Text('СКОРО', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textHint)),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: Text(title)),
      body: Center(child: Text('РАЗДЕЛ $title В РАЗРАБОТКЕ')),
    );
  }
}
