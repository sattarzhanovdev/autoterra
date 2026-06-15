import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/common/status_badge.dart';

class DistributorColorLabScreen extends StatefulWidget {
  const DistributorColorLabScreen({super.key});

  @override
  State<DistributorColorLabScreen> createState() => _DistributorColorLabScreenState();
}

class _DistributorColorLabScreenState extends State<DistributorColorLabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<ColorRequest> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await DataRepository().distributorColorRequests();
      if (mounted) {
        setState(() {
          _requests = requests;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _requests
        .where((r) =>
            r.status != ColorRequestStatus.delivered &&
            r.status != ColorRequestStatus.cancelled)
        .toList();
    final history = _requests
        .where((r) =>
            r.status == ColorRequestStatus.delivered ||
            r.status == ColorRequestStatus.cancelled)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('COLOR LAB (ПОДБОР)'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'АКТИВНЫЕ'),
            Tab(text: 'ИСТОРИЯ'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('ПОВТОРИТЬ')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildList(active, emptyText: 'НЕТ АКТИВНЫХ ЗАЯВОК'),
                    _buildList(history, emptyText: 'ИСТОРИЯ ПУСТА'),
                  ],
                ),
    );
  }

  Widget _buildList(List<ColorRequest> items, {required String emptyText}) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 220),
            Center(child: Text(emptyText, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _ColorLabCard(request: items[i], onUpdate: _load),
      ),
    );
  }
}

class _ColorLabCard extends StatelessWidget {
  final ColorRequest request;
  final VoidCallback onUpdate;
  const _ColorLabCard({required this.request, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final status = request.status;
    final canProcess = status == ColorRequestStatus.created ||
        status == ColorRequestStatus.pickedUp ||
        status == ColorRequestStatus.inProgress;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PremiumIconBadge(
                icon: Icons.colorize_outlined,
                size: 36,
                iconSize: 18,
                iconColor: AppColors.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.carBrand} ${request.carModel}'.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    Text(
                      'Код: ${request.colorCode} · ${request.clientName ?? "Клиент"}'.toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              StatusBadge.fromColorStatus(request.status),
            ],
          ),
          if (request.colorName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.color_lens_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  request.colorName.toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          if (request.comment != null && request.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.comment_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.comment!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (request.recipe != null && request.recipe!.isNotEmpty) ...[
            const Divider(height: 24, thickness: 0.5),
            Row(
              children: [
                const Icon(Icons.science_outlined, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                const Text('РЕЦЕПТ:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              request.recipe!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (canProcess) ...[
            const Divider(height: 24, thickness: 0.5),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showCompleteSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlack,
                  minimumSize: const Size(0, 34),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('ЗАВЕРШИТЬ ПОДБОР',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCompleteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompleteSheet(request: request, onUpdate: onUpdate),
    );
  }
}

class _CompleteSheet extends StatefulWidget {
  final ColorRequest request;
  final VoidCallback onUpdate;
  const _CompleteSheet({required this.request, required this.onUpdate});

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  final _recipeCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _recipeCtrl.text = widget.request.recipe ?? '';
  }

  @override
  void dispose() {
    _recipeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_recipeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите формулу/рецепт')));
      return;
    }
    setState(() => _saving = true);
    try {
      await DataRepository().distributorUpdateColorRequest(widget.request.id, {
        'status': 'ready',
        'recipe': _recipeCtrl.text.trim(),
      });
      if (mounted) {
        widget.onUpdate();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Подбор завершен, клиент уведомлен'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ЗАВЕРШЕНИЕ ПОДБОРА',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.request.carBrand} ${widget.request.carModel} · ${widget.request.colorCode}'.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          if (widget.request.clientName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Клиент: ${widget.request.clientName}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _recipeCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'РЕЦЕПТ / ФОРМУЛА КРАСКИ',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ГОТОВО (УВЕДОМИТЬ КЛИЕНТА)', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
