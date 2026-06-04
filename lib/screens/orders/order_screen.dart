import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/premium_icon_badge.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  static const _allCategories = 'Все';

  final _commentCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _repo = const DataRepository();
  late Future<OrderConfigData> _future = _repo.orderConfig();
  final Map<String, int> _qty = {};
  final Set<String> _stockWarnings = {};
  String _selectedCategory = _allCategories;
  String? _selectedStoreId;
  bool _sending = false;

  int get _totalQty => _qty.values.fold(0, (sum, value) => sum + value);

  @override
  void dispose() {
    _commentCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _ensureStore(OrderConfigData data) {
    _selectedStoreId ??= data.stores.isEmpty ? null : data.stores.first.id;
  }

  StoreData? _selectedStore(List<StoreData> stores) {
    for (final store in stores) {
      if (store.id == _selectedStoreId) return store;
    }
    return stores.isEmpty ? null : stores.first;
  }

  void _changeQty(ProductData product, int delta) {
    if (!_canOrder(product)) return;
    final current = _qty[product.id] ?? 0;
    final maxQty = product.quantity;
    final requested = current + delta;
    final next = requested.clamp(0, maxQty);
    setState(() {
      if (next == 0) {
        _qty.remove(product.id);
      } else {
        _qty[product.id] = next;
      }
      if (requested > maxQty) {
        _stockWarnings.add(product.id);
      } else if (next < maxQty) {
        _stockWarnings.remove(product.id);
      }
    });
  }

  bool _canOrder(ProductData product) {
    return product.status != StockStatus.outOfStock && product.quantity > 0;
  }

  List<String> _categories(List<ProductData> products) {
    final categories =
        products
            .map((item) => item.category.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return [_allCategories, ...categories];
  }

  List<ProductData> _filteredProducts(List<ProductData> products) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return products.where((item) {
      final inCategory =
          _selectedCategory == _allCategories ||
          item.category == _selectedCategory;
      final inSearch =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.sku.toLowerCase().contains(query) ||
          item.brand.toLowerCase().contains(query);
      return inCategory && inSearch;
    }).toList();
  }

  List<ProductData> _selectedProducts(List<ProductData> products) {
    return products.where((item) => (_qty[item.id] ?? 0) > 0).toList();
  }

  Future<void> _submit(OrderConfigData data) async {
    if (_selectedStoreId == null || _totalQty == 0) return;
    setState(() => _sending = true);
    try {
      await _repo.createOrder(
        storeId: _selectedStoreId!,
        comment: _commentCtrl.text,
        items: _qty.entries
            .map((entry) => {'productId': entry.key, 'quantity': entry.value})
            .toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ЗАКАЗ ОТПРАВЛЕН ДИСТРИБЬЮТОРУ'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().toUpperCase()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _refresh() async {
    final next = _repo.orderConfig();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ОФОРМЛЕНИЕ ЗАКАЗА')),
      body: FutureBuilder<OrderConfigData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }
          final data = snapshot.data!;
          _ensureStore(data);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _catalogCard(data.products),
                  const SizedBox(height: 16),
                  _selectedCard(data.products),
                  const SizedBox(height: 16),
                  _storesCard(data.stores),
                  const SizedBox(height: 16),
                  _requestForm(data),
                  const SizedBox(height: 16),
                  _distributorCard(data),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _distributorCard(OrderConfigData data) {
    final dist = data.distributor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const PremiumIconBadge(
              icon: Icons.store_sharp,
              size: 44,
              iconSize: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dist.name.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    dist.phone,
                    style: const TextStyle(
                      color: AppColors.brandRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'РЕГИОН',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storesCard(List<StoreData> stores) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'МАГАЗИН ВЫДАЧИ',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            if (stores.isEmpty)
              const Text(
                'МАГАЗИН ПОКА НЕ НАЗНАЧЕН. ЗАКАЗ УЙДЁТ ДИСТРИБЬЮТОРУ ДЛЯ УТОЧНЕНИЯ.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              )
            else if (stores.length == 1)
              _storeTile(stores.first, selected: true, onTap: null)
            else
              ...stores.map(
                (store) => _storeTile(
                  store,
                  selected: _selectedStoreId == store.id,
                  onTap: () => setState(() => _selectedStoreId = store.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _storeTile(
    StoreData store, {
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandBlack.withValues(alpha: 0.05)
              : Colors.white,
          border: Border.all(
            color: selected ? AppColors.brandBlack : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          children: [
            const PremiumIconBadge(
              icon: Icons.store_sharp,
              size: 40,
              iconSize: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  Text(
                    store.address,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_box_sharp, color: AppColors.brandBlack),
          ],
        ),
      ),
    );
  }

  Widget _requestForm(OrderConfigData data) {
    final disabled = _sending || _totalQty == 0 || _selectedStoreId == null;
    final store = _selectedStore(data.stores);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ОТПРАВКА ЗАКАЗА',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            Text(
              store == null
                  ? 'ВЫБЕРИТЕ ТОВАРЫ ДЛЯ ОФОРМЛЕНИЯ'
                  : 'ВЫБРАНО: ${store.name.toUpperCase()}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'КОММЕНТАРИЙ К ЗАКАЗУ',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 42),
                  child: Icon(Icons.comment_sharp),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: disabled ? null : () => _submit(data),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _totalQty == 0
                            ? 'ДОБАВЬТЕ ТОВАРЫ'
                            : 'ОТПРАВИТЬ ЗАКАЗ · $_totalQty ШТ.',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catalogCard(List<ProductData> products) {
    final categories = _categories(products);
    final filtered = _filteredProducts(products);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'АССОРТИМЕНТ',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'ПОИСК ПО КАТАЛОГУ',
                prefixIcon: Icon(Icons.search_sharp),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final selected = category == _selectedCategory;
                  return ChoiceChip(
                    label: Text(category.toUpperCase()),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = category),
                    selectedColor: AppColors.brandBlack,
                    backgroundColor: Colors.transparent,
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                      side: BorderSide(color: AppColors.brandBlack, width: 1.5),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            if (products.isEmpty)
              const Text(
                'КАТАЛОГ ПУСТ',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              )
            else if (filtered.isEmpty)
              const Text(
                'НИЧЕГО НЕ НАЙДЕНО',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              )
            else
              ...filtered.map(_productTile),
          ],
        ),
      ),
    );
  }

  Widget _productTile(ProductData item) {
    final qty = _qty[item.id] ?? 0;
    final canOrder = _canOrder(item);
    final showStockWarning =
        _stockWarnings.contains(item.id) || qty >= item.quantity;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: qty > 0
            ? AppColors.brandBlack.withValues(alpha: 0.04)
            : Colors.white,
        border: Border.all(
          color: qty > 0 ? AppColors.brandBlack : AppColors.border,
          width: qty > 0 ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumIconBadge(
                icon: Icons.inventory_2_sharp,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.category.toUpperCase()} · ${item.brand.toUpperCase()}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'SKU: ${item.sku}',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _stockPill(item.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${_formatVolume(item.volume)} Л',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_formatPrice(item.price)} ₽',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppColors.brandBlack,
                ),
              ),
              const Spacer(),
              if (!canOrder)
                SizedBox(
                  width: 128,
                  height: 36,
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    child: const Text('НЕТ В НАЛИЧИИ'),
                  ),
                )
              else if (qty == 0)
                SizedBox(
                  width: 128,
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => _changeQty(item, 1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_sharp, size: 18),
                        SizedBox(width: 6),
                        Text('ДОБАВИТЬ'),
                      ],
                    ),
                  ),
                )
              else
                _qtyStepper(item, qty),
            ],
          ),
          if (showStockWarning && canOrder) ...[
            const SizedBox(height: 8),
            Text(
              'ДОСТУПНО ТОЛЬКО ${item.quantity} ШТ.',
              style: const TextStyle(
                color: AppColors.brandRed,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _selectedCard(List<ProductData> products) {
    final selected = _selectedProducts(products);
    if (selected.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'В ЗАКАЗЕ',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
                ),
                const Spacer(),
                Text(
                  '$_totalQty ШТ.',
                  style: const TextStyle(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...selected.map((item) {
              final qty = _qty[item.id] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _qtyStepper(item, qty),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _stockPill(StockStatus status) {
    final color = switch (status) {
      StockStatus.inStock => AppColors.brandBlack,
      StockStatus.low => AppColors.warning,
      StockStatus.onOrder => AppColors.brandBlack,
      StockStatus.outOfStock => AppColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        _stockLabel(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _stockLabel(StockStatus status) {
    switch (status) {
      case StockStatus.inStock:
        return 'в наличии';
      case StockStatus.low:
        return 'мало';
      case StockStatus.onOrder:
        return 'под заказ';
      case StockStatus.outOfStock:
        return 'нет в наличии';
    }
  }

  String _formatVolume(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  Widget _qtyStepper(ProductData product, int qty) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.brandBlack, width: 1.5),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyButton(Icons.remove_sharp, qty == 0, () => _changeQty(product, -1)),
          SizedBox(
            width: 32,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          _qtyButton(
            Icons.add_sharp,
            qty >= product.quantity,
            () => _changeQty(product, 1),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, bool disabled, VoidCallback onTap) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        onPressed: disabled ? null : onTap,
        icon: Icon(icon, size: 18, color: disabled ? AppColors.textHint : AppColors.brandBlack),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }
}
