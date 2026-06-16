import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/data_repository.dart';
import '../../services/api_client.dart';
import '../../widgets/common/section_header.dart';

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

  final TextEditingController _testController = TextEditingController();
  Map<String, dynamic>? _testResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _testController.dispose();
    super.dispose();
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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      await _repo.generateIntegrationToken();
      await _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Новый ключ сгенерирован', style: TextStyle(color: Colors.white))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _runTest() async {
    if (_testController.text.isEmpty) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final payload = jsonDecode(_testController.text);
      if (payload is! List) throw 'Ожидается JSON массив [{}, ...]';
      
      final integrationToken = _data?['token'] as String?;
      if (integrationToken == null) throw 'Сначала сгенерируйте ключ доступа';
      final res = await _repo.test1CIntegration(payload, integrationToken);
      setState(() => _testResult = res);
      await _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка формата: $e')));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.brandRed)),
      );
    }

    final token = _data?['token'] as String?;
    final logs = (_data?['logs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('ИНТЕГРАЦИЯ 1С'),
        backgroundColor: AppColors.brandBlack,
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTokenBlock(token),
            const SizedBox(height: 24),
            _buildZeroCodeBlock(),
            const SizedBox(height: 24),
            _buildSandboxBlock(),
            const SizedBox(height: 24),
            _buildInstructionsBlock(),
            const SizedBox(height: 32),
            const SectionHeader(title: 'ЖУРНАЛ СИНХРОНИЗАЦИИ'),
            const SizedBox(height: 12),
            if (logs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'ЛОГОВ ПОКА НЕТ',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              ...logs.map((log) => _buildLogCard(log)),
            const SizedBox(height: 80),
          ],
        ),
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

  Widget _buildZeroCodeBlock() {
    final apiUrl = '${ApiClient.baseUrl}/integration/1c/exchange/';
    final token = _data?['token'] ?? 'ВАШ_КЛЮЧ';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.brandBlack, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on, color: AppColors.brandRed, size: 18),
              const SizedBox(width: 8),
              const Text('БЕЗ ПРОГРАММИРОВАНИЯ (1С)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Используйте стандартную функцию 1С «Обмен с сайтом». Просто введите эти данные в настройки 1С:',
            style: TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 16),
          _field('Адрес сайта', '$apiUrl?token=$token'),
          _field('Имя пользователя', 'AutoTerra'),
          _field('Пароль', 'Любой символ'),
          const SizedBox(height: 12),
          const Text(
            '1С сама выгрузит товары, остатки и цены по расписанию.',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('СКОПИРОВАНО')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSandboxBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.brandRed, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, color: AppColors.brandRed, size: 18),
              const SizedBox(width: 8),
              const Text('ПЕСОЧНИЦА (ТЕСТ JSON)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Вставьте JSON для проверки сопоставления товаров (dry run). Данные в базе не изменятся.',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _testController,
            maxLines: 5,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            decoration: const InputDecoration(
              hintText: '[{"sku": "...", "quantity": 10}]',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(8),
            ),
          ),
          const SizedBox(height: 12),
          if (_testResult != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              color: AppColors.canvas,
              child: Text(
                'Результат: ${_testResult!['status']}\nОбновлено: ${_testResult!['updated']}/${_testResult!['total_items']}\nОшибки: ${(_testResult!['errors'] as List).length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _testing ? null : _runTest,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
              child: _testing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('ПРОВЕРИТЬ СОПОСТАВЛЕНИЕ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsBlock() {
    final apiUrl = ApiClient.baseUrl;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const ShapeDecoration(
        color: AppColors.brandBlack,
        shape: BeveledRectangleBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ДОКУМЕНТАЦИЯ ДЛЯ ПРОГРАММИСТА 1С', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          _instructionRow('Header', 'X-Integration-Token: ВАШ_КЛЮЧ'),
          const Divider(color: Colors.white24, height: 24),
          _endpointInfo('1. Обновление остатков (POST)', '$apiUrl/integration/erp/stock-update/'),
          _endpointInfo('2. Синхронизация каталога (POST)', '$apiUrl/integration/erp/catalog-sync/'),
          _endpointInfo('3. Синхронизация клиентов (POST)', '$apiUrl/integration/erp/client-sync/'),
          _endpointInfo('4. Получение заказов (GET)', '$apiUrl/integration/erp/orders-export/'),
          const SizedBox(height: 12),
          const Text('СОВЕТ: Используйте ?dry_run=true для тестов.', style: TextStyle(color: AppColors.brandRed, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _instructionRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SelectableText(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _endpointInfo(String title, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          SelectableText(url, style: const TextStyle(color: AppColors.brandRed, fontSize: 10, fontFamily: 'monospace')),
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
