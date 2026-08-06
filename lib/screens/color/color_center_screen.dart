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
      useSafeArea: true,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(color: Colors.white),
        // Нижний отступ — под системную навигацию Android: useSafeArea
        // прикрывает только верх.
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.viewPaddingOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'РЕЦЕПТ ЦВЕТА',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
            ),
            const SizedBox(height: 16),
            InfoRow(label: 'МАРКА', value: request.carLabel.toUpperCase()),
            InfoRow(label: 'КОД ЦВЕТА', value: request.colorCode.toUpperCase()),
            InfoRow(label: 'ЦВЕТ', value: request.colorName.toUpperCase()),
            InfoRow(label: 'ТИП ПОКРЫТИЯ', value: request.paintTypeLabel.toUpperCase()),
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
                          request.carLabel.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        if (request.vin.isNotEmpty)
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoChip(Icons.color_lens_outlined, '${request.colorCode} · ${request.colorName}'.toUpperCase()),
                        const SizedBox(height: 6),
                        _infoChip(Icons.layers_outlined, request.paintTypeLabel.toUpperCase()),
                      ],
                    ),
                  ),
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
  final _colorCodeCtrl = TextEditingController();
  final _colorNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  String _transferMethod = 'courier';

  /// Тип покрытия. В новой заявке не предзаполняем: от него зависит цена,
  /// выбор должен быть осознанным.
  PaintCoatingType? _paintType;

  /// Уточнение к покрытию своими словами: три варианта покрывают почти всё,
  /// но состав бывает нестандартный, и колористу это надо передать.
  final _paintNoteCtrl = TextEditingController();
  DateTime? _pickupTime;

  /// Крайнее время, до которого маляр готов принять курьера за лючком.
  TimeOfDay? _arriveUntil;
  bool _urgent = false;
  bool _saving = false;

  /// Время «до» в формате, который ждёт API, — «HH:MM».
  String? get _arriveUntilText => _arriveUntil == null
      ? null
      : '${_arriveUntil!.hour.toString().padLeft(2, '0')}:'
          '${_arriveUntil!.minute.toString().padLeft(2, '0')}';

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool get _hasChanges {
    if (widget.initialRequest == null) {
      return _brandCtrl.text.isNotEmpty || _colorCodeCtrl.text.isNotEmpty;
    }
    final r = widget.initialRequest!;
    if (_brandCtrl.text != r.carBrand) return true;
    if (_paintNoteCtrl.text != (r.paintTypeNote ?? '')) return true;
    if (_colorCodeCtrl.text != r.colorCode) return true;
    if (_colorNameCtrl.text != r.colorName) return true;
    if (_paintType != r.paintType) return true;
    if (_addressCtrl.text != (r.pickupAddress ?? '')) return true;
    if (_contactPersonCtrl.text != (r.contactPerson ?? '')) return true;
    if (_contactPhoneCtrl.text != (r.contactPhone ?? '')) return true;
    if (_commentCtrl.text != (r.comment ?? '')) return true;
    if (_transferMethod != r.transferMethod) return true;
    if (_pickupTime != r.pickupTime) return true;
    if (_arriveUntilText != r.courierArriveUntil) return true;
    if (_urgent != r.urgent) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialRequest != null) {
      final r = widget.initialRequest!;
      _brandCtrl.text = r.carBrand;
      _paintNoteCtrl.text = r.paintTypeNote ?? '';
      _colorCodeCtrl.text = r.colorCode;
      _colorNameCtrl.text = r.colorName;
      _paintType = r.paintType;
      _addressCtrl.text = r.pickupAddress ?? '';
      _contactPersonCtrl.text = r.contactPerson ?? '';
      _contactPhoneCtrl.text = r.contactPhone ?? '';
      _commentCtrl.text = r.comment ?? '';
      _transferMethod = r.transferMethod;
      _pickupTime = r.pickupTime;
      _arriveUntil = _parseTime(r.courierArriveUntil);
      _urgent = r.urgent;
    }

    // Refresh UI when any text changes to update button state
    for (final controller in [
      _brandCtrl, _colorCodeCtrl, _colorNameCtrl, _paintNoteCtrl,
      _addressCtrl, _contactPersonCtrl, _contactPhoneCtrl, _commentCtrl
    ]) {
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _submit() async {
    // Марка и код — то, по чему колорист подбирает цвет. Раньше обязательной
    // была модель, но для подбора она ничего не даёт.
    if (_brandCtrl.text.trim().isEmpty || _colorCodeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('УКАЖИТЕ МАРКУ И КОД ЦВЕТА'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final paintType = _paintType;
    if (paintType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ВЫБЕРИТЕ ТИП ПОКРЫТИЯ'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.initialRequest != null) {
        await DataRepository().updateColorRequest(widget.initialRequest!.id, {
          'carBrand': _brandCtrl.text,
          'paintTypeNote': _paintNoteCtrl.text.trim(),
          'colorCode': _colorCodeCtrl.text,
          'colorName': _colorNameCtrl.text,
          'paintType': paintType.name,
          'urgent': _urgent,
          'transferMethod': _transferMethod,
          'pickupAddress': _addressCtrl.text,
          'pickupTime': _pickupTime?.toIso8601String(),
          'courierArriveUntil': _arriveUntilText,
          'contactPerson': _contactPersonCtrl.text,
          'contactPhone': _contactPhoneCtrl.text,
          'comment': _commentCtrl.text,
        });
      } else {
        await DataRepository().createColorRequest({
          'carBrand': _brandCtrl.text,
          'paintTypeNote': _paintNoteCtrl.text.trim(),
          'colorCode': _colorCodeCtrl.text,
          'colorName': _colorNameCtrl.text,
          'paintType': paintType.name,
          'urgent': _urgent,
          'transferMethod': _transferMethod,
          'pickupAddress': _addressCtrl.text,
          'pickupTime': _pickupTime?.toIso8601String(),
          'courierArriveUntil': _arriveUntilText,
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
                // Цвет определяют марка и код. Модель, VIN и год для подбора
                // не нужны — они только удлиняли форму.
                _sectionTitle('1. МАРКА И ЦВЕТ'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brandCtrl,
                  decoration: const InputDecoration(labelText: 'МАРКА *'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _colorCodeCtrl, decoration: const InputDecoration(labelText: 'КОД ЦВЕТА *'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: _colorNameCtrl, decoration: const InputDecoration(labelText: 'НАЗВАНИЕ ЦВЕТА'))),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle('2. ТИП ПОКРЫТИЯ'),
                const SizedBox(height: 6),
                const Text(
                  'От типа покрытия зависят состав рецепта и цена — по нему же считается добор краски.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                ...PaintCoatingType.values.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _paintTypeTile(type),
                  ),
                ),
                const SizedBox(height: 8),
                // Три варианта покрывают почти всё, но состав бывает
                // нестандартный — тогда маляр дописывает его словами.
                TextFormField(
                  controller: _paintNoteCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'УТОЧНЕНИЕ ПО ПОКРЫТИЮ',
                    hintText: 'Например: перламутр в 3 слоя, матовый лак',
                    helperText: 'Если ни один вариант не описывает состав точно',
                  ),
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
                _sectionTitle('3. ПЕРЕДАЧА ЛЮЧКА'),
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
                  const SizedBox(height: 12),
                  // Дедлайн приезда: колорист и курьер планируют выезд по нему,
                  // иначе курьер приезжает, когда маляра уже нет на месте.
                  InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _arriveUntil ?? const TimeOfDay(hour: 18, minute: 0),
                        helpText: 'ДО СКОЛЬКИ МОЖЕТ ПРИЕХАТЬ КУРЬЕР?',
                      );
                      if (time != null) setState(() => _arriveUntil = time);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'ДО СКОЛЬКИ МОЖЕТ ПРИЕХАТЬ КУРЬЕР?',
                        helperText: 'Курьер приедет за лючком не позже этого времени',
                        suffixIcon: _arriveUntil == null
                            ? const Icon(Icons.schedule_outlined, size: 20)
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => _arriveUntil = null),
                              ),
                      ),
                      child: Text(
                        _arriveUntilText ?? 'НЕ ОГРАНИЧЕНО',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _arriveUntil == null ? AppColors.textHint : AppColors.textPrimary,
                        ),
                      ),
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

  /// Галочка на один из трёх типов покрытия: акрил, база + лак, трёхстадийная.
  Widget _paintTypeTile(PaintCoatingType type) {
    final selected = _paintType == type;
    return InkWell(
      onTap: () => setState(() => _paintType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandBlack : Colors.white,
          border: Border.all(color: selected ? AppColors.brandBlack : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: selected ? Colors.white : AppColors.textHint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5,
                      color: selected ? Colors.white : AppColors.brandBlack,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.white70 : AppColors.textSecondary,
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
