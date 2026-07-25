import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/premium_icon_badge.dart';

class ColorCenterScreen extends StatefulWidget {
  const ColorCenterScreen({super.key});

  @override
  State<ColorCenterScreen> createState() => _ColorCenterScreenState();
}

class _ColorCenterScreenState extends State<ColorCenterScreen> {
  late final PaginationController<ColorRequest> _controller;

  @override
  void initState() {
    super.initState();
    // Завершённые и отменённые заявки отсекает сервер.
    _controller = PaginationController<ColorRequest>(
      fetchPage: (page) => DataRepository().colorRequests(page: page, activeOnly: true),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reload() {
    _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ПОДБОР ЦВЕТА'),
      ),
      body: _buildRequestsTab(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewRequestDialog(),
        backgroundColor: AppColors.brandRed,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'ПОДОБРАТЬ ЦВЕТ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return PaginatedListView<ColorRequest>(
      controller: _controller,
      separator: const SizedBox(height: 12),
      emptyMessage: 'НЕТ АКТИВНЫХ ЗАЯВОК',
      itemBuilder: (context, request, _) => _ColorCard(
        request: request,
        onTap: () => _showRecipe(request),
        onUpdate: _reload,
      ),
    );
  }

  void _showRecipe(ColorRequest request) {
    if (request.recipe == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'РЕЦЕПТ ЦВЕТА',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
            ),
            const SizedBox(height: 16),
            InfoRow(label: 'АВТОМОБИЛЬ', value: '${request.carBrand} ${request.carModel}'.toUpperCase()),
            InfoRow(label: 'КОД ЦВЕТА', value: request.colorCode.toUpperCase()),
            InfoRow(label: 'ЦВЕТ', value: request.colorName.toUpperCase()),
            const Divider(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.canvas, border: Border.all(color: AppColors.border)),
              child: Text(
                request.recipe!,
                style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                child: const Text('ЗАКРЫТЬ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewRequestDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewColorRequestSheet(onCreated: _reload),
    );
  }
}

class _ColorCard extends StatelessWidget {
  final ColorRequest request;
  final VoidCallback? onTap;
  final VoidCallback? onUpdate;
  const _ColorCard({required this.request, this.onTap, this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final canAction = request.status == ColorRequestStatus.created;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () {
          if (request.status == ColorRequestStatus.ready) {
            onTap?.call();
          } else if (canAction) {
            _showEditMenu(context);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const PremiumIconBadge(
                    icon: Icons.palette_outlined,
                    size: 42,
                    iconSize: 22,
                    iconColor: AppColors.brandRed,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request.carBrand} ${request.carModel}'.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        Text(
                          'VIN: ${request.vin}'.toUpperCase(),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge.fromColorStatus(request.status),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  _infoChip(Icons.color_lens_outlined, '${request.colorCode} · ${request.colorName}'.toUpperCase()),
                  const Spacer(),
                  if (request.slaDeadline != null)
                    _infoChip(Icons.timer_outlined, 'ДО ${DateFormat('HH:mm').format(request.slaDeadline!)}', request.isOverdue ? AppColors.brandRed : AppColors.success),
                ],
              ),
              if (request.status == ColorRequestStatus.ready) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size(double.infinity, 36),
                    shape: const BeveledRectangleBorder(),
                  ),
                  child: const Text('СМОТРЕТЬ РЕЦЕПТ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewColorRequestSheet(
        initialRequest: request,
        onCreated: () => onUpdate?.call(),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, [Color color = AppColors.textSecondary]) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _NewColorRequestSheet extends StatefulWidget {
  final VoidCallback onCreated;
  final ColorRequest? initialRequest;
  const _NewColorRequestSheet({required this.onCreated, this.initialRequest});

  @override
  State<_NewColorRequestSheet> createState() => _NewColorRequestSheetState();
}

class _NewColorRequestSheetState extends State<_NewColorRequestSheet> {
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  final _colorCodeCtrl = TextEditingController();
  final _colorNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  String _transferMethod = 'courier';
  DateTime? _pickupTime;
  bool _urgent = false;
  bool _saving = false;

  bool get _hasChanges {
    if (widget.initialRequest == null) {
      return _brandCtrl.text.isNotEmpty || _modelCtrl.text.isNotEmpty;
    }
    final r = widget.initialRequest!;
    if (_brandCtrl.text != r.carBrand) return true;
    if (_modelCtrl.text != r.carModel) return true;
    if (_yearCtrl.text != r.carYear) return true;
    if (_vinCtrl.text != r.vin) return true;
    if (_colorCodeCtrl.text != r.colorCode) return true;
    if (_colorNameCtrl.text != r.colorName) return true;
    if (_addressCtrl.text != (r.pickupAddress ?? '')) return true;
    if (_contactPersonCtrl.text != (r.contactPerson ?? '')) return true;
    if (_contactPhoneCtrl.text != (r.contactPhone ?? '')) return true;
    if (_commentCtrl.text != (r.comment ?? '')) return true;
    if (_transferMethod != r.transferMethod) return true;
    if (_pickupTime != r.pickupTime) return true;
    if (_urgent != r.urgent) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialRequest != null) {
      final r = widget.initialRequest!;
      _brandCtrl.text = r.carBrand;
      _modelCtrl.text = r.carModel;
      _yearCtrl.text = r.carYear;
      _vinCtrl.text = r.vin;
      _colorCodeCtrl.text = r.colorCode;
      _colorNameCtrl.text = r.colorName;
      _addressCtrl.text = r.pickupAddress ?? '';
      _contactPersonCtrl.text = r.contactPerson ?? '';
      _contactPhoneCtrl.text = r.contactPhone ?? '';
      _commentCtrl.text = r.comment ?? '';
      _transferMethod = r.transferMethod;
      _pickupTime = r.pickupTime;
      _urgent = r.urgent;
    }

    // Refresh UI when any text changes to update button state
    for (final controller in [
      _brandCtrl, _modelCtrl, _yearCtrl, _vinCtrl, _colorCodeCtrl, _colorNameCtrl,
      _addressCtrl, _contactPersonCtrl, _contactPhoneCtrl, _commentCtrl
    ]) {
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      if (widget.initialRequest != null) {
        await DataRepository().updateColorRequest(widget.initialRequest!.id, {
          'carBrand': _brandCtrl.text,
          'carModel': _modelCtrl.text,
          'carYear': _yearCtrl.text,
          'vin': _vinCtrl.text,
          'colorCode': _colorCodeCtrl.text,
          'colorName': _colorNameCtrl.text,
          'urgent': _urgent,
          'transferMethod': _transferMethod,
          'pickupAddress': _addressCtrl.text,
          'pickupTime': _pickupTime?.toIso8601String(),
          'contactPerson': _contactPersonCtrl.text,
          'contactPhone': _contactPhoneCtrl.text,
          'comment': _commentCtrl.text,
        });
      } else {
        await DataRepository().createColorRequest({
          'carBrand': _brandCtrl.text,
          'carModel': _modelCtrl.text,
          'carYear': _yearCtrl.text,
          'vin': _vinCtrl.text,
          'colorCode': _colorCodeCtrl.text,
          'colorName': _colorNameCtrl.text,
          'urgent': _urgent,
          'transferMethod': _transferMethod,
          'pickupAddress': _addressCtrl.text,
          'pickupTime': _pickupTime?.toIso8601String(),
          'contactPerson': _contactPersonCtrl.text,
          'contactPhone': _contactPhoneCtrl.text,
          'comment': _commentCtrl.text,
        });
      }
      
      if (!mounted) return;
      widget.onCreated();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить заявку?'),
        content: const Text('Заявка будет аннулирована.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('НЕТ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('ОТМЕНИТЬ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await DataRepository().cancelColorRequest(widget.initialRequest!.id);
      if (!mounted) return;
      widget.onCreated();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            AppBar(
              title: Text(widget.initialRequest != null ? 'ИЗМЕНЕНИЕ ЗАЯВКИ' : 'НОВАЯ ЗАЯВКА', style: const TextStyle(fontWeight: FontWeight.w900)),
              automaticallyImplyLeading: false,
              actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))],
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _sectionTitle('1. АВТОМОБИЛЬ И ЦВЕТ'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'МАРКА *'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: _modelCtrl, decoration: const InputDecoration(labelText: 'МОДЕЛЬ *'))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(flex: 2, child: TextFormField(controller: _vinCtrl, decoration: const InputDecoration(labelText: 'VIN / ГОСНОМЕР'))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _yearCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        decoration: const InputDecoration(labelText: 'ГОД', counterText: ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _colorCodeCtrl, decoration: const InputDecoration(labelText: 'КОД ЦВЕТА'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: _colorNameCtrl, decoration: const InputDecoration(labelText: 'НАЗВАНИЕ ЦВЕТА'))),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.brandRed,
                  value: _urgent,
                  onChanged: (v) => setState(() => _urgent = v),
                  title: const Text('СРОЧНО', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                  subtitle: const Text('Сокращённый срок выполнения (SLA 4 часа)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 12),
                _sectionTitle('2. ПЕРЕДАЧА ЛЮЧКА'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _radioBtn('courier', 'КУРЬЕР'),
                    const SizedBox(width: 12),
                    _radioBtn('self_delivery', 'САМ ПРИВЕЗУ'),
                  ],
                ),
                if (_transferMethod == 'courier') ...[
                  const SizedBox(height: 16),
                  TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'АДРЕС ЗАБОРА *')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _contactPersonCtrl, decoration: const InputDecoration(labelText: 'КОНТАКТНОЕ ЛИЦО'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: _contactPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'ТЕЛЕФОН'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (time != null) {
                        final now = DateTime.now();
                        setState(() => _pickupTime = DateTime(now.year, now.month, now.day, time.hour, time.minute));
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'ВРЕМЯ ЗАБОРА'),
                      child: Text(_pickupTime == null ? 'НЕ ВЫБРАНО' : DateFormat('HH:mm').format(_pickupTime!)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TextFormField(controller: _commentCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'КОММЕНТАРИЙ')),
                const SizedBox(height: 32),
                if (widget.initialRequest != null)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: _saving ? null : _handleDelete,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                            ),
                            child: const Text('ОТМЕНИТЬ'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: (_saving || !_hasChanges) ? null : _submit,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                            child: Text(_saving ? 'СОХРАНЕНИЕ...' : 'ПОДТВЕРДИТЬ'),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (_saving || !_hasChanges) ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandRed),
                      child: Text(_saving ? 'ОТПРАВКА...' : 'ОТПРАВИТЬ ЗАЯВКУ'),
                    ),
                  ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5));

  Widget _radioBtn(String value, String label) {
    final selected = _transferMethod == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _transferMethod = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandBlack : Colors.white,
            border: Border.all(color: AppColors.brandBlack),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : AppColors.brandBlack, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ),
    );
  }
}
