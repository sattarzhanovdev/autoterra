import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../purchases/purchases_screen.dart';

class DistributorPurchasesScreen extends StatefulWidget {
  const DistributorPurchasesScreen({super.key});

  @override
  State<DistributorPurchasesScreen> createState() => _DistributorPurchasesScreenState();
}

class _DistributorPurchasesScreenState extends State<DistributorPurchasesScreen> {
  late final PaginationController<Purchase> _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<Purchase>(
      fetchPage: (page) =>
          DataRepository().distributorPurchases(page: page, toVerify: true),
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
      appBar: AppBar(title: const Text('ПРОВЕРКА ПОКУПОК')),
      body: PaginatedListView<Purchase>(
        controller: _controller,
        emptyBuilder: Column(
          children: const [
            PremiumIconBadge(
              icon: Icons.verified_outlined,
              size: 56,
              iconSize: 28,
            ),
            SizedBox(height: 16),
            Text(
              'Все покупки проверены',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        itemBuilder: (context, purchase, _) => PurchaseCard(
          purchase: purchase,
          fmt: fmt,
          isDistributor: true,
          onUpdate: _load,
        ),
      ),
    );
  }
}
