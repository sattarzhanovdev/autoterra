import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/data_repository.dart';
import '../../models/models.dart';
import '../../widgets/common/section_header.dart';

class AdminManagerTasksScreen extends StatefulWidget {
  const AdminManagerTasksScreen({super.key});

  @override
  State<AdminManagerTasksScreen> createState() => _AdminManagerTasksScreenState();
}

class _AdminManagerTasksScreenState extends State<AdminManagerTasksScreen> {
  final DataRepository _repo = DataRepository();

  List<ManagerTask> _tasks = [];
  List<Map<String, dynamic>> _managers = [];
  String? _filterManagerId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.adminManagerTasks(managerId: _filterManagerId),
        _repo.adminManagers(),
      ]);
      setState(() {
        _tasks = results[0] as List<ManagerTask>;
        _managers = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('AdminManagerTasks load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(ManagerTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить задачу?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(task.text, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.adminDeleteManagerTask(task.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    }
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (ctx) => _CreateTaskSheet(
        managers: _managers,
        repo: _repo,
        onCreated: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  int get _pending => _tasks.where((t) => t.status == ManagerTaskStatus.pending).length;
  int get _completed => _tasks.where((t) => t.status == ManagerTaskStatus.completed).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.brandBlack,
        title: const Text(
          'ЗАДАЧИ МЕНЕДЖЕРОВ',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.brandRed,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Filter
                  if (_managers.isNotEmpty) ...[
                    _buildFilter(),
                    const SizedBox(height: 20),
                  ],

                  // Stats row
                  Row(
                    children: [
                      _buildStatChip('АКТИВНЫХ', _pending, AppColors.brandRed),
                      const SizedBox(width: 8),
                      _buildStatChip('ВЫПОЛНЕНО', _completed, AppColors.brandBlack),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tasks
                  if (_tasks.isEmpty)
                    _buildEmpty()
                  else ...[
                    const SectionHeader(title: 'ВСЕ ЗАДАЧИ'),
                    const SizedBox(height: 12),
                    ..._tasks.map((t) => _TaskCard(
                          task: t,
                          onDelete: () => _delete(t),
                        )),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.brandRed,
        shape: const BeveledRectangleBorder(),
        elevation: 0,
        onPressed: _showCreateSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ФИЛЬТР', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.brandRed, letterSpacing: 1)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _filterManagerId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'МЕНЕДЖЕР',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Все менеджеры')),
              ..._managers.map((m) => DropdownMenuItem(
                    value: m['id'].toString(),
                    child: Text(m['name']?.toString() ?? m['username']?.toString() ?? ''),
                  )),
            ],
            onChanged: (v) {
              setState(() => _filterManagerId = v);
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: ShapeDecoration(
          color: color,
          shape: const BeveledRectangleBorder(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const Icon(Icons.task_outlined, size: 40, color: AppColors.border),
          const SizedBox(height: 12),
          const Text(
            'НЕТ ЗАДАЧ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textSecondary, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          const Text(
            'Нажмите + чтобы поставить задачу менеджеру',
            style: TextStyle(color: AppColors.textHint, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final ManagerTask task;
  final VoidCallback onDelete;

  const _TaskCard({required this.task, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final completed = task.status == ManagerTaskStatus.completed;
    final df = DateFormat('dd.MM.yyyy');
    final overdue = task.deadline != null && task.deadline!.isBefore(DateTime.now()) && !completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(
            color: completed ? AppColors.brandBlack : AppColors.brandRed,
            width: 3,
          ),
          top: const BorderSide(color: AppColors.border),
          right: const BorderSide(color: AppColors.border),
          bottom: const BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                completed ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: completed ? AppColors.brandBlack : AppColors.brandRed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.text,
                    style: TextStyle(
                      color: completed ? AppColors.textHint : AppColors.textPrimary,
                      decoration: completed ? TextDecoration.lineThrough : null,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _metaRow(Icons.person_outline, task.managerName),
                  const SizedBox(height: 2),
                  _metaRow(Icons.business_outlined, task.clientName),
                  if (task.deadline != null) ...[
                    const SizedBox(height: 2),
                    _metaRow(
                      Icons.calendar_today_outlined,
                      'Срок: ${df.format(task.deadline!)}',
                      color: overdue ? const Color(0xFFD97706) : null,
                    ),
                  ],
                  if (task.comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      task.comment,
                      style: const TextStyle(color: AppColors.textHint, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline, size: 18, color: AppColors.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 11, color: color ?? AppColors.textHint),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: color ?? AppColors.textSecondary, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CreateTaskSheet extends StatefulWidget {
  final List<Map<String, dynamic>> managers;
  final DataRepository repo;
  final VoidCallback onCreated;

  const _CreateTaskSheet({required this.managers, required this.repo, required this.onCreated});

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _textCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  String? _selectedManagerId;
  String? _selectedClientId;
  DateTime? _deadline;
  String? _errorMessage;

  List<Map<String, dynamic>> _clients = [];
  bool _loadingClients = false;
  bool _submitting = false;

  final DataRepository _repo = DataRepository();

  @override
  void dispose() {
    _textCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClients(String managerId) async {
    setState(() {
      _loadingClients = true;
      _clients = [];
      _selectedClientId = null;
    });
    try {
      final apiClients = await _repo.adminManagerClients(managerId);
      setState(() {
        _clients = apiClients;
        _loadingClients = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.brandRed),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Введите текст задачи');
      return;
    }
    if (_selectedManagerId == null) {
      setState(() => _errorMessage = 'Выберите менеджера');
      return;
    }

    setState(() { _submitting = true; _errorMessage = null; });
    try {
      await widget.repo.adminCreateManagerTask({
        'text': text,
        'managerId': _selectedManagerId,
        if (_selectedClientId != null) 'clientId': _selectedClientId,
        if (_deadline != null) 'deadline': DateFormat('yyyy-MM-dd').format(_deadline!),
        if (_commentCtrl.text.trim().isNotEmpty) 'comment': _commentCtrl.text.trim(),
      });
      widget.onCreated();
    } catch (e) {
      if (mounted) setState(() { _submitting = false; _errorMessage = 'Ошибка: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              decoration: const BoxDecoration(color: AppColors.brandBlack),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'НОВАЯ ЗАДАЧА',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // Form body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Manager
                  _label('МЕНЕДЖЕР'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedManagerId,
                    isExpanded: true,
                    decoration: _fieldDecoration('Выберите менеджера'),
                    items: widget.managers
                        .map((m) => DropdownMenuItem(
                              value: m['id'].toString(),
                              child: Text(m['name']?.toString() ?? m['username']?.toString() ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _selectedManagerId = v);
                      if (v != null) _loadClients(v);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Client
                  _label('КЛИЕНТ'),
                  const SizedBox(height: 6),
                  if (_loadingClients)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandRed),
                          ),
                          SizedBox(width: 10),
                          Text('Загрузка клиентов...', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedClientId,
                      isExpanded: true,
                      decoration: _fieldDecoration(
                        _selectedManagerId == null ? 'Сначала выберите менеджера' : 'Выберите клиента',
                      ),
                      items: _clients
                          .map((c) => DropdownMenuItem(
                                value: c['id'].toString(),
                                child: Text(c['name']?.toString() ?? ''),
                              ))
                          .toList(),
                      onChanged: _selectedManagerId == null ? null : (v) => setState(() => _selectedClientId = v),
                    ),
                  const SizedBox(height: 16),

                  // Task text
                  _label('ТЕКСТ ЗАДАЧИ'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _textCtrl,
                    maxLines: 3,
                    decoration: _fieldDecoration('Опишите задачу для менеджера...'),
                  ),
                  const SizedBox(height: 16),

                  // Comment
                  _label('КОММЕНТАРИЙ'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _commentCtrl,
                    decoration: _fieldDecoration('Необязательно'),
                  ),
                  const SizedBox(height: 16),

                  // Deadline
                  _label('СРОК ВЫПОЛНЕНИЯ'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        color: AppColors.canvas,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textHint),
                          const SizedBox(width: 10),
                          Text(
                            _deadline != null
                                ? DateFormat('dd MMMM yyyy', 'ru').format(_deadline!)
                                : 'Выбрать дату (необязательно)',
                            style: TextStyle(
                              color: _deadline != null ? AppColors.textPrimary : AppColors.textHint,
                              fontSize: 13,
                              fontWeight: _deadline != null ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                          if (_deadline != null) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() => _deadline = null),
                              child: const Icon(Icons.close, size: 16, color: AppColors.textHint),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Inline error
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF0F0),
                        border: Border(left: BorderSide(color: AppColors.brandRed, width: 3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.brandRed, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: const BeveledRectangleBorder(),
                      ),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'СОЗДАТЬ ЗАДАЧУ',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: AppColors.textSecondary,
          letterSpacing: 1,
        ),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
        filled: true,
        fillColor: AppColors.canvas,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.zero,
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.brandRed, width: 1.5),
          borderRadius: BorderRadius.zero,
        ),
        disabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.zero,
        ),
      );
}
