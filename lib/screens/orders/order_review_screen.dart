import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';

/// Разбор заказа оператором — узкое место всего потока.
///
/// Здесь решается главная задача: клиент не должен оплатить то, чего нет на
/// складе. Поэтому оператор видит по каждой позиции «заказано / в наличии»,
/// правит количества и отправляет клиенту либо подтверждение, либо
/// корректировку — и только после согласия клиент попадает на оплату.
class OrderReviewScreen extends StatefulWidget {
  final String orderId;

  /// Заказ, если экран открыт из списка. При переходе по ссылке из письма
  /// его нет — тогда грузим по [orderId].
  final Order? initialOrder;

  const OrderReviewScreen({super.key, required this.orderId, this.initialOrder});

  @override
  State<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends State<OrderReviewScreen> {
  final _repo = DataRepository();
  final _fmt = NumberFormat('#,##0', 'ru_RU');

  Order? _order;
  String? _loadError;
  bool _busy = false;

  /// Правки оператора: id позиции → новое количество. Пока карта пуста,
  /// заказ не изменён и доступно обычное подтверждение.
  final Map<String, int> _quantities = {};

  /// Изменился ли состав относительно того, что прислал клиент.
  bool get _isModified {
    final order = _order;
    if (order == null) return false;
    return order.items.any((item) {
      final id = item.id;
      if (id == null) return false;
      return _quantities[id] != item.quantity;
    });
  }

  bool get _hasAnyItem => _quantities.values.any((q) => q > 0);

  double get _adjustedTotal {
    final order = _order;
    if (order == null) return 0;
    var sum = 0.0;
    for (final item in order.items) {
      final qty = _quantities[item.id] ?? item.quantity;
      sum += item.price * qty;
    }
    return sum;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialOrder != null) {
      _applyOrder(widget.initialOrder!);
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final order = await _repo.orderDetail(widget.orderId);
      if (mounted) setState(() => _applyOrder(order));
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  /// Сбрасывает правки под актуальный состав заказа.
  void _applyOrder(Order order) {
    _order = order;
    _loadError = null;
    _quantities
      ..clear()
      ..addEntries(
        order.items
            .where((item) => item.id != null)
            .map((item) => MapEntry(item.id!, item.quantity)),
      );
  }

  // ── Действия оператора ────────────────────────────────────────────────────

  /// Выполняет действие, показывая блокировку и ошибку единообразно.
  /// Возвращает `true`, если действие прошло.
  Future<bool> _run(Future<Order> Function() action, String successMessage) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return true;
      setState(() {
        _applyOrder(updated);
        _busy = false;
      });
      _toast(successMessage);
      // Списку нужно перечитать заказ — он ушёл из «новых».
      Navigator.of(context).pop(true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _busy = false);
      if (e is OrderShortageException) {
        _showShortageDialog(e);
      } else {
        _toast(e.toString(), isError: true);
      }
      return false;
    }
  }

  Future<void> _confirm({bool force = false}) {
    return _run(
      () => _repo.confirmOrder(widget.orderId, force: force),
      force ? 'Заказ подтверждён без учёта остатков' : 'Заказ подтверждён, клиент может оплатить',
    );
  }

  Future<void> _sendAdjustment() async {
    final order = _order;
    if (order == null) return;

    final reason = await _askReason(
      title: 'Корректировка заказа',
      hint: 'Что изменилось и почему — клиент увидит этот текст',
      confirmLabel: 'ОТПРАВИТЬ КЛИЕНТУ',
    );
    if (reason == null) return;

    final items = order.items
        .where((item) => item.id != null)
        .map((item) => {
              'itemId': int.tryParse(item.id!) ?? item.id,
              'quantity': _quantities[item.id] ?? item.quantity,
            })
        .toList();

    await _run(
      () => _repo.adjustOrder(widget.orderId, items: items, reason: reason),
      'Корректировка отправлена клиенту на согласование',
    );
  }

  Future<void> _reject() async {
    final reason = await _askReason(
      title: 'Отклонить заказ',
      hint: 'Причина отклонения — клиент увидит этот текст',
      confirmLabel: 'ОТКЛОНИТЬ',
      isDestructive: true,
      requireText: true,
    );
    if (reason == null) return;
    await _run(
      () => _repo.rejectOrder(widget.orderId, reason: reason),
      'Заказ отклонён, товар возвращён на склад',
    );
  }

  Future<void> _ship() {
    return _run(() => _repo.shipOrder(widget.orderId), 'Заказ отмечен как отправленный');
  }

  // ── Диалоги ───────────────────────────────────────────────────────────────

  /// Сервер отказался подтверждать дефицитный заказ. Предлагаем починить
  /// состав (правильный путь) или подтвердить под ответственность оператора.
  void _showShortageDialog(OrderShortageException e) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'НЕ ХВАТАЕТ ОСТАТКОВ',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'По этим позициям заказано больше, чем есть на складе:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ...e.shortages.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    Text(
                      'Заказано ${s.requested} · в наличии ${s.available}',
                      style: const TextStyle(fontSize: 12, color: AppColors.brandRed, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _trimToAvailable(e.shortages);
            },
            child: const Text(
              'УМЕНЬШИТЬ ДО ОСТАТКА',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.brandBlack),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _confirm(force: true);
            },
            child: const Text(
              'ВСЁ РАВНО ПОДТВЕРДИТЬ',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.brandRed),
            ),
          ),
        ],
      ),
    );
  }

  /// Подставляет доступный остаток в дефицитные позиции — дальше оператор
  /// отправляет это клиенту как корректировку.
  void _trimToAvailable(List<OrderShortage> shortages) {
    final order = _order;
    if (order == null) return;
    final byProduct = {for (final s in shortages) s.productId: s.available};
    setState(() {
      for (final item in order.items) {
        final id = item.id;
        final available = byProduct[item.productId];
        if (id != null && available != null) _quantities[id] = available;
      }
    });
    _toast('Количества уменьшены до остатка — отправьте корректировку клиенту');
  }

  Future<String?> _askReason({
    required String title,
    required String hint,
    required String confirmLabel,
    bool isDestructive = false,
    bool requireText = false,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSubmit = !requireText || controller.text.trim().isNotEmpty;
            return AlertDialog(
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: Text(
                title.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                onChanged: (_) => setDialogState(() {}),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 12),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('ОТМЕНА', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.textSecondary)),
                ),
                TextButton(
                  onPressed: canSubmit
                      ? () => Navigator.of(dialogContext).pop(controller.text.trim())
                      : null,
                  child: Text(
                    confirmLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: canSubmit
                          ? (isDestructive ? AppColors.brandRed : AppColors.brandBlack)
                          : AppColors.textHint,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.brandRed : AppColors.brandBlack,
      ),
    );
  }

  // ── Разметка ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.brandBlack,
        foregroundColor: Colors.white,
        title: Text(
          order == null ? 'ЗАКАЗ' : order.documentNumber,
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 15),
        ),
      ),
      body: _buildBody(order),
      bottomNavigationBar: order == null ? null : _buildActions(order),
    );
  }

  Widget _buildBody(Order? order) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _loadError = null);
                  _load();
                },
                child: const Text('ПОВТОРИТЬ'),
              ),
            ],
          ),
        ),
      );
    }
    if (order == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brandRed));
    }

    return AbsorbPointer(
      absorbing: _busy,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OrderSummary(order: order),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ПОЗИЦИИ',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
              ),
              if (_isModified)
                const Text(
                  'ЕСТЬ ПРАВКИ',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.brandRed),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...order.items.map(_buildItemRow),
          const SizedBox(height: 16),
          _buildTotals(order),
          if (order.comment != null && order.comment!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _LabeledBlock(title: 'КОММЕНТАРИЙ КЛИЕНТА', body: order.comment!),
          ],
          if (order.rejectionReason != null) ...[
            const SizedBox(height: 16),
            _LabeledBlock(title: 'ПРИЧИНА ОТКЛОНЕНИЯ', body: order.rejectionReason!),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildItemRow(PurchaseItem item) {
    final id = item.id;
    final qty = _quantities[id] ?? item.quantity;
    final editable = id != null && (_order?.status == OrderStatus.newOrder);
    final removed = qty == 0;
    // Дефицит считаем по текущему количеству, а не по изначальному: как только
    // оператор уменьшил позицию до остатка, подсветка должна погаснуть.
    final available = item.availableQuantity;
    final isShort = available != null && qty > available;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(
            color: removed
                ? AppColors.textHint
                : isShort
                    ? AppColors.brandRed
                    : AppColors.brandBlack,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              decoration: removed ? TextDecoration.lineThrough : null,
              color: removed ? AppColors.textHint : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${item.sku} · ${_fmt.format(item.price)} ₽/шт',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      available == null
                          ? 'ПОД ЗАКАЗ'
                          : 'В НАЛИЧИИ: $available',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isShort ? AppColors.brandRed : AppColors.textSecondary,
                      ),
                    ),
                    if (qty != item.quantity)
                      Text(
                        'Было: ${item.quantity}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              if (editable)
                _QuantityStepper(
                  quantity: qty,
                  max: available,
                  onChanged: (value) => setState(() => _quantities[id] = value),
                )
              else
                Text(
                  '× $qty',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotals(Order order) {
    final changed = _isModified;
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.brandBlack,
      child: Column(
        children: [
          if (changed) ...[
            _totalRow('Заказано клиентом', order.totalAmount, muted: true, strikethrough: true),
            const SizedBox(height: 6),
          ],
          _totalRow(changed ? 'К подтверждению' : 'Сумма заказа', _adjustedTotal),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool muted = false, bool strikethrough = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: muted ? AppColors.textOnDarkMuted : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          '${_fmt.format(value)} ₽',
          style: TextStyle(
            color: muted ? AppColors.textOnDarkMuted : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: muted ? 13 : 18,
            decoration: strikethrough ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  /// Набор действий зависит от статуса: разбирать можно только новый заказ,
  /// отправлять — только оплаченный.
  Widget? _buildActions(Order order) {
    final children = <Widget>[];

    if (order.status == OrderStatus.newOrder) {
      if (_isModified) {
        children.add(_primaryButton(
          label: _hasAnyItem ? 'ОТПРАВИТЬ КОРРЕКТИРОВКУ' : 'НЕЧЕГО ПОДТВЕРЖДАТЬ',
          onPressed: _hasAnyItem ? _sendAdjustment : null,
        ));
      } else {
        children.add(_primaryButton(label: 'ПОДТВЕРДИТЬ ЗАКАЗ', onPressed: _confirm));
      }
      children.add(_secondaryButton(label: 'ОТКЛОНИТЬ', onPressed: _reject, isDestructive: true));
    } else if (order.status == OrderStatus.adjusted) {
      children.add(const _StatusHint(text: 'Корректировка отправлена. Ждём ответа клиента.'));
    } else if (order.status == OrderStatus.confirmed) {
      children.add(const _StatusHint(text: 'Заказ подтверждён. Ждём оплату от клиента.'));
    } else if (order.status == OrderStatus.paid) {
      children.add(_primaryButton(label: 'ОТМЕТИТЬ ОТПРАВКУ', onPressed: _ship));
    }

    if (children.isEmpty) return null;

    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy) ...[
            const LinearProgressIndicator(color: AppColors.brandRed, minHeight: 2),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _primaryButton({required String label, VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandRed,
          disabledBackgroundColor: AppColors.border,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    VoidCallback? onPressed,
    bool isDestructive = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton(
        onPressed: _busy ? null : onPressed,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 0.5,
            color: isDestructive ? AppColors.brandRed : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Шапка: кто заказал, когда и куда.
class _OrderSummary extends StatelessWidget {
  final Order order;

  const _OrderSummary({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  (order.clientName ?? 'Клиент').toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              _OrderStatusChip(status: order.status),
            ],
          ),
          if (order.clientInn != null) ...[
            const SizedBox(height: 4),
            Text(
              'ИНН ${order.clientInn}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          _row('Создан', dateFmt.format(order.date)),
          _row(
            'Получение',
            order.deliveryMethod == 'self_pickup' ? 'Самовывоз' : 'Доставка курьером',
          ),
          if (order.storeName.isNotEmpty) _row('Точка', order.storeName),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textHint, letterSpacing: 0.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusChip extends StatelessWidget {
  final OrderStatus status;

  const _OrderStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.newOrder => AppColors.brandRed,
      OrderStatus.adjusted => AppColors.brandRed,
      OrderStatus.rejected || OrderStatus.cancelled => AppColors.textHint,
      _ => AppColors.brandBlack,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: color,
      child: Text(
        status.label.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5),
      ),
    );
  }
}

/// Шаг количества с потолком по остатку: увеличить сверх наличия нельзя —
/// именно это и создаёт ситуацию «оплатили то, чего нет».
class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final int? max;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.quantity, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final canIncrease = max == null || quantity < max!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(Icons.remove, quantity > 0 ? () => onChanged(quantity - 1) : null),
        Container(
          width: 44,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
          ),
          child: Text(
            '$quantity',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ),
        _button(Icons.add, canIncrease ? () => onChanged(quantity + 1) : null),
      ],
    );
  }

  Widget _button(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          color: onTap == null ? AppColors.canvas : Colors.white,
        ),
        child: Icon(icon, size: 16, color: onTap == null ? AppColors.textHint : AppColors.brandBlack),
      ),
    );
  }
}

class _LabeledBlock extends StatelessWidget {
  final String title;
  final String body;

  const _LabeledBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textHint, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatusHint extends StatelessWidget {
  final String text;

  const _StatusHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
      ),
    );
  }
}
