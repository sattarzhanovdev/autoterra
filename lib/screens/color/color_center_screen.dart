import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/common/attachment_picker.dart';

class ColorCenterScreen extends StatefulWidget {
  const ColorCenterScreen({super.key});

  @override
  State<ColorCenterScreen> createState() => _ColorCenterScreenState();
}

class _ColorCenterScreenState extends State<ColorCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Future<List<ColorRequest>> _future;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _future = const DataRepository().colorRequests();
  }

  void _reload() {
    setState(() {
      _future = const DataRepository().colorRequests();
    });
  }

  Future<void> _refresh() async {
    final next = const DataRepository().colorRequests();
    setState(() => _future = next);
    await next;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('COLOR LAB'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppColors.brandRed,
          tabs: const [
            Tab(text: 'ЗАЯВКИ'),
            Tab(text: 'ИСТОРИЯ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildRequestsTab(), _buildHistoryTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewRequestDialog(),
        backgroundColor: AppColors.brandBlack,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'СОЗДАТЬ ЗАЯВКУ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return FutureBuilder<List<ColorRequest>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final requests = snapshot.data!
            .where((item) => item.status != ColorRequestStatus.delivered)
            .toList();
        if (requests.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 220),
                Center(child: Text('НЕТ АКТИВНЫХ ЗАЯВОК', style: TextStyle(fontWeight: FontWeight.w700))),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ColorCard(
              request: requests[i],
              onTap: () => _showDetail(requests[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<List<ColorRequest>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 220),
                Center(child: Text('ИСТОРИЯ ПУСТА', style: TextStyle(fontWeight: FontWeight.w700))),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = requests[i];
              return _ColorCard(request: r, onTap: () => _showDetail(r));
            },
          ),
        );
      },
    );
  }

  void _showDetail(ColorRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ColorRequestDetailSheet(request: request),
    );
  }

  void _showNewRequestDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewColorRequestSheet(onCreated: _reload),
    );
  }
}

class _ColorCard extends StatelessWidget {
  final ColorRequest request;
  final VoidCallback? onTap;
  const _ColorCard({required this.request, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final slaColor = request.isOverdue ? AppColors.brandRed : AppColors.brandBlack;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumIconBadge(
                    icon: Icons.palette_outlined,
                    size: 44,
                    iconSize: 22,
                    iconColor: AppColors.brandBlack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '  '.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'VIN: ',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.timer_sharp, size: 12, color: slaColor),
                            const SizedBox(width: 6),
                            Text(
                              request.slaDeadline != null
                                  ? 'SLA: '
                                  : 'SLA: НЕ ЗАДАН',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: slaColor,
                              ),
                            ),
                            if (request.isOverdue) ...[
                              const SizedBox(width: 6),
                              const Text(
                                '(ПРОСРОЧЕНО)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.brandRed,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge.fromColorStatus(request.status),
                      if (request.urgent) ...[
                        const SizedBox(height: 6),
                        const StatusBadge(
                          label: 'СРОЧНО',
                          color: AppColors.brandRed,
                          filled: true,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1.5),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _infoChip(
                    Icons.color_lens_sharp,
                    ' · '.toUpperCase(),
                    AppColors.brandBlack,
                  ),
                  _infoChip(
                    Icons.calendar_today_sharp,
                    DateFormat('dd.MM.yy').format(request.createdAt),
                    AppColors.textSecondary,
                  ),
                ],
              ),
              if (request.status == ColorRequestStatus.ready) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlack,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_sharp, color: AppColors.brandRed, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'РЕЦЕПТ ГОТОВ. НАЖМИТЕ ДЛЯ ПРОСМОТРА',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ColorRequestDetailSheet extends StatelessWidget {
  final ColorRequest request;
  const _ColorRequestDetailSheet({required this.request});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            color: AppColors.brandBlack,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text(
                  'ДЕТАЛИ ЗАЯВКИ',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_sharp),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(thickness: 2, color: AppColors.brandBlack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatusBadge.fromColorStatus(request.status),
                    Text(
                      'СОЗДАНА: ',
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _section('АВТОМОБИЛЬ'),
                _infoRow('МАРКА/МОДЕЛЬ', ' '.toUpperCase()),
                if (request.carYear != null) _infoRow('ГОД', request.carYear!),
                _infoRow('VIN', request.vin),

                const SizedBox(height: 24),
                _section('ЦВЕТ'),
                _infoRow('КОД ЦВЕТА', request.colorCode),
                _infoRow('НАЗВАНИЕ', request.colorName.toUpperCase()),
                if (request.comment != null) _infoRow('КОММЕНТАРИЙ', request.comment!),

                const SizedBox(height: 24),
                _section('ПАРАМЕТРЫ ЗАБОРА/ДОСТАВКИ'),
                _infoRow('СПОСОБ', request.deliveryMethod == 'courier' ? 'КУРЬЕР' : 'САМОВЫВОЗ'),
                if (request.courierPickup) ...[
                  _infoRow('ЗАБОР ЛЮЧКА', 'ДА'),
                  if (request.pickupAddress != null) _infoRow('АДРЕС ЗАБОРА', request.pickupAddress!.toUpperCase()),
                  if (request.pickupDate != null) _infoRow('ДАТА ЗАБОРА', dateFormat.format(request.pickupDate!)),
                ],
                if (request.contactPerson != null) _infoRow('КОНТАКТ', request.contactPerson!.toUpperCase()),
                if (request.contactPhone != null) _infoRow('ТЕЛЕФОН', request.contactPhone!),

                if (request.courierTasks.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('ЗАДАЧИ КУРЬЕРА', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  ...request.courierTasks.map((t) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border, width: 1.5)),
                    child: ListTile(
                      dense: true,
                      title: Text(t.type == 'pickup' ? 'ЗАБОР ЛЮЧКА' : 'ДОСТАВКА', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      subtitle: Text(t.address.toUpperCase(), style: const TextStyle(fontSize: 11)),
                      trailing: StatusBadge(label: t.status.name.toUpperCase(), color: AppColors.brandBlack),
                    ),
                  )),
                ],

                const SizedBox(height: 24),
                _section('SLA'),
                _infoRow('ДЕДЛАЙН', request.slaDeadline != null ? dateFormat.format(request.slaDeadline!) : 'НЕ ЗАДАН'),
                if (request.isOverdue)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('ВНИМАНИЕ: ВРЕМЯ ВЫПОЛНЕНИЯ ПРЕВЫШЕНО', style: TextStyle(color: AppColors.brandRed, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),

                if (request.materials.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _section('РЕЦЕПТ (МАТЕРИАЛЫ)'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.brandWhite,
                      border: Border.all(color: AppColors.brandBlack, width: 1.5),
                    ),
                    child: Column(
                      children: request.materials.map((m) => ListTile(
                        dense: true,
                        title: Text(m.sku.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        trailing: Text(' ', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.brandRed)),
                        subtitle: m.comment != null ? Text(m.comment!.toUpperCase(), style: const TextStyle(fontSize: 10)) : null,
                      )).toList(),
                    ),
                  ),
                ] else if (request.recipe != null) ...[
                  const SizedBox(height: 24),
                  _section('РЕЦЕПТ (ТЕКСТ)'),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.brandWhite,
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: Text(request.recipe!, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],

                const SizedBox(height: 24),
                _section('ФОТО'),
                AttachmentList(attachments: request.attachments),

                const SizedBox(height: 24),
                _section('ИСТОРИЯ ИЗМЕНЕНИЙ'),
                ...request.statusHistory.reversed.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.history_sharp, size: 14, color: AppColors.brandBlack),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ' · ',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                            if (h.comment != null && h.comment!.isNotEmpty)
                              Text(h.comment!.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11,
          color: AppColors.textHint,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _NewColorRequestSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _NewColorRequestSheet({required this.onCreated});

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
  final _commentCtrl = TextEditingController();
  final _pickupAddressCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  DateTime? _pickupTime;
  List<PlatformFile> _attachments = [];
  bool _urgent = false;
  bool _courierPickup = false;
  String _deliveryMethod = 'courier';
  bool _saving = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _vinCtrl.dispose();
    _colorCodeCtrl.dispose();
    _colorNameCtrl.dispose();
    _commentCtrl.dispose();
    _pickupAddressCtrl.dispose();
    _contactPersonCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_brandCtrl.text.isEmpty || _modelCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ЗАПОЛНИТЕ ОБЯЗАТЕЛЬНЫЕ ПОЛЯ (*)'), backgroundColor: AppColors.brandRed),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await const ApiClient().createColorRequest(
        {
          'carBrand': _brandCtrl.text,
          'carModel': _modelCtrl.text,
          'carYear': _yearCtrl.text,
          'vin': _vinCtrl.text,
          'colorCode': _colorCodeCtrl.text,
          'colorName': _colorNameCtrl.text,
          'comment': _commentCtrl.text,
          'urgent': _urgent,
          'courierPickup': _courierPickup,
          'pickupAddress': _pickupAddressCtrl.text,
          'pickupTime': _pickupTime?.toIso8601String(),
          'contactPerson': _contactPersonCtrl.text,
          'contactPhone': _contactPhoneCtrl.text,
          'deliveryMethod': _deliveryMethod,
        },
        attachments: _attachments,
      );
      if (!mounted) return;
      widget.onCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ЗАЯВКА СОЗДАНА'),
          backgroundColor: AppColors.brandBlack,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().toUpperCase()), backgroundColor: AppColors.brandRed),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            color: AppColors.brandBlack,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text(
                  'НОВАЯ ЗАЯВКА COLOR LAB',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_sharp),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(thickness: 2, color: AppColors.brandBlack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('1. АВТОМОБИЛЬ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.textHint, letterSpacing: 1.0)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'МАРКА *'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _modelCtrl, decoration: const InputDecoration(labelText: 'МОДЕЛЬ *'))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _yearCtrl, decoration: const InputDecoration(labelText: 'ГОД ВЫПУСКА'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _vinCtrl, decoration: const InputDecoration(labelText: 'VIN / ГОСНОМЕР'))),
                  ],
                ),

                const SizedBox(height: 28),
                const Text('2. ЦВЕТ И ДЕТАЛИ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.textHint, letterSpacing: 1.0)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(width: 120, child: TextFormField(controller: _colorCodeCtrl, decoration: const InputDecoration(labelText: 'КОД ЦВЕТА'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _colorNameCtrl, decoration: const InputDecoration(labelText: 'НАЗВАНИЕ ЦВЕТА'))),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _commentCtrl, decoration: const InputDecoration(labelText: 'КОММЕНТАРИЙ К ЗАКАЗУ'), maxLines: 3),
                const SizedBox(height: 20),
                AttachmentPicker(
                  title: 'ФОТО ДЛЯ ПОДБОРА',
                  emptyText: 'ФОТО ЛЮЧКА ИЛИ АВТОМОБИЛЯ',
                  files: _attachments,
                  onChanged: (files) => setState(() => _attachments = files),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _urgent,
                  onChanged: (v) => setState(() => _urgent = v),
                  title: const Text('СРОЧНО', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  subtitle: const Text('ПРИОРИТЕТНАЯ ОБРАБОТКА (SLA 4Ч)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  activeColor: AppColors.brandRed,
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 28),
                const Text('3. ЗАБОР И ДОСТАВКА', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.textHint, letterSpacing: 1.0)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _deliveryMethod,
                  decoration: const InputDecoration(labelText: 'СПОСОБ ПОЛУЧЕНИЯ'),
                  items: const [
                    DropdownMenuItem(value: 'courier', child: Text('ДОСТАВКА КУРЬЕРОМ')),
                    DropdownMenuItem(value: 'self', child: Text('САМОВЫВОЗ')),
                  ],
                  onChanged: (v) => setState(() => _deliveryMethod = v!),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _courierPickup,
                  onChanged: (v) => setState(() => _courierPickup = v),
                  title: const Text('ЗАБРАТЬ ЛЮЧОК КУРЬЕРОМ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  subtitle: const Text('СОЗДАТЬ ЗАДАЧУ ДЛЯ КУРЬЕРА', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  activeColor: AppColors.brandBlack,
                  contentPadding: EdgeInsets.zero,
                ),
                if (_courierPickup) ...[
                  const SizedBox(height: 12),
                  TextFormField(controller: _pickupAddressCtrl, decoration: const InputDecoration(labelText: 'АДРЕС ЗАБОРА', prefixIcon: Icon(Icons.location_on_sharp))),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                      if (date == null || !mounted) return;
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (time == null) return;
                      setState(() { _pickupTime = DateTime(date.year, date.month, date.day, time.hour, time.minute); });
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'ВРЕМЯ ЗАБОРА', prefixIcon: Icon(Icons.schedule_sharp)),
                      child: Text(_pickupTime == null ? 'ВЫБЕРИТЕ ВРЕМЯ' : DateFormat('dd.MM.yyyy HH:mm').format(_pickupTime!)),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _contactPersonCtrl, decoration: const InputDecoration(labelText: 'КОНТАКТНОЕ ЛИЦО'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _contactPhoneCtrl, decoration: const InputDecoration(labelText: 'ТЕЛЕФОН'), keyboardType: TextInputType.phone)),
                  ],
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), backgroundColor: AppColors.brandRed),
                    child: Text(_saving ? 'ОТПРАВКА...' : 'ОТПРАВИТЬ ЗАЯВКУ', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
