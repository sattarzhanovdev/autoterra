import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../models/paginated.dart';
import '../../services/data_repository.dart';

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
      ]);
      setState(() {
        _unified = results[0] as Map<String, dynamic>;
        final historyPage = results[1] as Paginated<ContactHistoryEntry>;
        _history = historyPage.items;
        _historyHasMore = historyPage.hasNext;
        _historyTotal = historyPage.count;
        _historyPage = 1;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _showError(e.toString());
    }
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF01D2C)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClientCard(),
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
          side: BorderSide(color: Color(0xFF171717), width: 1),
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
                  color: const Color(0xFF171717),
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
                    backgroundColor: const Color(0xFFF01D2C).withOpacity(0.08),
                    foregroundColor: const Color(0xFFF01D2C),
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
            _InfoRow(label: 'ГОРОД', value: c['city']?.toString() ?? '—'),
            _InfoRow(label: 'ПАРТНЁР', value: c['partnerStatus']?.toString() ?? '—'),
            if (c['distributorName'] != null)
              _InfoRow(label: 'ДИСТРИБЬЮТОР', value: c['distributorName'].toString()),
            if (c['contact'] != null && c['contact'].toString().isNotEmpty)
              _InfoRow(label: 'КОНТАКТ', value: c['contact'].toString()),
            if (c['phone'] != null && c['phone'].toString().isNotEmpty)
              _InfoRow(label: 'ТЕЛЕФОН', value: c['phone'].toString()),
          ],
        ),
      ),
    );
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
                color: Color(0xFF171717),
              ),
            ),
            TextButton.icon(
              onPressed: _openAddHistory,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF171717),
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
          const Center(child: CircularProgressIndicator(color: Color(0xFFF01D2C)))
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
                  color: Colors.grey,
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
                          color: Color(0xFFF01D2C),
                          strokeWidth: 2,
                        ),
                      )
                    : TextButton(
                        onPressed: _loadMoreHistory,
                        child: Text(
                          'ПОКАЗАТЬ ЕЩЁ (${_history.length} ИЗ $_historyTotal)',
                          style: const TextStyle(
                            color: Color(0xFFF01D2C),
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
                color: Colors.grey,
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
                color: Color(0xFF171717),
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
          side: BorderSide(color: Color(0xFFE0E0E0)),
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
              color: const Color(0xFF171717),
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
                          color: Color(0xFF171717),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        fmt.format(entry.date),
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.result,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF171717), height: 1.4),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.authorName,
                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
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
                color: Color(0xFF171717),
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
                color: isSelected ? const Color(0xFFF01D2C) : Colors.transparent,
              ),
              title: Text(
                s.$2,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: isSelected ? const Color(0xFFF01D2C) : const Color(0xFF171717),
                  letterSpacing: 0.5,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Color(0xFFF01D2C))
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
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ДОБАВИТЬ КОНТАКТ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1, color: Color(0xFF171717)),
          ),
          const SizedBox(height: 16),
          const Text(
            'ТИП КОНТАКТА',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey),
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
                    color: sel ? const Color(0xFF171717) : const Color(0xFFF5F5F5),
                    child: Text(
                      t.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: sel ? Colors.white : const Color(0xFF171717),
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
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _resultCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Опишите результат контакта...',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
              contentPadding: EdgeInsets.all(12),
              filled: true,
              fillColor: Color(0xFFF5F5F5),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.zero,
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF171717), width: 1.5),
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
                backgroundColor: const Color(0xFF171717),
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
