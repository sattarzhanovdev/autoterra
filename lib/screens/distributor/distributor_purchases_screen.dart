import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../purchases/purchases_screen.dart';

class DistributorPurchasesScreen extends StatefulWidget {
  const DistributorPurchasesScreen({super.key});

  @override
  State<DistributorPurchasesScreen> createState() => _DistributorPurchasesScreenState();
}

class _DistributorPurchasesScreenState extends State<DistributorPurchasesScreen> {
  List<Purchase> _purchases = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final purchases = await DataRepository().distributorPurchases(toVerify: true);
      if (mounted) {
        setState(() {
          _purchases = purchases;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ru_RU');

    return Scaffold(
      appBar: AppBar(title: const Text('ПРОВЕРКА ПОКУПОК')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('ПОВТОРИТЬ')),
                    ],
                  ),
                )
              : _buildList(fmt),
    );
  }

  Widget _buildList(NumberFormat fmt) {
    if (_purchases.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 180),
            Center(
              child: Column(
                children: [
                  const PremiumIconBadge(
                    icon: Icons.verified_outlined,
                    size: 56,
                    iconSize: 28,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Все покупки проверены',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _purchases.length,
        itemBuilder: (context, i) => PurchaseCard(
          purchase: _purchases[i],
          fmt: fmt,
          isDistributor: true,
          onUpdate: _load,
        ),
      ),
    );
  }
}
