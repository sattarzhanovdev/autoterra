import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';

/// Заказ глазами клиента.
///
/// Ключевой экран безопасного потока: оплата открывается только после того,
/// как оператор подтвердил наличие. Если состав урезали, клиент сначала видит
/// что именно изменилось, и лишь потом соглашается и платит.
class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Order? initialOrder;

  const OrderDetailScreen({super.key, required this.orderId, this.initialOrder});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _repo = DataRepository();
  final _fmt = NumberFormat('#,##0', 'ru_RU');

  Order? _order;
  String? _loadError;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    if (_order == null) _load();
  }

  Future<void> _load() async {
    try {
      final order = await _repo.orderDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  // ── Действия клиента ──────────────────────────────────────────────────────

  Future<void> _acceptAdjustment() async {
    setState(() => _busy = true);
    try {
      final updated = await _repo.acceptAdjustment(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _busy = false;
        _changed = true;
      });
      _toast('Корректировка принята. Можно оплатить заказ');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString(), isError: true);
    }
  }

  Future<void> _pay() async {
    final order = _order;
    if (order == null) return;

    setState(() => _busy = true);
    try {
      // Если платёж уже создан, повторно не создаём — ведём на ту же страницу.
      final url = order.pendingPaymentUrl ?? await _repo.payOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _changed = true;
      });

      if (url == null) {
        _toast('Не удалось получить ссылку на оплату', isError: true);
        return;
      }
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _toast('Не удалось открыть страницу оплаты', isError: true);
        return;
      }
      // Статус меняет вебхук провайдера, поэтому по возвращении перечитываем.
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString(), isError: true);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'ОТМЕНИТЬ ЗАКАЗ?',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
        ),
        content: const Text(
          'Заказ будет отменён, товар вернётся на склад. Восстановить его будет нельзя.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('НАЗАД', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ОТМЕНИТЬ ЗАКАЗ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.brandRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _repo.cancelOrder(widget.orderId);
      if (!mounted) return;
      _changed = true;
      _toast('Заказ отменён');
      await _load();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString(), isError: true);
    }
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
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.brandBlack,
          foregroundColor: Colors.white,
          title: Text(
            order?.documentNumber ?? 'ЗАКАЗ',
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 15),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ),
        body: _buildBody(order),
        bottomNavigationBar: order == null ? null : _buildActions(order),
      ),
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

    final adjustment = order.adjustments.isNotEmpty ? order.adjustments.first : null;

    return RefreshIndicator(
      color: AppColors.brandRed,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _OrderProgress(status: order.status),
          const SizedBox(height: 16),

          // Корректировка — самое важное на экране, поэтому идёт первой.
          if (order.status == OrderStatus.adjusted && adjustment != null) ...[
            _AdjustmentDiff(adjustment: adjustment, fmt: _fmt),
            const SizedBox(height: 16),
          ],

          if (order.status == OrderStatus.rejected && order.rejectionReason != null) ...[
            _Notice(
              title: 'ЗАКАЗ ОТКЛОНЁН',
              body: order.rejectionReason!,
              accent: AppColors.brandRed,
            ),
            const SizedBox(height: 16),
          ],

          const Text(
            'СОСТАВ ЗАКАЗА',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          ...order.items.map((item) => _ItemRow(item: item, fmt: _fmt)),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.brandBlack,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ИТОГО',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
                ),
                Text(
                  '${_fmt.format(order.totalAmount)} ₽',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ],
            ),
          ),

          if (order.comment != null && order.comment!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Notice(title: 'ВАШ КОММЕНТАРИЙ', body: order.comment!),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Что клиент может сделать сейчас. Кнопка оплаты появляется только для
  /// подтверждённого заказа — до этого платить нечего и не за что.
  Widget? _buildActions(Order order) {
    final children = <Widget>[];

    switch (order.status) {
      case OrderStatus.newOrder:
        children.add(const _Hint('Заказ у оператора. Мы сообщим, когда наличие подтвердят.'));
        children.add(_textButton('ОТМЕНИТЬ ЗАКАЗ', _cancel, isDestructive: true));
      case OrderStatus.adjusted:
        children.add(_primaryButton('ПРИНЯТЬ И ПЕРЕЙТИ К ОПЛАТЕ', _acceptAdjustment));
        children.add(_textButton('ОТКАЗАТЬСЯ ОТ ЗАКАЗА', _cancel, isDestructive: true));
      case OrderStatus.confirmed:
      case OrderStatus.accepted:
        children.add(_primaryButton(
          order.pendingPaymentUrl != null
              ? 'ПРОДОЛЖИТЬ ОПЛАТУ · ${_fmt.format(order.totalAmount)} ₽'
              : 'ОПЛАТИТЬ ${_fmt.format(order.totalAmount)} ₽',
          _pay,
        ));
        children.add(_textButton('ОТМЕНИТЬ ЗАКАЗ', _cancel, isDestructive: true));
      case OrderStatus.paid:
        children.add(const _Hint('Оплачено. Готовим заказ к отправке.'));
      case OrderStatus.shipped:
        children.add(const _Hint('Заказ в пути.'));
      case OrderStatus.fulfilled:
        children.add(const _Hint('Заказ доставлен.'));
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        break;
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

  Widget _primaryButton(String label, VoidCallback onPressed) {
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

  Widget _textButton(String label, VoidCallback onPressed, {bool isDestructive = false}) {
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

/// Полоса прогресса заказа. Отменённые и отклонённые ветки в неё не
/// укладываются, поэтому для них показываем отдельную плашку.
class _OrderProgress extends StatelessWidget {
  final OrderStatus status;

  const _OrderProgress({required this.status});

  static const _steps = [
    ('ОФОРМЛЕН', [OrderStatus.newOrder, OrderStatus.adjusted]),
    ('ПОДТВЕРЖДЁН', [OrderStatus.confirmed, OrderStatus.accepted]),
    ('ОПЛАЧЕН', [OrderStatus.paid]),
    ('В ПУТИ', [OrderStatus.shipped]),
    ('ДОСТАВЛЕН', [OrderStatus.fulfilled]),
  ];

  int get _currentIndex {
    for (var i = 0; i < _steps.length; i++) {
      if (_steps[i].$2.contains(status)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.rejected || status == OrderStatus.cancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        color: AppColors.textHint,
        child: Text(
          status.label.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
        ),
      );
    }

    final current = _currentIndex;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      color: Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 4,
                    color: i <= current ? AppColors.brandRed : AppColors.border,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _steps[i].$1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      color: i <= current ? AppColors.brandBlack : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            if (i < _steps.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

/// Что именно изменил оператор: было → стало, построчно.
class _AdjustmentDiff extends StatelessWidget {
  final OrderAdjustment adjustment;
  final NumberFormat fmt;

  const _AdjustmentDiff({required this.adjustment, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final adjustedBySku = {for (final i in adjustment.adjustedItems) i.sku: i};

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.brandRed, width: 2),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ОПЕРАТОР СКОРРЕКТИРОВАЛ ЗАКАЗ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.brandRed, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          const Text(
            'Часть позиций недоступна в заказанном количестве. Проверьте изменения — оплата пройдёт только по этому составу.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          if (adjustment.reason != null && adjustment.reason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: AppColors.canvas,
              child: Text(
                adjustment.reason!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...adjustment.originalItems.map((original) {
            final adjusted = adjustedBySku[original.sku];
            final newQty = adjusted?.quantity ?? 0;
            if (newQty == original.quantity) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    original.name.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${original.quantity} шт',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 12, color: AppColors.textHint),
                      ),
                      Text(
                        newQty == 0 ? 'убрано' : '$newQty шт',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.brandRed),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final PurchaseItem item;
  final NumberFormat fmt;

  const _ItemRow({required this.item, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.sku} · ${fmt.format(item.price)} ₽ × ${item.quantity}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Text(
            '${fmt.format(item.total)} ₽',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String title;
  final String body;
  final Color? accent;

  const _Notice({required this.title, required this.body, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: accent == null ? null : Border(left: BorderSide(color: accent!, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: accent ?? AppColors.textHint,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

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
