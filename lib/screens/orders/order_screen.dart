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
          content: Text('Заказ отправлен дистрибьютору'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
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
      appBar: AppBar(title: const Text('Заказ')),
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
              icon: Icons.store_rounded,
              size: 44,
              iconSize: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dist.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    dist.phone,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'По региону',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
              'Магазин выдачи',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            if (stores.isEmpty)
              const Text(
                'Магазин пока не назначен. Заказ уйдёт дистрибьютору, он уточнит выдачу.',
                style: TextStyle(color: AppColors.textSecondary),
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
              ? AppColors.brandRed.withValues(alpha: 0.05)
              : Colors.white,
          border: Border.all(
            color: selected ? AppColors.brandRed : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const PremiumIconBadge(
              icon: Icons.store_rounded,
              size: 40,
              iconSize: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    store.address,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.brandRed),
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
              'Отправка заказа',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              store == null
                  ? 'Выберите товары. Дистрибьютор уточнит выдачу.'
                  : 'Выбрано: ${store.name}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Комментарий, если нужно',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 42),
                  child: Icon(Icons.comment_outlined),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
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
                            ? 'Добавьте товар'
                            : 'Отправить дистрибьютору · $_totalQty шт.',
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
              'Ассортимент',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Найдите товар, нажмите “Добавить” и укажите количество',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Поиск по названию, артикулу или бренду',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final selected = category == _selectedCategory;
                  return ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = category),
                    selectedColor: AppColors.brandRed.withValues(alpha: 0.14),
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.brandRed
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: selected ? AppColors.brandRed : AppColors.border,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            if (products.isEmpty)
              const Text(
                'Ассортимент пока не заполнен',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else if (filtered.isEmpty)
              const Text(
                'Ничего не найдено',
                style: TextStyle(color: AppColors.textSecondary),
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
            ? AppColors.brandRed.withValues(alpha: 0.04)
            : Colors.white,
        border: Border.all(
          color: qty > 0 ? AppColors.brandRed : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumIconBadge(
                icon: Icons.inventory_2_outlined,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.category} · ${item.brand}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Артикул: ${item.sku}',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 11,
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
                '${_formatVolume(item.volume)} л',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_formatPrice(item.price)} ₽',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
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
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text(
                      'Нет в наличии',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Добавить',
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ),
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
              'Доступно только ${item.quantity} шт. Больше остатка заказать нельзя.',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
                  'В заказе',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  '$_totalQty шт.',
                  style: const TextStyle(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w800,
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
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
      StockStatus.inStock => AppColors.success,
      StockStatus.low => AppColors.warning,
      StockStatus.onOrder => AppColors.info,
      StockStatus.outOfStock => AppColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _stockLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
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
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyButton(Icons.remove, qty == 0, () => _changeQty(product, -1)),
          SizedBox(
            width: 32,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          _qtyButton(
            Icons.add,
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
        icon: Icon(icon, size: 18),
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
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
