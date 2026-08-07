import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../common/premium_icon_badge.dart';

/// Opens the styled order-acceptance sheet for [order] and returns `true` if
/// the order was accepted (with a courier + delivery date for courier orders,
/// or directly for self-pickup orders).
Future<bool?> showAssignOrderCourierSheet(BuildContext context, Order order, NumberFormat fmt) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AssignOrderCourierSheet(order: order, fmt: fmt),
  );
}

class AssignOrderCourierSheet extends StatefulWidget {
  final Order order;
  final NumberFormat fmt;
  const AssignOrderCourierSheet({super.key, required this.order, required this.fmt});

  @override
  State<AssignOrderCourierSheet> createState() => _AssignOrderCourierSheetState();
}

class _AssignOrderCourierSheetState extends State<AssignOrderCourierSheet> {
  String? _selectedCourierId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _loadingCouriers = true;
  bool _saving = false;
  List<Map<String, dynamic>> _couriers = [];

  bool get _isSelfPickup => widget.order.deliveryMethod == 'self_pickup';

  @override
  void initState() {
    super.initState();
    if (_isSelfPickup) {
      _loadingCouriers = false;
    } else {
      DataRepository().distributorCouriers().then((data) {
        if (mounted) setState(() { _couriers = data; _loadingCouriers = false; });
      }).catchError((_) {
        if (mounted) setState(() => _loadingCouriers = false);
      });
    }
  }

  Future<void> _submit() async {
    if (!_isSelfPickup && _selectedCourierId == null) return;
    setState(() => _saving = true);
    try {
      await DataRepository().updateOrderStatus(
        widget.order.id,
        status: 'accepted',
        courierId: _isSelfPickup ? null : _selectedCourierId,
        estimatedDeliveryDate: _isSelfPickup ? null : DateFormat('yyyy-MM-dd').format(_selectedDate),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final fmt = widget.fmt;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const PremiumIconBadge(icon: Icons.delivery_dining_outlined, size: 40, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSelfPickup ? 'ПРИНЯТЬ ЗАКАЗ' : 'НАЗНАЧИТЬ ДОСТАВКУ',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      Text(
                        order.documentNumber.toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(height: 24),

            const Text(
              'ДЕТАЛИ ЗАКАЗА',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.brandRed, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Клиент',
              value: order.clientName ?? 'ID: ${order.clientId}',
            ),
            _DetailRow(icon: Icons.store_outlined, label: 'Магазин', value: order.storeName),
            _DetailRow(
              icon: Icons.local_shipping_outlined,
              label: 'Получение',
              value: _isSelfPickup ? 'Самовывоз' : 'Курьером',
            ),
            _DetailRow(
              icon: Icons.payments_outlined,
              label: 'Сумма',
              value: '${fmt.format(order.totalAmount)} ₽',
              valueColor: AppColors.brandRed,
            ),
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 5, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.name} × ${item.quantity}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )),
            ],

            if (!_isSelfPickup) ...[
              const Divider(height: 24),
              const Text(
                'КУРЬЕР',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.brandRed, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              if (_loadingCouriers)
                const LinearProgressIndicator()
              else if (_couriers.isEmpty)
                const Text(
                  'Нет доступных курьеров',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedCourierId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text('Выберите курьера'),
                  items: _couriers
                      .map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'])))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCourierId = v),
                ),
              const SizedBox(height: 16),

              const Text(
                'ОЖИДАЕМАЯ ДАТА',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.brandRed, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd.MM.yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Icon(Icons.calendar_today, size: 18, color: AppColors.brandRed),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: (_saving || (!_isSelfPickup && _selectedCourierId == null)) ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('В РАБОТУ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
