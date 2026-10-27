import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/common/product_photo.dart';
import '../../widgets/common/shop_sale_price.dart';
import '../../widgets/common/client_product_price.dart';
import '../../widgets/common/order_discount_summary.dart';

class OrderScreen extends StatefulWidget {
  final DataRepository? repository;
  final Order? initialOrder;
  const OrderScreen({super.key, this.repository, this.initialOrder});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> with WidgetsBindingObserver {
  Timer? _priceTimer;
  Timer? _catalogTimer;
  bool _refreshingCatalog = false;
  bool _batchingPrices = false;
  String? _lastCatalogRevision;
  final Set<String> _unavailableIds = {};

  bool _financialChange(ProductData? old, ProductData next) =>
      old == null ||
      old.price != next.price ||
      old.basePrice != next.basePrice ||
      old.effectiveDiscountPercent != next.effectiveDiscountPercent;

  bool get _cartBlocked =>
      _unavailableIds.isNotEmpty ||
      _qty.entries.any((e) {
        final product = _selected[e.key];
        if (product == null) return true;
        return product.status != StockStatus.onOrder &&
            e.value > product.quantity;
      });
  Timer? _quoteTimer;
  Map<String, dynamic>? _orderDiscount;
  String? _quoteError;
  Map<String, dynamic>? _bonus;
  double _bonusRequested = 0;
  bool _useBonus = false;
  int _quoteRevision = 0;

  List<Map<String, dynamic>> get _quoteItems => _qty.entries
      .map((e) => <String, dynamic>{'productId': e.key, 'quantity': e.value})
      .toList();

  void _scheduleQuote() {
    _quoteTimer?.cancel();
    _quoteRevision++;
    _quoteError = null;
    if (_qty.isEmpty) {
      _orderDiscount = null;
      _bonus = null;
      return;
    }
    _quoteTimer = Timer(
      const Duration(milliseconds: 250),
      () => _loadOrderQuote(),
    );
  }

  Future<void> _loadOrderQuote({bool reportError = false}) async {
    final revision = ++_quoteRevision;
    if (_qty.isEmpty) return;
    try {
      final response = _useBonus
          ? await _repo.orderQuote(
              _quoteItems,
              bonusAmount: _bonusRequested.toStringAsFixed(2),
            )
          : await _repo.orderQuote(_quoteItems);
      if (!mounted || revision != _quoteRevision) return;
      final details = Map<String, dynamic>.from(
        response['orderDiscount'] as Map,
      );
      setState(() {
        _orderDiscount = details;
        _bonus = response['bonus'] is Map
            ? Map<String, dynamic>.from(response['bonus'] as Map)
            : null;
        _quoteError = null;
      });
    } catch (_) {
      if (mounted && revision == _quoteRevision) {
        setState(() {
          _quoteError = _orderDiscount == null
              ? 'Не удалось рассчитать заказ'
              : null;
        });
      }
      if (reportError) rethrow;
    }
  }

  bool _syncingPrices = false;
  final _priceRevision = ValueNotifier<int>(0);
  static const _buildName = String.fromEnvironment(
    'FLUTTER_BUILD_NAME',
    defaultValue: 'dev',
  );
  static const _buildNumber = String.fromEnvironment(
    'FLUTTER_BUILD_NUMBER',
    defaultValue: 'dev',
  );
  static const _allCategories = 'Все';

  final _commentCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  late final DataRepository _repo;
  late Future<OrderConfigData> _future;
  final Map<String, int> _qty = {};
  final Map<String, int> _quantityToAdd = {};
  final Set<String> _quantityEditors = {};
  bool _showCheckout = false;
  final _catalogScroll = ScrollController();
  final _checkoutScroll = ScrollController();

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
  bool _catalogRequested = false;

  String _selectedCategory = _allCategories;
  String? _selectedStoreId;
  String _deliveryMethod = 'courier';
  String _paymentMethod = 'online';
  bool _sending = false;

  // Baseline for change tracking
  Map<String, int>? _initialQty;
  String? _initialComment;
  String? _initialStoreId;
  String? _initialDeliveryMethod;
  String? _initialPaymentMethod;

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
    if (_paymentMethod != _initialPaymentMethod) return true;

    return false;
  }

  void _showProductDetails(ProductData product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ValueListenableBuilder<int>(
        valueListenable: _priceRevision,
        builder: (context, revision, child) {
          final current =
              _selected[product.id] ??
              _catalog.items.where((p) => p.id == product.id).firstOrNull ??
              product;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ProductThumb(
                    images: current.images,
                    size: 120,
                    onTap: () => showProductGallery(
                      context,
                      images: current.images,
                      title: current.name,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('${current.brand} · ${current.sku}'),
                  if (current.description != null) Text(current.description!),
                  const SizedBox(height: 16),
                  ClientProductPrice(product: current),
                  Text(_stockLabel(current)),
                  ShopSalePrice(product: current),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double get _totalAmount =>
      double.tryParse('${_orderDiscount?['total']}') ?? 0;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DataRepository();
    _future = _repo.orderConfig();
    _catalog = PaginationController<ProductData>(
      fetchPage: (page) => _repo.products(
        page: page,
        search: _search.isEmpty ? null : _search,
        category: _selectedCategory == _allCategories
            ? null
            : _selectedCategory,
        brand: _brandFilter,
        inStockOnly: _inStockOnly,
      ),
    );
    _catalog.loadInitial();
    _catalog.addListener(_updateCartFromCatalog);
    WidgetsBinding.instance.addObserver(this);
    _priceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          !_sending) {
        _syncPrices();
      }
    });

    _catalogTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
      if (!mounted ||
          _sending ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      try {
        final revision = await _repo.catalogRevision();
        if (mounted && revision != _lastCatalogRevision) {
          await _refresh(background: true);
        } else if (mounted) {
          await _loadOrderQuote();
        }
      } catch (_) {
        if (mounted) await _refresh(background: true);
      }
    });

    if (widget.initialOrder != null) {
      _commentCtrl.text = widget.initialOrder!.comment ?? '';
      _deliveryMethod = widget.initialOrder!.deliveryMethod;
      _paymentMethod = widget.initialOrder!.paymentMethod;
      _prefillFromOrder(widget.initialOrder!);
    }

    // Listen to comments to track changes in real-time
    _commentCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _catalogTimer?.cancel();
    _priceTimer?.cancel();
    _quoteTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _priceRevision.dispose();
    _commentCtrl.dispose();
    _searchCtrl.dispose();
    _catalog.dispose();
    _catalogScroll.dispose();
    _checkoutScroll.dispose();
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
    _scheduleQuote();
    _initialQty = Map.from(_qty);
    _initialComment = _commentCtrl.text;
    _initialDeliveryMethod = _deliveryMethod;
    _initialPaymentMethod = _paymentMethod;
  }

  void _applyFilters() {
    _catalogRequested = true;
    _catalog.setFilters(() {});
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = _allCategories;
      _brandFilter = null;
      _inStockOnly = false;
      _search = '';
      _searchCtrl.clear();
    });
    _applyFilters();
  }

  void _ensureStore(OrderConfigData data) {
    if (_selectedStoreId == null && widget.initialOrder != null) {
      // Find matching store by name/address if possible, or ID
      final matching = data.stores
          .where((s) => s.name == widget.initialOrder!.storeName)
          .firstOrNull;
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

  int _remainingToAdd(ProductData product) {
    if (!_canOrder(product)) return 0;
    final limit = product.status == StockStatus.onOrder && product.quantity == 0
        ? 999
        : product.quantity;
    return (limit - (_qty[product.id] ?? 0)).clamp(0, limit);
  }

  int _pendingQuantity(ProductData product) {
    final remaining = _remainingToAdd(product);
    if (remaining == 0) return 0;
    return (_quantityToAdd[product.id] ?? 1).clamp(1, remaining);
  }

  void _selectQuantity(ProductData product, int delta) {
    final remaining = _remainingToAdd(product);
    if (remaining == 0) return;
    setState(() {
      _quantityToAdd[product.id] = (_pendingQuantity(product) + delta).clamp(
        1,
        remaining,
      );
    });
  }

  void _addSelectedQuantity(ProductData product) {
    final count = _pendingQuantity(product);
    if (count == 0) return;
    _changeQty(product, count);
  }

  void _changeQty(ProductData product, int delta) {
    if (delta > 0 && !_canOrder(product)) return;
    final current = _qty[product.id] ?? 0;

    // If onOrder and quantity is 0, allow ordering without a hard limit
    // If status is inStock/low, limit by current quantity
    final isUnlimited =
        product.status == StockStatus.onOrder && product.quantity == 0;
    final maxQty = isUnlimited ? 999 : product.quantity;

    final requested = current + delta;
    final next = requested.clamp(0, maxQty);
    setState(() {
      if (next == 0) {
        _qty.remove(product.id);
        _selected.remove(product.id);
        _unavailableIds.remove(product.id);
      } else {
        _qty[product.id] = next;
        _selected[product.id] = product;
      }
      _scheduleQuote();
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
    if (product.quantity <= 0 && product.status != StockStatus.onOrder) {
      return false;
    }
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
      final msg = _deliveryMethod == 'courier'
          ? 'Выберите адрес для доставки'
          : 'Выберите магазин для самовывоза';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    setState(() => _sending = true);
    try {
      await _syncPrices(reportError: true);
      if (_cartBlocked) {
        throw StateError('Товар недоступен или превышен остаток');
      }
      _quoteTimer?.cancel();
      await _loadOrderQuote(reportError: true);
      if (_orderDiscount == null) return;
      await _repo.createOrder(
        replaceOrderId: widget.initialOrder?.id,
        storeId: _selectedStoreId,
        deliveryMethod: _deliveryMethod,
        paymentMethod:
            data.client.cashPaymentAllowed && _deliveryMethod == 'courier'
            ? _paymentMethod
            : 'online',
        comment: _commentCtrl.text,
        bonusAmount: _useBonus ? _bonusRequested.toStringAsFixed(2) : '0.00',
        items: _qty.entries
            .map((entry) => {'productId': entry.key, 'quantity': entry.value})
            .toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.initialOrder != null
                ? 'Заказ обновлен'
                : 'Заказ отправлен дистрибьютору',
          ),
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
        content: const Text(
          'Заказ будет аннулирован, товары вернутся на склад.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('НЕТ'),
          ),
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
        const SnackBar(
          content: Text('Заказ отменен'),
          backgroundColor: AppColors.info,
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

  void _updateCartFromCatalog() {
    if (!mounted || _batchingPrices) return;
    var changed = false;
    for (final product in _catalog.items) {
      if (_selected.containsKey(product.id)) {
        changed = _financialChange(_selected[product.id], product) || changed;
        _selected[product.id] = product;
      }
    }
    setState(() {
      if (changed) _scheduleQuote();
    });
    _priceRevision.value++;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(background: true);
  }

  Future<void> _syncPrices({
    bool reportError = false,
    bool refreshQuote = false,
  }) async {
    if (_syncingPrices || !mounted) return;
    final ids = {
      ..._selected.keys,
      ..._catalog.items.map((p) => p.id),
    }.toList();
    if (ids.isEmpty) return;
    _syncingPrices = true;
    try {
      final products = <ProductData>[];
      for (var i = 0; i < ids.length; i += 200) {
        products.addAll(
          await _repo.productQuote(
            ids.sublist(i, (i + 200).clamp(0, ids.length)),
          ),
        );
      }
      if (!mounted) return;
      var changed = false;
      _batchingPrices = true;
      try {
        for (final product in products) {
          if (_selected.containsKey(product.id)) {
            changed =
                _financialChange(_selected[product.id], product) || changed;
            _selected[product.id] = product;
          }
          _catalog.replaceWhere((p) => p.id == product.id, product);
        }
      } finally {
        _batchingPrices = false;
      }
      final available = products.map((p) => p.id).toSet();
      _unavailableIds
        ..clear()
        ..addAll(_selected.keys.where((id) => !available.contains(id)));
      _catalog.removeWhere((p) => !available.contains(p.id));
      setState(() {});
      _priceRevision.value++;
      if (changed || refreshQuote) {
        _quoteTimer?.cancel();
        await _loadOrderQuote(reportError: reportError);
      }
    } catch (e) {
      if (reportError) rethrow;
    } finally {
      _syncingPrices = false;
    }
  }

  Future<void> _refresh({bool background = false}) async {
    if (_refreshingCatalog) return;
    _refreshingCatalog = true;
    try {
      final data = await _repo.orderConfig();
      if (!mounted) return;
      final filtersChanged =
          (_brandFilter != null && !data.brands.contains(_brandFilter)) ||
          (_selectedCategory != _allCategories &&
              !data.categories.contains(_selectedCategory));
      setState(() {
        if (!data.brands.contains(_brandFilter)) _brandFilter = null;
        if (!data.categories.contains(_selectedCategory)) {
          _selectedCategory = _allCategories;
        }
        _future = Future.value(data);
      });
      _batchingPrices = true;
      try {
        await _catalog.refresh(preservePages: !filtersChanged);
      } finally {
        _batchingPrices = false;
      }
      if (_catalog.error != null) throw _catalog.error!;
      await _syncPrices(reportError: true, refreshQuote: true);
      if (!mounted) return;
      _lastCatalogRevision = data.catalogRevision;
      if (filtersChanged && !background) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Фильтры обновлены вместе с ассортиментом'),
          ),
        );
      }
    } catch (_) {
      if (mounted && !background) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Не удалось обновить данные. Повторить'),
            action: SnackBarAction(
              label: 'ПОВТОРИТЬ',
              onPressed: () => _refresh(),
            ),
          ),
        );
      }
    } finally {
      _refreshingCatalog = false;
    }
  }

  void _setCheckout(bool value) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _showCheckout = value);
  }

  Widget _cartBar() {
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'В корзине: $_totalQty шт.',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _quoteError != null
                          ? 'Не удалось рассчитать сумму'
                          : _orderDiscount == null
                          ? 'Расчёт суммы...'
                          : '${_formatPrice(_totalAmount)} ₽',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  key: const ValueKey('open-checkout'),
                  onPressed: () => _setCheckout(true),
                  child: const Text('К ОФОРМЛЕНИЮ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showCheckout || _sending,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showCheckout) _setCheckout(false);
      },
      child: Scaffold(
        appBar: AppBar(
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(20),
            child: Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Text(
                'Версия $_buildName · сборка $_buildNumber',
                key: ValueKey('installed-build-label'),
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
          ),
          leading: _showCheckout
              ? BackButton(onPressed: () => _setCheckout(false))
              : null,
          title: Text(
            _showCheckout
                ? 'Корзина и оформление'
                : widget.initialOrder != null
                ? 'Изменение заказа'
                : 'Оформление заказа',
          ),
        ),
        bottomNavigationBar: !_showCheckout && _totalQty > 0
            ? _cartBar()
            : null,
        body: FutureBuilder<OrderConfigData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }
            final data = snapshot.data!;
            _lastCatalogRevision ??= data.catalogRevision;
            _ensureStore(data);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                key: ValueKey(_showCheckout ? 'checkout-view' : 'catalog-view'),
                controller: _showCheckout ? _checkoutScroll : _catalogScroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (!_showCheckout) ...[
                    // Каталог: шапка с фильтрами
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(child: _catalogHeader(data)),
                    ),
                    // Каталог: виртуализированный список товаров
                    _catalogSliverList(),
                  ],
                  // Остальные карточки
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 2),
                        if (!_showCheckout) _catalogFooter(),
                        const SizedBox(height: 16),
                        _selectedCard(),
                        for (final entry in _qty.entries)
                          if (_unavailableIds.contains(entry.key))
                            Text(
                              '${_selected[entry.key]?.name}: Товар больше недоступен',
                              style: const TextStyle(color: AppColors.error),
                            )
                          else if (_selected[entry.key] != null &&
                              _selected[entry.key]!.status !=
                                  StockStatus.onOrder &&
                              entry.value > _selected[entry.key]!.quantity)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_selected[entry.key]!.name}: доступно ${_selected[entry.key]!.quantity} шт., в корзине ${entry.value}',
                                  style: const TextStyle(
                                    color: AppColors.error,
                                  ),
                                ),
                                if (_selected[entry.key]!.quantity > 0)
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _qty[entry.key] =
                                          _selected[entry.key]!.quantity;
                                      _scheduleQuote();
                                    }),
                                    child: Text(
                                      'Уменьшить до ${_selected[entry.key]!.quantity} шт.',
                                    ),
                                  ),
                              ],
                            ),
                        const SizedBox(height: 16),
                        _deliveryMethodCard(data),
                        if (data.client.cashPaymentAllowed &&
                            _deliveryMethod == 'courier')
                          SwitchListTile(
                            title: const Text('Оплата наличными курьеру'),
                            subtitle: const Text(
                              'После подтверждения заказ уйдёт в сборку. Оплатите при доставке.',
                            ),
                            value: _paymentMethod == 'cash',
                            onChanged: (value) => setState(
                              () => _paymentMethod = value ? 'cash' : 'online',
                            ),
                          ),
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
                _methodBtn(
                  'courier',
                  'ДОСТАВКА',
                  Icons.local_shipping_outlined,
                ),
                const SizedBox(width: 12),
                _methodBtn(
                  'self_pickup',
                  'САМОВЫВОЗ',
                  Icons.storefront_outlined,
                ),
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
              Icon(
                icon,
                color: active ? Colors.white : AppColors.brandBlack,
                size: 20,
              ),
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
          color: selected
              ? AppColors.brandRed.withValues(alpha: 0.05)
              : Colors.white,
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
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.brandRed),
          ],
        ),
      ),
    );
  }

  Widget _bonusPreview(double balance, double totalAmount) {
    double number(String key, double fallback) =>
        double.tryParse('${_bonus?[key]}') ?? fallback;
    final maximum = number('maxAllowed', 0);
    final selected = _useBonus ? _bonusRequested.clamp(0.0, maximum) : 0.0;
    final applied = number('applied', 0);
    final payable = number('payableTotal', totalAmount);
    final fmt = NumberFormat('#,##0.00', 'ru_RU');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ваши бонусы',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Text('Баланс: ${fmt.format(number('balance', balance))} ₽'),
          Text('Можно использовать в этом заказе: до ${fmt.format(maximum)} ₽'),
          const Text('1 бонус = 1 ₽. Максимум 10% суммы после скидок.'),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Использовать бонусы'),
              value: _useBonus,
              onChanged: maximum <= 0
                  ? null
                  : (value) => setState(() {
                      _useBonus = value;
                      _bonusRequested = value ? maximum : 0;
                      _scheduleQuote();
                    }),
            ),
          ),
          if (_useBonus) ...[
            Slider(
              value: selected,
              min: 0,
              max: maximum > 0 ? maximum : 1,
              onChanged: maximum <= 0
                  ? null
                  : (value) => setState(() {
                      _bonusRequested = (value * 100).floor() / 100;
                      _scheduleQuote();
                    }),
            ),
            Text('Выбрано: ${fmt.format(selected)} ₽'),
            TextButton(
              onPressed: maximum <= 0
                  ? null
                  : () => setState(() {
                      _bonusRequested = maximum;
                      _scheduleQuote();
                    }),
              child: const Text('Использовать максимум'),
            ),
          ],
          Text('Сумма заказа: ${fmt.format(totalAmount)} ₽'),
          Text('Бонусы: −${fmt.format(applied)} ₽'),
          Text(
            'К оплате: ${fmt.format(payable)} ₽',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const Text(
            'Списание произойдёт при оплате после повторной проверки суммы и баланса.',
          ),
        ],
      ),
    );
  }

  Widget _requestForm(OrderConfigData data) {
    final disabled =
        _cartBlocked ||
        _sending ||
        _orderDiscount == null ||
        !_hasChanges ||
        _totalQty == 0 ||
        (data.stores.isNotEmpty && _selectedStoreId == null);
    final store = _selectedStore(data.stores);
    final totalAmount = _totalAmount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_totalQty > 0) ...[
              if (_orderDiscount != null)
                OrderDiscountSummary(details: _orderDiscount!)
              else if (_quoteError != null)
                TextButton(
                  onPressed: _loadOrderQuote,
                  child: Text('$_quoteError. Повторить'),
                )
              else
                const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            const Text(
              'Отправка заказа',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              _deliveryMethod == 'courier'
                  ? (store == null
                        ? 'Укажите адрес для курьера.'
                        : 'Доставка на адрес: ${store.address}')
                  : (store == null
                        ? 'Выберите ваш объект для оформления.'
                        : 'Заказ для объекта: ${store.name}'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
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
            if (_orderDiscount != null &&
                data.client.cashPaymentAllowed &&
                _deliveryMethod == 'courier' &&
                _paymentMethod == 'cash') ...[
              const SizedBox(height: 16),
              Text(
                'Наличными курьеру: ${_formatPrice(totalAmount)} ₽. Бонусы при этом способе оплаты не списываются.',
              ),
            ],
            if ((double.tryParse('${_bonus?['balance']}') ??
                        data.bonusBalance) >
                    0 &&
                totalAmount > 0 &&
                !(data.client.cashPaymentAllowed &&
                    _deliveryMethod == 'courier' &&
                    _paymentMethod == 'cash')) ...[
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
                        child: const Text(
                          'ОТМЕНИТЬ ЗАКАЗ',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'ПОДТВЕРДИТЬ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
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
                          _totalQty == 0
                              ? 'Добавьте товар'
                              : _orderDiscount == null
                              ? 'Расчёт заказа…'
                              : 'Отправить дистрибьютору · ${_formatPrice(totalAmount)} ₽',
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
            if (_catalog.isLoading && _catalog.hasLoadedOnce) ...[
              const LinearProgressIndicator(),
              const Text('Обновляем каталог...'),
            ],
            if (_catalog.error != null && _catalog.items.isNotEmpty) ...[
              const Text('Не удалось обновить данные. Повторить'),
              TextButton(
                onPressed: () => _catalog.refresh(),
                child: const Text('ПОВТОРИТЬ'),
              ),
            ],
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
                _catalogRequested = true;
                // Дебаунс: запрос уходит на сервер, а не фильтрует страницу.
                _catalog.refreshDebounced();
              },
              decoration: InputDecoration(
                hintText: 'Название, синоним, артикул, бренд, категория',
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(_brandFilter),
                    initialValue: _brandFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Бренд',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Все бренды'),
                      ),
                      ...data.brands.map(
                        (brand) => DropdownMenuItem<String?>(
                          value: brand,
                          child: Text(brand),
                        ),
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
                    color: _inStockOnly
                        ? AppColors.brandRed
                        : AppColors.textPrimary,
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
          final updating = _catalogRequested || _catalog.hasLoadedOnce;
          return SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: AppColors.brandRed),
                    const SizedBox(height: 12),
                    Text(
                      updating ? 'Обновляем каталог...' : 'Загрузка товаров...',
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Ошибка
        if (_catalog.error != null &&
            _catalog.items.isEmpty &&
            !_catalog.isLoadingMore) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Text(
                    'Не удалось загрузить товары',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
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
          return SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Text(
                      'По выбранным фильтрам товары не найдены',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _resetFilters,
                      child: const Text('СБРОСИТЬ ФИЛЬТРЫ'),
                    ),
                  ],
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
        if (_catalog.items.isEmpty ||
            _catalog.isLoading ||
            _catalog.error != null) {
          return const SizedBox.shrink();
        }

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
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
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
    final showStockWarning = item.quantity > 0 && qty >= item.quantity;

    String stockStatusText;
    Color stockColor;
    if (item.quantity > 5) {
      stockStatusText = _stockLabel(item);
      stockColor = AppColors.success;
    } else if (item.quantity > 0) {
      stockStatusText = _stockLabel(item);
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
      key: ValueKey('catalog-product-${item.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ShapeDecoration(
        color: isOutOfStock
            ? AppColors.border.withValues(alpha: 0.2)
            : (qty > 0
                  ? AppColors.brandRed.withValues(alpha: 0.05)
                  : Colors.white),
        shape: BeveledRectangleBorder(
          side: BorderSide(
            color: isOutOfStock
                ? AppColors.border
                : (qty > 0 ? AppColors.brandRed : AppColors.border),
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
                        InkWell(
                          onTap: () => _showProductDetails(item),
                          child: SizedBox(
                            key: ValueKey('catalog-title-${item.id}'),
                            width: double.infinity,
                            height:
                                MediaQuery.textScalerOf(context).scale(13) *
                                1.3 *
                                3,
                            child: Text(
                              item.name.toUpperCase(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                height: 1.3,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.brand} · ${item.sku}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: ShapeDecoration(
                            color: stockColor.withValues(alpha: 0.1),
                            shape: const BeveledRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(5),
                              ),
                            ),
                          ),
                          child: Text(
                            stockStatusText,
                            style: TextStyle(
                              color: stockColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ShopSalePrice(product: item),
              ClientProductPrice(product: item),
              if (canOrder || qty > 0) ...[
                const SizedBox(height: 12),
                _addToCartControls(item),
                if (qty > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'В корзине: $qty шт.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
              if (item.quantity > 0 && !showStockWarning) ...[
                const SizedBox(height: 8),
                Text(
                  qty > 0
                      ? 'Можно добавить ещё: ${_remainingToAdd(item)} шт.'
                      : 'Доступно: ${item.quantity} шт.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              if (showStockWarning && item.quantity > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Достигнут максимальный остаток: ${item.quantity} шт.',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _addToCartControls(ProductData product) {
    final expanded =
        _quantityEditors.contains(product.id) || (_qty[product.id] ?? 0) > 0;
    final pending = _pendingQuantity(product);
    final remaining = _remainingToAdd(product);
    final addButton = SizedBox(
      height: 48,
      child: ElevatedButton(
        key: ValueKey('add-to-cart-${product.id}'),
        onPressed: pending > 0
            ? () {
                if (!expanded) {
                  setState(() => _quantityEditors.add(product.id));
                } else {
                  _addSelectedQuantity(product);
                }
              }
            : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 48),
          backgroundColor: AppColors.brandBlack,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: const Text(
          'ДОБАВИТЬ',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
    if (!expanded) return SizedBox(width: double.infinity, child: addButton);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: 'Количество для добавления',
          child: Container(
            key: ValueKey('quantity-control-${product.id}'),
            width: 120,
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: IconButton(
                    tooltip: 'Уменьшить количество для добавления',
                    padding: EdgeInsets.zero,
                    onPressed: pending > 1
                        ? () => _selectQuantity(product, -1)
                        : null,
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '$pending',
                    key: ValueKey('quantity-to-add-${product.id}'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  child: IconButton(
                    tooltip: 'Увеличить количество для добавления',
                    padding: EdgeInsets.zero,
                    onPressed: pending < remaining
                        ? () => _selectQuantity(product, 1)
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: addButton),
      ],
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${_formatPrice(item.price)} ₽/шт · ${_formatPrice(item.price * qty)} ₽',
                          ),
                          ClientProductPrice(product: item),
                        ],
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

  String _stockLabel(ProductData product) {
    if (product.quantity > 5) return 'В НАЛИЧИИ · ${product.quantity} ШТ.';
    if (product.quantity > 0) return 'МАЛО · ${product.quantity} ШТ.';
    return product.status == StockStatus.onOrder
        ? 'ПОД ЗАКАЗ'
        : 'НЕТ В НАЛИЧИИ';
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  Widget _qtyStepper(ProductData product, int qty) {
    final isUnlimited =
        product.status == StockStatus.onOrder && product.quantity == 0;
    final reachedLimit =
        !_canOrder(product) ||
        (isUnlimited ? qty >= 999 : qty >= product.quantity);

    return Column(
      key: ValueKey('basket-quantity-${product.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'В корзине',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Container(
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
              _qtyButton(Icons.add, reachedLimit, () => _changeQty(product, 1)),
            ],
          ),
        ),
      ],
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
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
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
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
