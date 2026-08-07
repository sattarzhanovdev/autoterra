import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/common/product_photo.dart';

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

  /// Выбранные товары целиком. Каталог листается страницами, и товар из
  /// корзины может быть уже не загружен — считать сумму и показывать состав
  /// по текущей странице нельзя.
  final Map<String, ProductData> _selected = {};

  final Set<String> _stockWarnings = {};

  /// Лента каталога. Фильтры применяет сервер.
  late final PaginationController<ProductData> _catalog;
  String _search = '';
  String? _brandFilter;
  bool _inStockOnly = false;

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

  double get _totalAmount {
    var total = 0.0;
    _qty.forEach((id, count) {
      final product = _selected[id];
      if (product != null) total += product.price * count;
    });
    return total;
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DataRepository();
    _future = _repo.orderConfig();
    _catalog = PaginationController<ProductData>(
      fetchPage: (page) => _repo.products(
        page: page,
        search: _search.isEmpty ? null : _search,
        category: _selectedCategory == _allCategories ? null : _selectedCategory,
        brand: _brandFilter,
        inStockOnly: _inStockOnly,
      ),
    );
    _catalog.loadInitial();

    if (widget.initialOrder != null) {
      _commentCtrl.text = widget.initialOrder!.comment ?? '';
      _deliveryMethod = widget.initialOrder!.deliveryMethod;
      _prefillFromOrder(widget.initialOrder!);
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
    _catalog.dispose();
    super.dispose();
  }

  /// Восстанавливает корзину из редактируемого заказа. Раньше позиции искались
  /// по SKU в полном каталоге — с постраничной загрузкой его больше нет,
  /// поэтому берём данные прямо из позиций заказа.
  void _prefillFromOrder(Order order) {
    for (final item in order.items) {
      final productId = item.productId;
      if (productId == null) continue;
      _qty[productId] = item.quantity;
      _selected[productId] = ProductData(
        id: productId,
        distributorId: order.distributorId,
        sku: item.sku,
        name: item.name,
        category: item.category,
        brand: item.brand,
        volume: item.volume,
        price: item.price,
        quantity: item.availableQuantity ?? item.quantity,
        status: StockStatus.inStock,
        updatedAt: DateTime.now(),
      );
    }
    _initialQty = Map.from(_qty);
    _initialComment = _commentCtrl.text;
    _initialDeliveryMethod = _deliveryMethod;
  }

  void _applyFilters() {
    _catalog.setFilters(() {});
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
    _initialStoreId ??= _selectedStoreId;
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
        _selected.remove(product.id);
      } else {
        _qty[product.id] = next;
        _selected[product.id] = product;
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

  List<ProductData> get _selectedProducts {
    return _qty.keys
        .map((id) => _selected[id])
        .whereType<ProductData>()
        .toList();
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
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Каталог: шапка с фильтрами
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(child: _catalogHeader(data)),
                ),
                // Каталог: виртуализированный список товаров
                _catalogSliverList(),
                // Остальные карточки
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 2),
                      _catalogFooter(),
                      const SizedBox(height: 16),
                      _selectedCard(),
                      const SizedBox(height: 16),
                      _deliveryMethodCard(data),
                      const SizedBox(height: 16),
                      _storesCard(data.stores),
                      const SizedBox(height: 16),
                      _requestForm(data),
                      const SizedBox(height: 16),
                      _distributorCard(data),
                    ]),
                  ),
                ),
              ],
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

  /// Сколько бонусов закроет собираемый заказ.
  ///
  /// Именно прикидка, а не списание: бонус уходит со счёта на шаге оплаты, а
  /// до неё дистрибьютор ещё может скорректировать состав заказа. Обещать
  /// точную сумму здесь нельзя — но и молчать про бонусы до самой оплаты тоже.
  Widget _bonusPreview(double balance, double totalAmount) {
    final fmt = NumberFormat('#,##0', 'ru_RU');
    final covers = balance < totalAmount ? balance : totalAmount;
    final rest = totalAmount - covers;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined, size: 18, color: AppColors.brandRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Бонусов на счёте: ${fmt.format(balance)} ₽',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Спишется с этого заказа',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('−${fmt.format(covers)} ₽',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.brandRed)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('К оплате', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('${fmt.format(rest)} ₽',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Списание произойдёт при оплате — сумму можно будет уменьшить.',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _requestForm(OrderConfigData data) {
    final disabled = _sending || !_hasChanges || _totalQty == 0 || (data.stores.isNotEmpty && _selectedStoreId == null);
    final store = _selectedStore(data.stores);
    final totalAmount = _totalAmount;

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
            if (data.bonusBalance > 0 && totalAmount > 0) ...[
              const SizedBox(height: 16),
              _bonusPreview(data.bonusBalance, totalAmount),
            ],
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

  /// Шапка каталога: заголовок, поиск, фильтры. Рисуется в SliverToBoxAdapter,
  /// чтобы товары ниже могли идти через SliverList.builder (виртуализация).
  Widget _catalogHeader(OrderConfigData data) {
    final categories = [_allCategories, ...data.categories];

    return Card(
      margin: EdgeInsets.zero,
      // Верхняя половина составной формы (гайдбук, стр. 16).
      shape: BeveledRectangleBorder(
        borderRadius: AppShapes.cut(AppShapes.chamferMd),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ассортимент',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Найдите товар, нажмите "Добавить" и укажите количество',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: (value) {
                _search = value.trim();
                // Дебаунс: запрос уходит на сервер, а не фильтрует страницу.
                _catalog.refreshDebounced();
              },
              decoration: InputDecoration(
                hintText: 'Поиск по названию, артикулу или бренду',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search = '';
                          _applyFilters();
                        },
                      ),
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
                    onSelected: (_) {
                      setState(() => _selectedCategory = category);
                      _applyFilters();
                    },
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _brandFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Бренд',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Все бренды')),
                      ...data.brands.map(
                        (brand) => DropdownMenuItem<String?>(value: brand, child: Text(brand)),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _brandFilter = value);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('В наличии'),
                  selected: _inStockOnly,
                  onSelected: (value) {
                    setState(() => _inStockOnly = value);
                    _applyFilters();
                  },
                  selectedColor: AppColors.brandRed.withValues(alpha: 0.14),
                  labelStyle: TextStyle(
                    color: _inStockOnly ? AppColors.brandRed : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: _inStockOnly ? AppColors.brandRed : AppColors.border,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  /// Виртуализированный список товаров каталога. Используется SliverList.builder,
  /// который создаёт виджеты только для видимых элементов — без лагов при
  /// накоплении страниц.
  Widget _catalogSliverList() {
    return ListenableBuilder(
      listenable: _catalog,
      builder: (context, _) {
        // Загрузка
        if (_catalog.isLoading && _catalog.items.isEmpty) {
          return const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(color: AppColors.brandRed)),
              ),
            ),
          );
        }

        // Ошибка
        if (_catalog.error != null && _catalog.items.isEmpty) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Text(
                    _catalog.error!.toString(),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _catalog.refresh,
                    child: const Text('ПОВТОРИТЬ'),
                  ),
                ],
              ),
            ),
          );
        }

        // Пусто
        if (_catalog.isEmpty) {
          return const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Ничего не найдено',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          );
        }

        // Виртуализированный список товаров
        final items = _catalog.items;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => _productTile(items[index]),
          ),
        );
      },
    );
  }

  /// Футер каталога: кнопка «показать ещё» и закрытие карточки.
  Widget _catalogFooter() {
    return ListenableBuilder(
      listenable: _catalog,
      builder: (context, _) {
        if (_catalog.items.isEmpty) return const SizedBox.shrink();

        return Card(
          margin: EdgeInsets.zero,
          // Ответная нижняя половина — срез уходит в другой угол.
          shape: BeveledRectangleBorder(
            borderRadius: AppShapes.cutPaired(AppShapes.chamferMd),
          ),
          child: _catalog.hasMore
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: _catalog.isLoadingMore
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: AppColors.brandRed,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: _catalog.loadMore,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brandRed,
                            side: const BorderSide(color: AppColors.brandRed),
                          ),
                          child: Text(
                            'ПОКАЗАТЬ ЕЩЁ (${_catalog.items.length} ИЗ ${_catalog.totalCount})',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ),
                )
              : const SizedBox(height: 4),
        );
      },
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
            : (qty > 0 ? AppColors.brandRed.withValues(alpha: 0.05) : Colors.white),
        shape: BeveledRectangleBorder(
          side: BorderSide(
            color: isOutOfStock ? AppColors.border : (qty > 0 ? AppColors.brandRed : AppColors.border)
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
                  // Фото товара: ссылки приходят из карточки ассортимента,
                  // по нажатию открывается галерея (до 15 кадров).
                  ProductThumb(
                    images: item.images,
                    size: 64,
                    onTap: () => showProductGallery(
                      context,
                      images: item.images,
                      title: item.name,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.brandBlack),
                  ),
                  const Spacer(),
                  if (isOutOfStock)
                    const SizedBox(height: 36) // Empty space instead of the button
                  else if (qty == 0)
                    ElevatedButton(
                      onPressed: () => _changeQty(item, 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBlack,
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

  Widget _selectedCard() {
    final selected = _selectedProducts;
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
                    ProductThumb(
                      images: item.images,
                      size: 36,
                      onTap: () => showProductGallery(
                        context,
                        images: item.images,
                        title: item.name,
                      ),
                    ),
                    const SizedBox(width: 8),
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
