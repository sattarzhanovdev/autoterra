import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/data_repository.dart';
import '../../services/api_client.dart';

class DistributorIntegrationScreen extends StatefulWidget {
  const DistributorIntegrationScreen({super.key});

  @override
  State<DistributorIntegrationScreen> createState() => _DistributorIntegrationScreenState();
}

class _DistributorIntegrationScreenState extends State<DistributorIntegrationScreen> {
  final DataRepository _repo = DataRepository();
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _showToken = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _repo.distributorIntegration();
      setState(() {
        _data = res;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      await _repo.generateIntegrationToken();
      await _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Новый ключ сгенерирован', style: TextStyle(color: Colors.white))));
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.brandRed)));
    }

    final token = _data?['token'] as String?;
    final logs = (_data?['logs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('ИНТЕГРАЦИЯ 1С'),
        backgroundColor: AppColors.brandBlack,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTokenBlock(token),
          const SizedBox(height: 24),
          _buildInstructionsBlock(),
          const SizedBox(height: 24),
          const Text('ЖУРНАЛ СИНХРОНИЗАЦИИ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('ЛОГОВ ПОКА НЕТ', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))))
          else
            ...logs.map((log) => _buildLogCard(log)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTokenBlock(String? token) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('КЛЮЧ ДОСТУПА (API KEY)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          if (token != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.canvas,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _showToken ? token : '*' * 32,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility, color: AppColors.brandBlack),
                    onPressed: () => setState(() => _showToken = !_showToken),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppColors.brandRed),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: token));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('СКОПИРОВАНО')));
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text('Ключ еще не сгенерирован', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loading ? null : _generate,
              child: const Text('СГЕНЕРИРОВАТЬ НОВЫЙ КЛЮЧ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsBlock() {
    final apiUrl = '${ApiClient.baseUrl}/integration/erp/stock-update/';
    final jsonExample = '''[
  {
    "sku": "LAK-77-01",
    "quantity": 100,
    "price": 1500.00
  }
]''';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.brandBlack, border: Border.all(color: AppColors.brandBlack)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ИНСТРУКЦИЯ ДЛЯ 1С-ПРОГРАММИСТА', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          const Text('URL ДЛЯ POST-ЗАПРОСА:', style: TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          SelectableText(apiUrl, style: const TextStyle(color: AppColors.brandRed, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('ЗАГОЛОВОК (HEADER):', style: TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const SelectableText('X-Integration-Token: ВАШ_КЛЮЧ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('ФОРМАТ ТЕЛА (JSON):', style: TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black,
            child: SelectableText(jsonExample, style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final isSuccess = log['status'] == 'success';
    final dt = DateTime.tryParse(log['createdAt'] ?? '');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: isSuccess ? AppColors.border : AppColors.brandRed)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isSuccess ? Icons.check_box : Icons.error, color: isSuccess ? AppColors.brandBlack : AppColors.brandRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(log['type'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    if (dt != null) Text(DateFormat('dd.MM.yy HH:mm').format(dt), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(log['details'].toString(), style: TextStyle(fontSize: 10, color: isSuccess ? AppColors.textPrimary : AppColors.brandRed)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
