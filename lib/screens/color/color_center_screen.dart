import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
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
        title: const Text('Подбор цвета'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Заявки'),
            Tab(text: 'История'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildRequestsTab(), _buildHistoryTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewRequestDialog(),
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Подобрать цвет',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                Center(child: Text('Нет активных заявок по цвету')),
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
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                Center(child: Text('История пуста')),
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
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = requests[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
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
                              '${r.carBrand} ${r.carModel}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${r.colorCode} · ${r.colorName}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              DateFormat('dd.MM.yyyy').format(r.createdAt),
                              style: const TextStyle(
                                color: AppColors.textHint,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge.fromColorStatus(r.status),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showRecipe(ColorRequest request) {
    if (request.recipe == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.science_outlined,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Рецепт цвета',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InfoRow(
              label: 'Автомобиль',
              value: '${request.carBrand} ${request.carModel}',
            ),
            InfoRow(label: 'Код цвета', value: request.colorCode),
            InfoRow(label: 'Цвет', value: request.colorName),
            InfoRow(label: 'VIN', value: request.vin),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Состав',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request.recipe!,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Понятно'),
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
    return Card(
      child: InkWell(
        onTap: request.status == ColorRequestStatus.ready ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.palette_outlined,
                      color: Color(0xFF8B5CF6),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request.carBrand} ${request.carModel}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'VIN: ${request.vin}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge.fromColorStatus(request.status),
                      if (request.urgent) ...[
                        const SizedBox(height: 4),
                        const StatusBadge(
                          label: 'Срочно',
                          color: AppColors.error,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _infoChip(
                    Icons.color_lens_outlined,
                    '${request.colorCode} · ${request.colorName}',
                    const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 8),
                  _infoChip(
                    Icons.calendar_today_outlined,
                    DateFormat('dd.MM.yyyy').format(request.createdAt),
                    AppColors.textSecondary,
                  ),
                ],
              ),
              if (request.status == ColorRequestStatus.ready) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Рецепт готов. Нажмите для просмотра',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: AppColors.success,
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
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
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
  bool _urgent = false;
  bool _courierPickup = false;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await const ApiClient().createColorRequest({
        'carBrand': _brandCtrl.text,
        'carModel': _modelCtrl.text,
        'vin': _vinCtrl.text,
        'colorCode': _colorCodeCtrl.text,
        'colorName': _colorNameCtrl.text,
        'urgent': _urgent,
        'courierPickup': _courierPickup,
      });
      if (!mounted) return;
      widget.onCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заявка на подбор цвета создана'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Новая заявка на подбор',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '1. Автомобиль',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brandCtrl,
                        decoration: const InputDecoration(labelText: 'Марка *'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _modelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Модель *',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'VIN или госномер',
                    prefixIcon: Icon(Icons.confirmation_num_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '2. Цвет',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: _colorCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Код цвета',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _colorNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Название цвета',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.primary.withOpacity(0.6),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Добавить фото лючка',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _urgent,
                  onChanged: (v) => setState(() => _urgent = v),
                  title: const Text(
                    'Срочно',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'Приоритетная обработка',
                    style: TextStyle(fontSize: 12),
                  ),
                  activeColor: AppColors.accent,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: _courierPickup,
                  onChanged: (v) => setState(() => _courierPickup = v),
                  title: const Text(
                    'Забрать лючок курьером',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'Дополнительная услуга внутри этой заявки',
                    style: TextStyle(fontSize: 12),
                  ),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(_saving ? 'Создаём...' : 'Создать заявку'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
