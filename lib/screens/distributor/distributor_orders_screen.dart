import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../purchases/purchases_screen.dart';

class DistributorOrdersScreen extends StatefulWidget {
  const DistributorOrdersScreen({super.key});

  @override
  State<DistributorOrdersScreen> createState() => _DistributorOrdersScreenState();
}

class _DistributorOrdersScreenState extends State<DistributorOrdersScreen> {
  late final PaginationController<Order> _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<Order>(
      fetchPage: (page) => DataRepository().distributorOrders(page: page),
    );
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
      body: PaginatedListView<Order>(
        controller: _controller,
        emptyBuilder: Column(
          children: const [
            PremiumIconBadge(
              icon: Icons.shopping_bag_outlined,
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
      ),
    );
  }
}
