import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/premium_icon_badge.dart';

class OrderScreen extends StatefulWidget {
  final DataRepository? repository;
  final Order? initialOrder;
  const OrderScreen({super.key, this.repository, this.initialOrder});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  static const _allCategories = 'Все';

  final _commentCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  late final DataRepository _repo;
  late Future<OrderConfigData> _future;
  final Map<String, int> _qty = {};
  final Set<String> _stockWarnings = {};
  String _selectedCategory = _allCategories;
  String? _selectedStoreId;
  String _deliveryMethod = 'courier';
  bool _sending = false;

  // Baseline for change tracking
  Map<String, int>? _initialQty;
  String? _initialComment;
  String? _initialStoreId;
  String? _initialDeliveryMethod;

  int get _totalQty => _qty.values.fold(0, (sum, value) => sum + value);

  bool get _hasChanges {
    if (widget.initialOrder == null) return _totalQty > 0;
    
    // Compare quantities
    if (_initialQty == null) return false;
    if (_qty.length != _initialQty!.length) return true;
    for (final entry in _qty.entries) {
      if (_initialQty![entry.key] != entry.value) return true;
    }

    // Compare fields
    if (_commentCtrl.text != (_initialComment ?? '')) return true;
    if (_selectedStoreId != _initialStoreId) return true;
    if (_deliveryMethod != _initialDeliveryMethod) return true;

    return false;
  }

  double _totalAmount(List<ProductData> products) {
    double total = 0;
    _qty.forEach((id, count) {
      final product = products.firstWhere((p) => p.id == id, orElse: () => products.first);
      total += product.price * count;
    });
    return total;
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DataRepository();
    _future = _repo.orderConfig();

    if (widget.initialOrder != null) {
      _commentCtrl.text = widget.initialOrder!.comment ?? '';
      _deliveryMethod = widget.initialOrder!.deliveryMethod;
    }
    
    // Listen to comments to track changes in real-time
    _commentCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _ensureStore(OrderConfigData data) {
    if (_selectedStoreId == null && widget.initialOrder != null) {
      // Find matching store by name/address if possible, or ID
      final matching = data.stores.where((s) => s.name == widget.initialOrder!.storeName).firstOrNull;
      if (matching != null) {
        _selectedStoreId = matching.id;
      }
    }
    _selectedStoreId ??= data.stores.isEmpty ? null : data.stores.first.id;

    // One-time population of quantities from initialOrder
    if (widget.initialOrder != null && _initialQty == null && data.products.isNotEmpty) {
      for (final item in widget.initialOrder!.items) {
        // Find matching product in catalog by SKU
        final p = data.products.where((x) => x.sku == item.sku).firstOrNull;
        if (p != null) {
          _qty[p.id] = item.quantity;
        }
      }
      
      // Capture baseline for change tracking
      _initialQty = Map.from(_qty);
      _initialComment = _commentCtrl.text;
      _initialStoreId = _selectedStoreId;
      _initialDeliveryMethod = _deliveryMethod;
    }
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
    
    // If onOrder and quantity is 0, allow ordering without a hard limit
    // If status is inStock/low, limit by current quantity
    final isUnlimited = product.status == StockStatus.onOrder && product.quantity == 0;
    final maxQty = isUnlimited ? 999 : product.quantity;
    
    final requested = current + delta;
    final next = requested.clamp(0, maxQty);
    setState(() {
      if (next == 0) {
        _qty.remove(product.id);
      } else {
        _qty[product.id] = next;
      }
      if (!isUnlimited && requested > maxQty) {
        _stockWarnings.add(product.id);
      } else if (isUnlimited || next < maxQty) {
        _stockWarnings.remove(product.id);
      }
    });
  }

  bool _canOrder(ProductData product) {
    if (product.status == StockStatus.outOfStock) return false;
    // If quantity is 0, only allow if explicitly 'onOrder'
    if (product.quantity <= 0 && product.status != StockStatus.onOrder) return false;
    return true;
  }

  List<String> _categories(List<ProductData> products) {
    final categories = products
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
      final inCategory = _selectedCategory == _allCategories || item.category == _selectedCategory;
      final inSearch = query.isEmpty ||
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
    if (_totalQty == 0) return;
    if (data.stores.isNotEmpty && _selectedStoreId == null) {
      final msg = _deliveryMethod == 'courier' ? 'Выберите адрес для доставки' : 'Выберите магазин для самовывоза';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    setState(() => _sending = true);
    try {
      if (widget.initialOrder != null) {
        await _repo.cancelOrder(widget.initialOrder!.id);
      }

      await _repo.createOrder(
        storeId: _selectedStoreId,
        deliveryMethod: _deliveryMethod,
        comment: _commentCtrl.text,
        items: _qty.entries.map((entry) => {'productId': entry.key, 'quantity': entry.value}).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.initialOrder != null ? 'Заказ обновлен' : 'Заказ отправлен дистрибьютору'),
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

  Future<void> _handleCancel() async {
    if (widget.initialOrder == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить заказ?'),
        content: const Text('Заказ будет аннулирован, товары вернутся на склад.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('НЕТ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('ОТМЕНИТЬ ЗАКАЗ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _sending = true);
    try {
      await _repo.cancelOrder(widget.initialOrder!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказ отменен'), backgroundColor: AppColors.info),
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
      appBar: AppBar(title: Text(widget.initialOrder != null ? 'Изменение заказа' : 'Оформление заказа')),
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
                  _deliveryMethodCard(data),
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

  Widget _deliveryMethodCard(OrderConfigData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Способ получения',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _methodBtn('courier', 'ДОСТАВКА', Icons.local_shipping_outlined),
                const SizedBox(width: 12),
                _methodBtn('self_pickup', 'САМОВЫВОЗ', Icons.storefront_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodBtn(String value, String label, IconData icon) {
    final active = _deliveryMethod == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _deliveryMethod = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active ? AppColors.brandBlack : Colors.white,
            border: Border.all(color: AppColors.brandBlack),
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? Colors.white : AppColors.brandBlack, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.brandBlack,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
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
    final isCourier = _deliveryMethod == 'courier';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCourier ? 'Адрес доставки' : 'Ваш магазин / Объект',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            if (stores.isEmpty)
              Text(
                isCourier 
                  ? 'У вас не добавлены магазины/адреса. Добавьте их в профиле, чтобы указать точку доставки.'
                  : 'Магазин пока не назначен. Заказ уйдёт дистрибьютору, он уточнит выдачу.',
                style: const TextStyle(color: AppColors.textSecondary),
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
          color: selected ? AppColors.brandRed.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: selected ? AppColors.brandRed : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.zero,
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
            if (selected) const Icon(Icons.check_circle, color: AppColors.brandRed),
          ],
        ),
      ),
    );
  }

  Widget _requestForm(OrderConfigData data) {
    final disabled = _sending || !_hasChanges || _totalQty == 0 || (data.stores.isNotEmpty && _selectedStoreId == null);
    final store = _selectedStore(data.stores);
    final totalAmount = _totalAmount(data.products);

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
              _deliveryMethod == 'courier'
                  ? (store == null ? 'Укажите адрес для курьера.' : 'Доставка на адрес: ${store.address}')
                  : (store == null ? 'Выберите ваш объект для оформления.' : 'Заказ для объекта: ${store.name}'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
            if (widget.initialOrder != null)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _sending ? null : _handleCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        child: const Text('ОТМЕНИТЬ ЗАКАЗ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: disabled ? null : () => _submit(data),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('ПОДТВЕРДИТЬ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                      ),
                    ),
                  ),
                ],
              )
            else
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
                          _totalQty == 0 ? 'Добавьте товар' : 'Отправить дистрибьютору · ${totalAmount.toStringAsFixed(0)} ₽',
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
                    onSelected: (_) => setState(() => _selectedCategory = category),
                    selectedColor: AppColors.brandRed.withValues(alpha: 0.14),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.brandRed : AppColors.textPrimary,
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
    final effectiveRemaining = item.quantity - qty;
    final showStockWarning = _stockWarnings.contains(item.id) || (item.quantity > 0 && qty >= item.quantity);

    String stockStatusText;
    Color stockColor;
    if (effectiveRemaining > 5) {
      stockStatusText = 'В НАЛИЧИИ';
      stockColor = AppColors.success;
    } else if (effectiveRemaining > 0) {
      stockStatusText = 'МАЛО';
      stockColor = AppColors.warning;
    } else if (item.status == StockStatus.onOrder) {
      stockStatusText = 'ПОД ЗАКАЗ';
      stockColor = AppColors.textHint;
    } else {
      stockStatusText = 'НЕТ В НАЛИЧИИ';
      stockColor = AppColors.error;
    }

    final isOutOfStock = !canOrder && qty == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ShapeDecoration(
        color: isOutOfStock 
            ? AppColors.border.withValues(alpha: 0.2) 
            : (qty > 0 ? const Color(0xFFF01D2C).withValues(alpha: 0.05) : Colors.white),
        shape: BeveledRectangleBorder(
          side: BorderSide(
            color: isOutOfStock ? AppColors.border : (qty > 0 ? const Color(0xFFF01D2C) : AppColors.border)
          ),
          borderRadius: BorderRadius.zero,
        ),
      ),
      child: Opacity(
        opacity: isOutOfStock ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.brand} · ${item.sku}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: ShapeDecoration(
                      color: stockColor.withValues(alpha: 0.1),
                      shape: const BeveledRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(5))),
                    ),
                    child: Text(
                      stockStatusText,
                      style: TextStyle(color: stockColor, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '${_formatPrice(item.price)} ₽',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF171717)),
                  ),
                  const Spacer(),
                  if (isOutOfStock)
                    const SizedBox(height: 36) // Empty space instead of the button
                  else if (qty == 0)
                    ElevatedButton(
                      onPressed: () => _changeQty(item, 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF171717),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(100, 36),
                      ),
                      child: const Text('ДОБАВИТЬ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _qtyStepper(item, qty),
                        if (!canOrder)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('БОЛЬШЕ НЕТ', style: TextStyle(color: AppColors.error, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                ],
              ),
              if (showStockWarning && canOrder && item.quantity > 0) ...[
                const SizedBox(height: 8),
                const Text(
                  'ДОСТИГНУТ МАКСИМАЛЬНЫЙ ОСТАТОК',
                  style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ],
            ],
          ),
        ),
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

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  Widget _qtyStepper(ProductData product, int qty) {
    final isUnlimited = product.status == StockStatus.onOrder && product.quantity == 0;
    final reachedLimit = !isUnlimited && qty >= product.quantity;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.zero,
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
            reachedLimit,
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

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
