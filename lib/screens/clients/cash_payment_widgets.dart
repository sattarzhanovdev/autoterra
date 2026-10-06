import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';

class ClientCashPermissionCard extends StatefulWidget {
  final String clientId;
  final DataRepository? repository;
  const ClientCashPermissionCard({
    super.key,
    required this.clientId,
    this.repository,
  });
  @override
  State<ClientCashPermissionCard> createState() =>
      _ClientCashPermissionCardState();
}

class _ClientCashPermissionCardState extends State<ClientCashPermissionCard> {
  late final _repo = widget.repository ?? DataRepository();
  bool? _allowed;
  bool _busy = false;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.clientCashPermission(widget.clientId);
      if (mounted) {
        setState(() {
          _allowed = data['cashPaymentAllowed'] == true;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _change(bool value) async {
    setState(() => _busy = true);
    try {
      final data = await _repo.updateClientCashPermission(
        widget.clientId,
        value,
      );
      if (mounted) {
        setState(() => _allowed = data['cashPaymentAllowed'] == true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось изменить доступ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return ListTile(
        title: const Text('Не удалось загрузить доступ к наличным'),
        trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      );
    }
    if (_allowed == null) return const LinearProgressIndicator();
    return SwitchListTile(
      title: const Text('Оплата наличными курьеру'),
      subtitle: Text(
        _allowed!
            ? 'Разрешена. Клиент может выбрать наличные после подтверждения заказа.'
            : 'Не разрешена. Уже принятые наличные заказы сохраняют свой способ оплаты.',
      ),
      value: _allowed!,
      onChanged: _busy ? null : _change,
    );
  }
}

class OrderCashChoiceButton extends StatefulWidget {
  final Order order;
  final DataRepository repository;
  final ValueChanged<Order> onChanged;
  const OrderCashChoiceButton({
    super.key,
    required this.order,
    required this.repository,
    required this.onChanged,
  });
  @override
  State<OrderCashChoiceButton> createState() => _OrderCashChoiceButtonState();
}

class _OrderCashChoiceButtonState extends State<OrderCashChoiceButton> {
  bool _busy = false;
  Future<void> _choose() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Оплата наличными курьеру'),
        content: Text(
          'Передать курьеру ${NumberFormat('#,##0.00', 'ru_RU').format(widget.order.totalAmount)} ₽ при доставке? Заказ поступит в сборку без онлайн-оплаты.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выбрать наличные'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final order = await widget.repository.chooseOrderCash(widget.order.id);
      if (mounted) widget.onChanged(order);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось выбрать наличные: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _busy ? null : _choose,
    icon: const Icon(Icons.payments_outlined),
    label: Text(_busy ? 'Сохранение…' : 'ОПЛАТА НАЛИЧНЫМИ КУРЬЕРУ'),
  );
}

class CourierCashCollection extends StatefulWidget {
  final CourierTask task;
  final DataRepository repository;
  final ValueChanged<CourierTask> onChanged;
  const CourierCashCollection({
    super.key,
    required this.task,
    required this.repository,
    required this.onChanged,
  });
  @override
  State<CourierCashCollection> createState() => _CourierCashCollectionState();
}

class _CourierCashCollectionState extends State<CourierCashCollection> {
  bool _busy = false;
  Future<void> _collect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтвердить получение наличных'),
        content: Text(
          'Вы действительно получили от клиента ${NumberFormat('#,##0.00', 'ru_RU').format(widget.task.cashAmount)} ₽? Подтверждайте только после получения всей суммы.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Нет'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Да, деньги получил'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final task = await widget.repository.courierCollectCash(widget.task.id);
      if (mounted) widget.onChanged(task);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось подтвердить наличные: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.task.paymentMethod != 'cash') return const SizedBox.shrink();
    final amount = NumberFormat(
      '#,##0.00',
      'ru_RU',
    ).format(widget.task.cashAmount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.task.cashCollected
                ? 'НАЛИЧНЫЕ ПОЛУЧЕНЫ: $amount ₽'
                : 'ПОЛУЧИТЬ НАЛИЧНЫМИ: $amount ₽',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (!widget.task.cashCollected &&
              widget.task.status == CourierTaskStatus.inProgress)
            FilledButton(
              onPressed: _busy ? null : _collect,
              child: Text(_busy ? 'Сохранение…' : 'ВЗЯЛ НАЛИЧНЫЕ'),
            ),
        ],
      ),
    );
  }
}
