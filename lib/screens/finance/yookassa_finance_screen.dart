import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/share_origin.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/file_download_service.dart';

const financeStatuses = {
  'matched': 'Сверено',
  'empty': 'Нет операций',
  'discrepancies': 'Есть расхождения',
  'not_in_registry': 'Нет в реестре',
  'payment_not_found': 'Платеж не найден',
  'amount_mismatch': 'Сумма не совпадает',
  'order_mismatch': 'Заказ не совпадает',
  'currency_mismatch': 'Валюта не совпадает',
  'payment_not_succeeded': 'Оплата не подтверждена',
  'refund_exceeds_payment': 'Возвраты превышают оплату',
  'fee_unknown': 'Комиссия неизвестна',
  'net_mismatch': 'Сумма к зачислению не совпадает',
};

class YooKassaFinanceScreen extends StatefulWidget {
  final ApiClient? api;
  const YooKassaFinanceScreen({super.key, this.api});
  @override
  State<YooKassaFinanceScreen> createState() => _YooKassaFinanceScreenState();
}

class _YooKassaFinanceScreenState extends State<YooKassaFinanceScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late DateTimeRange _period;
  Map<String, dynamic>? _data;
  String? _distributor;
  String? _error;
  bool _loading = false;
  bool _busy = false;
  int _page = 1;
  int _request = 0;
  bool get _allowed =>
      {UserRole.admin, UserRole.distributor}.contains(authService.currentRole);
  Map<String, String> get _filters => {
    'date_from': DateFormat('yyyy-MM-dd').format(_period.start),
    'date_to': DateFormat('yyyy-MM-dd').format(_period.end),
    'distributor_id': ?_distributor,
  };

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _period = DateTimeRange(
      start: DateTime(today.year, today.month),
      end: today,
    );
    if (_allowed) _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.financeReport({..._filters, 'page': '$_page'});
      if (mounted && request == _request) setState(() => _data = data);
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e.toString());
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        withData: true,
      );
      if (picked == null || !mounted) return;
      final file = picked.files.single;
      if (file.bytes == null) throw ApiException('Не удалось прочитать файл');
      final result = await _api.importFinanceRegistry(
        file.bytes!,
        file.name,
        distributorId: _distributor,
      );
      _message(
        'Добавлено: ${result['imported']}; повторов: ${result['duplicates']}; вне доступа: ${result['skipped']}',
      );
      _page = 1;
      await _load();
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final file = await _api.exportFinance(_filters);
      final saved = await const FileDownloadService().save(
        fileName: file.fileName,
        bytes: file.bytes,
        format: 'xlsx',
      );
      if (!mounted) return;
      _message('Сохранено: ${saved.displayPath}');
      if (saved.canShare) {
        await Share.shareXFiles([
          XFile(saved.path!),
        ], sharePositionOrigin: shareOriginFrom(context));
      }
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _money(dynamic value) => value == null
      ? 'Не сверено'
      : '${NumberFormat('#,##0.00', 'ru_RU').format(num.parse('$value'))} ₽';
  String _status(dynamic value) => financeStatuses[value] ?? '$value';

  @override
  Widget build(BuildContext context) {
    if (!_allowed) {
      return const Scaffold(
        body: Center(child: Text('Нет доступа к финансовому учету')),
      );
    }
    final summary = _data?['summary'] as Map<String, dynamic>?;
    final operations = (_data?['operations'] as List?) ?? [];
    final discrepancies = (_data?['discrepancies'] as List?) ?? [];
    final count = _data?['count'] as int? ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('УЧЕТ ЮKASSA'),
        actions: [
          IconButton(
            onPressed: _busy || _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Внутренний учет · RUB. Продажи по дате оплаты, возвраты по дате возврата. Комиссия включает НДС из реестра.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(
              '${DateFormat('dd.MM.yyyy').format(_period.start)} — ${DateFormat('dd.MM.yyyy').format(_period.end)}',
            ),
            onPressed: _busy || _loading
                ? null
                : () async {
                    final selected = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _period,
                    );
                    if (selected != null && mounted) {
                      setState(() {
                        _period = selected;
                        _page = 1;
                      });
                      _load();
                    }
                  },
          ),
          if (authService.currentRole == UserRole.admin && _data != null)
            DropdownButtonFormField<String>(
              initialValue: _distributor,
              decoration: const InputDecoration(labelText: 'Дистрибьютор'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Все дистрибьюторы'),
                ),
                for (final dist in _data!['distributors'] as List)
                  DropdownMenuItem(
                    value: '${dist['id']}',
                    child: Text('${dist['name']}'),
                  ),
              ],
              onChanged: _busy || _loading
                  ? null
                  : (value) {
                      setState(() {
                        _distributor = value;
                        _page = 1;
                      });
                      _load();
                    },
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy || _loading ? null : _import,
                icon: const Icon(Icons.upload_file),
                label: const Text('Импорт CSV / XLSX'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _busy || _loading || _error != null || summary == null
                    ? null
                    : _export,
                icon: const Icon(Icons.download),
                label: const Text('Excel для бухгалтерии'),
              ),
            ],
          ),
          if (_busy || _loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Повторить')),
                ],
              ),
            ),
          if (!_loading && _error == null && summary != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Статус сверки'),
                subtitle: Text(_status(summary['status'])),
                trailing: Text('${summary['discrepancies']} расхождений'),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Оплаченных заказов'),
                trailing: Text('${summary['paidOrders']}'),
              ),
            ),
            for (final item in const {
              'sales': 'Продажи через ЮKassa',
              'commission': 'Комиссия ЮKassa с НДС',
              'refunds': 'Сверенные возвраты',
              'net': 'Итого к зачислению',
              'confirmedNet': 'Подтвержденная часть к зачислению',
            }.entries)
              Card(
                child: ListTile(
                  title: Text(item.value),
                  trailing: Text(_money(summary[item.key])),
                ),
              ),
            if (discrepancies.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('РАСХОЖДЕНИЯ (первые 100; полный список в Excel)'),
              for (final row in discrepancies)
                ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: Text(
                    '${row['providerPaymentId']} · ${_status(row['status'])}',
                  ),
                  subtitle: Text(
                    'Заказ: ${row['orderId'] ?? '—'} · в реестре: ${_money(row['registryAmount'])} · в учете: ${_money(row['amount'])}',
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text('ОПЕРАЦИИ · $count'),
            if (operations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('За этот период операций нет'),
              ),
            if (operations.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    for (final label in [
                      'Дата',
                      'Заказ',
                      'Клиент',
                      'Дистрибьютор',
                      'ID ЮKassa',
                      'Оплата',
                      'Комиссия',
                      'Возврат',
                      'К зачислению',
                      'Сверка',
                    ])
                      DataColumn(label: Text(label)),
                  ],
                  rows: [
                    for (final row in operations)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              DateFormat(
                                'dd.MM.yyyy HH:mm',
                              ).format(DateTime.parse(row['date']).toLocal()),
                            ),
                          ),
                          DataCell(Text('${row['orderId'] ?? '—'}')),
                          DataCell(Text('${row['client'] ?? '—'}')),
                          DataCell(Text('${row['distributor'] ?? '—'}')),
                          DataCell(
                            SelectableText('${row['providerPaymentId']}'),
                          ),
                          for (final key in ['amount', 'fee', 'refund', 'net'])
                            DataCell(Text(_money(row[key]))),
                          DataCell(Text(_status(row['status']))),
                        ],
                      ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _page > 1 && !_busy
                      ? () {
                          _page--;
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Страница $_page'),
                IconButton(
                  onPressed: _page * 100 < count && !_busy
                      ? () {
                          _page++;
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
