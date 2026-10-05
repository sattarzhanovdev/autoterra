import '../clients/personal_prices_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../models/paginated.dart';
import '../../services/data_repository.dart';
import '../../services/api_client.dart';
import '../../core/theme.dart';

const _kStatusLabels = {
  'new': 'НОВЫЙ',
  'pending': 'ОЖИДАНИЕ',
  'under_review': 'НА ПРОВЕРКЕ',
  'active': 'АКТИВНЫЙ',
  'blocked': 'ЗАБЛОКИРОВАН',
  'archived': 'АРХИВ',
};

class ManagerClientDetailScreen extends StatefulWidget {
  final String clientId;
  const ManagerClientDetailScreen({super.key, required this.clientId});

  @override
  State<ManagerClientDetailScreen> createState() => _ManagerClientDetailScreenState();
}

class _ManagerClientDetailScreenState extends State<ManagerClientDetailScreen> {
  final _repo = DataRepository();
  Map<String, dynamic>? _unified;
  String? _loadError;
  List<Order> _orders = [];
  List<Purchase> _purchases = [];
  int _ordersPage = 1;
  int _purchasesPage = 1;
  bool _moreOrders = false;
  bool _morePurchases = false;
  bool _moreBusy = false;
  List<ContactHistoryEntry> _history = [];
  bool _loading = true;
  bool _historyLoading = false;
  bool _historyLoadingMore = false;
  bool _historyHasMore = false;
  int _historyPage = 1;
  int _historyTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.managerClientUnified(widget.clientId),
        _repo.managerClientHistory(widget.clientId),
        _repo.managerClientOrders(widget.clientId),
        _repo.managerClientPurchases(widget.clientId),
      ]);
      if (!mounted) return;
      setState(() {
        _unified = results[0] as Map<String, dynamic>;
        final historyPage = results[1] as Paginated<ContactHistoryEntry>;
        _history = historyPage.items;
        _historyHasMore = historyPage.hasNext;
        _historyTotal = historyPage.count;
        _historyPage = 1;
        final orders = results[2] as Paginated<Order>;
        final purchases = results[3] as Paginated<Purchase>;
        _orders = orders.items;
        _purchases = purchases.items;
        _moreOrders = orders.hasNext;
        _morePurchases = purchases.hasNext;
        _ordersPage = 1;
        _purchasesPage = 1;
        _loadError = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e.toString(); });
    }
  }

  Future<void> _loadMore({required bool orders}) async {
    if (_moreBusy) return;
    setState(() => _moreBusy = true);
    try {
      if (orders) {
        final page = await _repo.managerClientOrders(widget.clientId, page: _ordersPage + 1);
        if (mounted) setState(() { _orders = [..._orders, ...page.items]; _moreOrders = page.hasNext; _ordersPage++; });
      } else {
        final page = await _repo.managerClientPurchases(widget.clientId, page: _purchasesPage + 1);
        if (mounted) setState(() { _purchases = [..._purchases, ...page.items]; _morePurchases = page.hasNext; _purchasesPage++; });
      }
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _moreBusy = false);
    }
  }

  Future<void> _removeClient() async {
    final name = _unified?['client']?['name']?.toString() ?? '';
    final input = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Удалить клиента?'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Для подтверждения введите точное название: $name'),
        TextField(controller: input, autofocus: true, decoration: const InputDecoration(labelText: 'Название клиента')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ОТМЕНА')),
        TextButton(onPressed: () => Navigator.pop(ctx, input.text == name), child: const Text('УДАЛИТЬ'))],
    ));
    input.dispose();
    if (confirmed != true || !mounted) return;
    try {
      await _repo.managerRemoveClient(widget.clientId, name);
      if (mounted) context.pop();
    } on ApiException catch (error) {
      final details = error.details;
      if (details is Map && details['canArchive'] == true && mounted) {
        final archive = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Есть история заказов'),
          content: const Text('Удаление недоступно. Архивировать клиента и отключить вход, сохранив историю?'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ОТМЕНА')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('АРХИВИРОВАТЬ'))],
        ));
        if (archive == true) {
          try {
            await _repo.managerRemoveClient(widget.clientId, name, archive: true);
            if (mounted) context.pop();
          } catch (archiveError) { if (mounted) _showError(archiveError.toString()); }
        }
      } else if (mounted) { _showError(error.toString()); }
    } catch (error) { if (mounted) _showError(error.toString()); }
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final result = await _repo.managerClientHistory(widget.clientId);
      setState(() {
        _history = result.items;
        _historyHasMore = result.hasNext;
        _historyTotal = result.count;
        _historyPage = 1;
        _historyLoading = false;
      });
    } catch (_) {
      setState(() => _historyLoading = false);
    }
  }

  /// История контактов — вложенная секция карточки, поэтому вместо
  /// бесконечной прокрутки догружаем её кнопкой «показать ещё».
  Future<void> _loadMoreHistory() async {
    if (_historyLoadingMore || !_historyHasMore) return;
    setState(() => _historyLoadingMore = true);
    try {
      final result = await _repo.managerClientHistory(
        widget.clientId,
        page: _historyPage + 1,
      );
      setState(() {
        _history = [..._history, ...result.items];
        _historyHasMore = result.hasNext;
        _historyTotal = result.count;
        _historyPage += 1;
        _historyLoadingMore = false;
      });
    } catch (_) {
      setState(() => _historyLoadingMore = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Ошибка: $msg')));
  }

  void _openStatusChange() {
    final client = _unified?['client'];
    if (client == null) return;
    final currentStatus = client['status']?.toString() ?? 'active';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: AppShapes.border(size: AppShapes.chamferLg),
      useSafeArea: true,
      builder: (ctx) => _StatusSheet(
        currentStatus: currentStatus,
        onSelect: (newStatus) async {
          Navigator.pop(ctx);
          try {
            await _repo.managerUpdateClientStatus(widget.clientId, newStatus);
            _load();
          } catch (e) {
            if (mounted) _showError(e.toString());
          }
        },
      ),
    );
  }

  void _openAddHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddHistorySheet(
        clientId: widget.clientId,
        onAdded: () {
          Navigator.pop(context);
          _loadHistory();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandWhite,
      appBar: AppBar(
        backgroundColor: AppColors.brandBlack,
        title: Text(
          _loading ? 'КЛИЕНТ' : (_unified?['client']?['name']?.toString().toUpperCase() ?? 'КЛИЕНТ'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 14),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : _loadError != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Ошибка: $_loadError'), TextButton(onPressed: _load, child: const Text('ПОВТОРИТЬ')),
            ]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClientCard(),
                  ClientPersonalPricesTile(clientId: widget.clientId),
                  const SizedBox(height: 16),
                  _buildStatsAndOrders(),
                  const SizedBox(height: 16),
                  _buildHistorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildClientCard() {
    final c = _unified?['client'];
    if (c == null) return const SizedBox.shrink();

    return Container(
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: AppColors.brandBlack, width: 1),
          borderRadius: BorderRadius.only(topRight: Radius.circular(15)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: AppColors.brandBlack,
                  child: Text(
                    'КАТ. ${(c['category'] as String? ?? 'B').toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openStatusChange,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.brandRed.withValues(alpha: 0.08),
                    foregroundColor: AppColors.brandRed,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: const BeveledRectangleBorder(
                      borderRadius: BorderRadius.only(topRight: Radius.circular(8)),
                    ),
                  ),
                  child: const Text(
                    'ИЗМЕНИТЬ СТАТУС',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'ИНН', value: c['inn']?.toString() ?? '—'),
            _InfoRow(label: 'НАЗВАНИЕ', value: c['name']?.toString() ?? '—'),
            _InfoRow(label: 'СТАТУС', value: _kStatusLabels[c['status']?.toString()] ?? c['statusDisplay']?.toString() ?? c['status']?.toString() ?? '—'),
            _InfoRow(label: 'РЕГИОН', value: c['region']?.toString() ?? '—'),
            _InfoRow(label: 'EMAIL', value: c['email']?.toString() ?? '—'),
            _InfoRow(label: 'АДРЕС', value: c['address']?.toString() ?? '—'),
            _InfoRow(label: 'ДАТА РЕГИСТРАЦИИ', value: c['createdAt']?.toString() ?? '—'),
            _InfoRow(label: 'ИСТОЧНИК', value: c['registrationSource']?.toString() ?? '—'),
            _InfoRow(label: 'ГОРОД', value: c['city']?.toString() ?? '—'),
            _InfoRow(label: 'ПАРТНЁР', value: c['partnerStatus']?.toString() ?? '—'),
            if (c['distributorName'] != null)
              _InfoRow(label: 'ДИСТРИБЬЮТОР', value: c['distributorName'].toString()),
            if (c['contact'] != null && c['contact'].toString().isNotEmpty)
              _InfoRow(label: 'КОНТАКТ', value: c['contact'].toString()),
            if (c['phone'] != null && c['phone'].toString().isNotEmpty)
              _InfoRow(label: 'ТЕЛЕФОН', value: c['phone'].toString()),
            const SizedBox(height: 12),
            TextButton.icon(onPressed: _removeClient,
              icon: const Icon(Icons.delete_outline), label: const Text('УДАЛИТЬ КЛИЕНТА'),
              style: TextButton.styleFrom(foregroundColor: AppColors.brandRed)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsAndOrders() {
    final stats = _unified?['stats'] as Map<String, dynamic>? ?? const {};
    String money(Object? value) => '${(value as num? ?? 0).toStringAsFixed(2)} ₽';
    final lastOrder = DateTime.tryParse(stats['lastOrderAt']?.toString() ?? '');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('СТАТИСТИКА', style: TextStyle(fontWeight: FontWeight.w900)),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _InfoRow(label: 'Заказов', value: '${stats['orderCount'] ?? 0}'),
        _InfoRow(label: 'Оплачено', value: '${stats['paidOrderCount'] ?? 0}'),
        _InfoRow(label: 'Оборот заказов', value: money(stats['orderTurnover'])),
        _InfoRow(label: 'Покупки', value: money(stats['purchaseTurnover'])),
        _InfoRow(label: 'Средний чек', value: money(stats['averageOrder'])),
        _InfoRow(label: 'Последний заказ', value: lastOrder == null ? '—' : DateFormat('dd.MM.yyyy').format(lastOrder)),
      ]))),
      const SizedBox(height: 12),
      const Text('ЗАКАЗЫ', style: TextStyle(fontWeight: FontWeight.w900)),
      if (_orders.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Заказов нет')),
      for (final order in _orders) Card(child: ListTile(
        title: Text('${order.documentNumber} · ${order.totalAmount.toStringAsFixed(2)} ₽'),
        subtitle: Text('${DateFormat('dd.MM.yyyy').format(order.createdAt)} · ${order.status.name}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/manager/orders/${order.id}'),
      )),
      if (_moreOrders) TextButton(onPressed: _moreBusy ? null : () => _loadMore(orders: true),
        child: Text(_moreBusy ? 'ЗАГРУЗКА...' : 'ПОКАЗАТЬ ЕЩЁ ЗАКАЗЫ')),
      const SizedBox(height: 12),
      const Text('ИСТОРИЯ ПОКУПОК', style: TextStyle(fontWeight: FontWeight.w900)),
      if (_purchases.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Покупок нет')),
      for (final purchase in _purchases) Card(child: ListTile(
        title: Text('${purchase.documentNumber} · ${purchase.totalAmount.toStringAsFixed(2)} ₽'),
        subtitle: Text('${DateFormat('dd.MM.yyyy').format(purchase.date)} · ${purchase.status.name}'),
      )),
      if (_morePurchases) TextButton(onPressed: _moreBusy ? null : () => _loadMore(orders: false),
        child: Text(_moreBusy ? 'ЗАГРУЗКА...' : 'ПОКАЗАТЬ ЕЩЁ ПОКУПКИ')),
    ]);
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ИСТОРИЯ КОНТАКТОВ',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
                color: AppColors.brandBlack,
              ),
            ),
            TextButton.icon(
              onPressed: _openAddHistory,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.brandBlack,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: const BeveledRectangleBorder(
                  borderRadius: BorderRadius.only(topRight: Radius.circular(8)),
                ),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text(
                'ДОБАВИТЬ',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_historyLoading)
          const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
        else if (_history.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: const Center(
              child: Text(
                'НЕТ ЗАПИСЕЙ О КОНТАКТАХ',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: AppColors.textHint,
                  letterSpacing: 1,
                ),
              ),
            ),
          )
        else ...[
          ..._history.map((entry) => _HistoryEntry(entry: entry)),
          if (_historyHasMore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: _historyLoadingMore
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.brandRed,
                          strokeWidth: 2,
                        ),
                      )
                    : TextButton(
                        onPressed: _loadMoreHistory,
                        child: Text(
                          'ПОКАЗАТЬ ЕЩЁ (${_history.length} ИЗ $_historyTotal)',
                          style: const TextStyle(
                            color: AppColors.brandRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.brandBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  final ContactHistoryEntry entry;
  const _HistoryEntry({required this.entry});

  IconData get _icon {
    switch (entry.type) {
      case 'call': return Icons.phone_outlined;
      case 'visit': return Icons.directions_walk_outlined;
      case 'email': return Icons.email_outlined;
      default: return Icons.notes_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.only(topRight: Radius.circular(10)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              color: AppColors.brandBlack,
              child: Icon(_icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.typeDisplay.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brandBlack,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        fmt.format(entry.date),
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.result,
                    style: const TextStyle(fontSize: 12, color: AppColors.brandBlack, height: 1.4),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.authorName,
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Sheet ───────────────────────────────────────────────────────────────

class _StatusSheet extends StatelessWidget {
  final String currentStatus;
  final void Function(String) onSelect;

  const _StatusSheet({required this.currentStatus, required this.onSelect});

  // Ровно те статусы, что принимает бэкенд (ClientProfile.STATUS_CHOICES).
  // «Ожидание» и «архив» ему неизвестны — на них он отвечал 400.
  static const _statuses = [
    ('new', 'НОВЫЙ'),
    ('under_review', 'НА ПРОВЕРКЕ'),
    ('active', 'АКТИВНЫЙ'),
    ('blocked', 'ЗАБЛОКИРОВАН'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'ИЗМЕНИТЬ СТАТУС',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1,
                color: AppColors.brandBlack,
              ),
            ),
          ),
          const Divider(height: 1),
          ..._statuses.map((s) {
            final isSelected = s.$1 == currentStatus;
            return ListTile(
              onTap: () => onSelect(s.$1),
              leading: Container(
                width: 8,
                height: 8,
                color: isSelected ? AppColors.brandRed : Colors.transparent,
              ),
              title: Text(
                s.$2,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: isSelected ? AppColors.brandRed : AppColors.brandBlack,
                  letterSpacing: 0.5,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.brandRed)
                  : null,
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Add Contact History Sheet ──────────────────────────────────────────────────

class _AddHistorySheet extends StatefulWidget {
  final String clientId;
  final VoidCallback onAdded;

  const _AddHistorySheet({required this.clientId, required this.onAdded});

  @override
  State<_AddHistorySheet> createState() => _AddHistorySheetState();
}

class _AddHistorySheetState extends State<_AddHistorySheet> {
  final _repo = DataRepository();
  final _resultCtrl = TextEditingController();
  String _type = 'call';
  bool _submitting = false;

  static const _types = [
    ('call', 'ЗВОНОК'),
    ('visit', 'ВИЗИТ'),
    ('email', 'EMAIL'),
    ('other', 'ДРУГОЕ'),
  ];

  @override
  void dispose() {
    _resultCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_resultCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await _repo.managerAddContactHistory(widget.clientId, {
        'type': _type,
        'result': _resultCtrl.text.trim(),
      });
      widget.onAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.zero),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ДОБАВИТЬ КОНТАКТ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1, color: AppColors.brandBlack),
          ),
          const SizedBox(height: 16),
          const Text(
            'ТИП КОНТАКТА',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.textHint),
          ),
          const SizedBox(height: 8),
          Row(
            children: _types.map((t) {
              final sel = _type == t.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _type = t.$1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: sel ? AppColors.brandBlack : AppColors.brandWhite,
                    child: Text(
                      t.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: sel ? Colors.white : AppColors.brandBlack,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'РЕЗУЛЬТАТ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.textHint),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _resultCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Опишите результат контакта...',
              hintStyle: TextStyle(fontSize: 12, color: AppColors.textHint),
              contentPadding: EdgeInsets.all(12),
              filled: true,
              fillColor: AppColors.brandWhite,
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.zero,
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.brandBlack, width: 1.5),
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandBlack,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const BeveledRectangleBorder(
                  borderRadius: BorderRadius.only(topRight: Radius.circular(14)),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'СОХРАНИТЬ',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
