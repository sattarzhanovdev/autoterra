import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../common/premium_icon_badge.dart';

/// Opens the styled courier-assignment sheet for [task] and returns `true`
/// if a courier was successfully assigned.
Future<bool?> showAssignCourierSheet(BuildContext context, CourierTask task) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AssignCourierSheet(task: task),
  );
}

class AssignCourierSheet extends StatefulWidget {
  final CourierTask task;
  const AssignCourierSheet({super.key, required this.task});

  @override
  State<AssignCourierSheet> createState() => _AssignCourierSheetState();
}

class _AssignCourierSheetState extends State<AssignCourierSheet> {
  String? _selectedCourierId;
  bool _loadingCouriers = true;
  bool _saving = false;
  List<Map<String, dynamic>> _couriers = [];

  @override
  void initState() {
    super.initState();
    DataRepository().distributorCouriers().then((data) {
      if (mounted) setState(() { _couriers = data; _loadingCouriers = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loadingCouriers = false);
    });
  }

  Future<void> _confirm() async {
    if (_selectedCourierId == null) return;
    setState(() => _saving = true);
    try {
      await DataRepository().updateDeliveryStatus(
        widget.task.id,
        status: 'assigned',
        courierId: _selectedCourierId,
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
    final task = widget.task;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              const PremiumIconBadge(icon: Icons.delivery_dining_outlined, size: 40, iconSize: 20, iconColor: AppColors.brandRed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'НАЗНАЧИТЬ КУРЬЕРА',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    Text(
                      task.typeDisplay.toUpperCase(),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(height: 24),

          _SheetRow(icon: Icons.person_outline, label: 'Клиент', value: task.clientName),
          _SheetRow(icon: Icons.location_on_outlined, label: 'Адрес', value: task.address),
          if (task.timeSlot.isNotEmpty)
            _SheetRow(icon: Icons.schedule_outlined, label: 'Время', value: task.timeSlot),

          const SizedBox(height: 16),
          const Text(
            'ВЫБЕРИТЕ КУРЬЕРА',
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
              hint: const Text('Курьер'),
              items: _couriers
                  .map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'])))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCourierId = v),
            ),

          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: (_saving || _selectedCourierId == null) ? null : _confirm,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('НАЗНАЧИТЬ КУРЬЕРА', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SheetRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
