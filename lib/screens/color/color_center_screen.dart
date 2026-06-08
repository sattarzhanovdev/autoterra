import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/premium_icon_badge.dart';

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
    _future = DataRepository().colorRequests();
  }

  void _reload() {
    setState(() {
      _future = DataRepository().colorRequests();
    });
  }

  Future<void> _refresh() async {
    final next = DataRepository().colorRequests();
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
        title: const Text('ПОДБОР ЦВЕТА'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.brandRed,
          unselectedLabelColor: Colors.white,
          indicatorColor: AppColors.brandRed,
          indicatorWeight: 3,
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
    return FutureBuilder<List<ColorRequest>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.brandRed));
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
                Center(child: Text('НЕТ АКТИВНЫХ ЗАЯВОК')),
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
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ColorCard(
              request: requests[i],
              onTap: () => _showRecipe(requests[i]),
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
          return const Center(child: CircularProgressIndicator(color: AppColors.brandRed));
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
                Center(child: Text('ИСТОРИЯ ПУСТА')),
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
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = requests[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
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
                                '${r.carBrand} ${r.carModel}'.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              Text(
                                '${r.colorCode} · ${r.colorName}'.toUpperCase(),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge.fromColorStatus(r.status),
                      ],
                    ),
                    if (r.slaDeadline != null) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('SLA DEADLINE:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          Text(
                            DateFormat('dd.MM.yyyy HH:mm').format(r.slaDeadline!),
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.bold, 
                              color: r.isOverdue ? AppColors.brandRed : AppColors.success
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showRecipe(ColorRequest request) {
    if (request.recipe == null) {
      return;
    }
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: request.status == ColorRequestStatus.ready ? onTap : null,
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
  const _NewColorRequestSheet({required this.onCreated});

  @override
  State<_NewColorRequestSheet> createState() => _NewColorRequestSheetState();
}

class _NewColorRequestSheetState extends State<_NewColorRequestSheet> {
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  final _colorCodeCtrl = TextEditingController();
  final _colorNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  String _transferMethod = 'courier';
  DateTime? _pickupTime;
  XFile? _photo;
  Uint8List? _webBytes;
  final bool _urgent = false;
  bool _saving = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.camera);
    if (img != null) {
      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        setState(() {
          _photo = img;
          _webBytes = bytes;
        });
      } else {
        setState(() => _photo = img);
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final bytes = _webBytes ?? (_photo != null ? await _photo!.readAsBytes() : null);
      await DataRepository().createColorRequest({
        'carBrand': _brandCtrl.text,
        'carModel': _modelCtrl.text,
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
      }, fileBytes: bytes, fileName: _photo?.name);
      
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          AppBar(
            title: const Text('НОВАЯ ЗАЯВКА', style: TextStyle(fontWeight: FontWeight.w900)),
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
                TextFormField(controller: _vinCtrl, decoration: const InputDecoration(labelText: 'VIN / ГОСНОМЕР')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _colorCodeCtrl, decoration: const InputDecoration(labelText: 'КОД ЦВЕТА'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: _colorNameCtrl, decoration: const InputDecoration(labelText: 'НАЗВАНИЕ ЦВЕТА'))),
                  ],
                ),
                const SizedBox(height: 24),
                _sectionTitle('2. ФОТО ЛЮЧКА'),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(color: AppColors.canvas, border: Border.all(color: AppColors.border)),
                    child: _photo == null 
                      ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: AppColors.brandRed), Text('ДОБАВИТЬ ФОТО', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))])
                      : kIsWeb
                        ? Image.memory(_webBytes!, fit: BoxFit.cover)
                        : Image.file(File(_photo!.path), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 24),
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
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandRed),
                    child: Text(_saving ? 'ОТПРАВКА...' : 'ОТПРАВИТЬ ЗАЯВКУ'),
                  ),
                ),
              ],
            ),
          ),
        ],
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
