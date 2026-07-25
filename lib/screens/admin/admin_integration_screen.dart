import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/paginated.dart';
import '../../services/data_repository.dart';
import '../../services/auth_service.dart';
import '../../models/models.dart';

class AdminIntegrationScreen extends StatefulWidget {
  const AdminIntegrationScreen({super.key});

  @override
  State<AdminIntegrationScreen> createState() => _AdminIntegrationScreenState();
}

class _AdminIntegrationScreenState extends State<AdminIntegrationScreen> {
  final DataRepository _repo = DataRepository();
  List<dynamic> _tokens = [];
  List<dynamic> _logs = [];
  bool _loading = true;

  // Логи синхронизации растут постоянно, поэтому подгружаются постранично.
  // Токены — по одному на дистрибьютора, их берём целиком.
  bool _logsLoadingMore = false;
  bool _logsHasMore = false;
  int _logsPage = 1;
  int _logsTotal = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final tokens = await fetchAllPages(
        (page) => _repo.adminIntegrationTokens(page: page),
      );
      final logs = await _repo.adminIntegrationLogs();
      setState(() {
        _tokens = List<dynamic>.from(tokens);
        _logs = List<dynamic>.from(logs.items);
        _logsHasMore = logs.hasNext;
        _logsTotal = logs.count;
        _logsPage = 1;
        _loading = false;
      });
    } catch (e) {
      debugPrint('AdminIntegration Init Error: $e');
      // Mock data fallback
      setState(() {
        _tokens = [
          {'id': '1', 'name': 'AutoTerra МСК', 'token': 'abc123def456...', 'createdAt': '2026-06-06T10:00:00Z'},
          {'id': '2', 'name': 'AutoTerra КЗН', 'token': null, 'createdAt': null},
        ];
        _logs = [
          {'id': '1', 'distributorName': 'AutoTerra МСК', 'type': 'stock_update', 'status': 'success', 'createdAt': '2026-06-06T10:05:00Z'},
          {'id': '2', 'distributorName': 'AutoTerra МСК', 'type': 'stock_update', 'status': 'error', 'createdAt': '2026-06-06T09:00:00Z'},
          {'id': '3', 'distributorName': 'AutoTerra КЗН', 'type': 'orders_export', 'status': 'success', 'createdAt': '2026-06-05T18:00:00Z'},
        ];
        _loading = false;
      });
    }
  }

  Future<void> _generate(String distributorId) async {
    setState(() => _loading = true);
    try {
      await _repo.adminIntegrationGenerate(distributorId);
      await _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Новый ключ сгенерирован', style: TextStyle(color: Colors.white))));
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка генерации токена')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = authService.currentRole;
    final isGlobal = role == UserRole.admin;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ИНТЕГРАЦИИ 1С', style: TextStyle(fontWeight: FontWeight.w900)),
            Text(
              isGlobal ? 'ЦЕНТРАЛЬНЫЙ ОФИС' : 'РЕГИОНАЛЬНЫЙ МЕНЕДЖЕР',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white60, letterSpacing: 1),
            ),
          ],
        ),
        backgroundColor: AppColors.brandBlack,
        toolbarHeight: 80,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetch),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ТОКЕНЫ ДИСТРИБЬЮТОРОВ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tokens.length,
                    itemBuilder: (context, index) => _buildTokenCard(_tokens[index]),
                  ),
                  const SizedBox(height: 32),
                  const Text('ЖУРНАЛ СИНХРОНИЗАЦИИ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 16),
                  _buildLogsTable(),
                  _buildLogsFooter(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildTokenCard(dynamic data) {
    final name = data['name'] ?? 'Неизвестно';
    final token = data['token'];
    final id = data['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.brandBlack, width: 1), borderRadius: BorderRadius.zero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  color: AppColors.canvas,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          token != null ? '****************${token.toString().substring(token.toString().length > 4 ? token.toString().length - 4 : 0)}' : 'НЕТ АКТИВНОГО ТОКЕНА',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                        ),
                      ),
                      if (token != null)
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: token.toString()));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('СКОПИРОВАНО')));
                          },
                          child: const Icon(Icons.copy, color: AppColors.brandRed, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _generate(id.toString()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Strict corners
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                child: const Text('СГЕНЕРИРОВАТЬ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadMoreLogs() async {
    if (_logsLoadingMore || !_logsHasMore) return;
    setState(() => _logsLoadingMore = true);
    try {
      final logs = await _repo.adminIntegrationLogs(page: _logsPage + 1);
      setState(() {
        _logs = [..._logs, ...logs.items];
        _logsHasMore = logs.hasNext;
        _logsTotal = logs.count;
        _logsPage += 1;
        _logsLoadingMore = false;
      });
    } catch (_) {
      setState(() => _logsLoadingMore = false);
    }
  }

  Widget _buildLogsTable() {
    if (_logs.isEmpty) {
      return const Text('ЛОГОВ ПОКА НЕТ', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold));
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border, width: 1)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.canvas),
          dataRowMaxHeight: 56,
          dataRowMinHeight: 56,
          columns: const [
            DataColumn(label: Text('ДАТА', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10))),
            DataColumn(label: Text('ДИСТРИБЬЮТОР', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10))),
            DataColumn(label: Text('ТИП', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10))),
            DataColumn(label: Text('СТАТУС', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10))),
          ],
          rows: _logs.map((log) {
            final isSuccess = log['status'] == 'success';
            final dt = DateTime.tryParse(log['createdAt'] ?? '');
            return DataRow(
              cells: [
                DataCell(Text(dt != null ? DateFormat('dd.MM.yy HH:mm').format(dt) : '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                DataCell(Text(log['distributorName']?.toString().toUpperCase() ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                DataCell(Text(log['type']?.toString().toUpperCase() ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: isSuccess ? AppColors.brandBlack : AppColors.brandRed),
                    child: Text(
                      isSuccess ? 'SUCCESS' : 'ERROR',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLogsFooter() {
    if (!_logsHasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: _logsLoadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.brandRed,
                  strokeWidth: 2,
                ),
              )
            : TextButton(
                onPressed: _loadMoreLogs,
                child: Text(
                  'ПОКАЗАТЬ ЕЩЁ (${_logs.length} ИЗ $_logsTotal)',
                  style: const TextStyle(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
      ),
    );
  }
}