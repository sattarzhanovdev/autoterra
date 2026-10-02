import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/data_repository.dart';
import '../../models/models.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/brand_icon.dart';

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
  String? _tasksError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _tasksError = null;
    });

    // Раньше оба запроса шли через Future.wait: падал любой — терялись оба,
    // и список менеджеров оставался пустым. В форме создания это выглядело
    // как намертво неактивный селект. Грузим независимо.
    final tasks = _repo
        .adminManagerTasks(managerId: _filterManagerId)
        .then<Object?>((v) => v)
        .catchError((Object e) => e);
    final managers = _repo
        .adminManagers()
        .then<Object?>((v) => v)
        .catchError((Object e) => e);

    final tasksResult = await tasks;
    final managersResult = await managers;
    if (!mounted) return;

    setState(() {
      if (tasksResult is List<ManagerTask>) {
        _tasks = tasksResult;
      } else {
        // Пустой список без объяснения читается как «задач нет» — а это
        // не одно и то же с «не смогли загрузить».
        _tasksError = '$tasksResult';
      }
      if (managersResult is List<Map<String, dynamic>>) {
        _managers = managersResult;
      }
      _loading = false;
    });
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
      shape: AppShapes.border(size: AppShapes.chamferLg),
      useSafeArea: true,
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
                  if (_tasksError != null)
                    _buildError()
                  else if (_tasks.isEmpty)
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
            initialValue: _filterManagerId,
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

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.brandRed)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 36, color: AppColors.brandRed),
          const SizedBox(height: 12),
          const Text(
            'НЕ УДАЛОСЬ ЗАГРУЗИТЬ ЗАДАЧИ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.brandRed, letterSpacing: 1),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _tasksError!,
            style: const TextStyle(color: AppColors.textHint, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
            child: const Text('ПОВТОРИТЬ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ],
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
                  _metaRow(BrandIcons.person, task.managerName),
                  const SizedBox(height: 2),
                  _metaRow(Icons.business_outlined, task.clientName),
                  if (task.deadline != null) ...[
                    const SizedBox(height: 2),
                    _metaRow(
                      Icons.calendar_today_outlined,
                      'Срок: ${df.format(task.deadline!)}',
                      // Гайдбук, стр. 16: важное выделяем фирменным красным.
                      color: overdue ? AppColors.brandRed : null,
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
              borderRadius: BorderRadius.zero,
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

  late List<Map<String, dynamic>> _managers = widget.managers;
  bool _loadingManagers = false;
  String? _managersError;

  List<Map<String, dynamic>> _clients = [];
  bool _loadingClients = false;
  String? _clientsError;
  bool _submitting = false;

  final DataRepository _repo = DataRepository();

  @override
  void initState() {
    super.initState();
    // Список приходит снимком с экрана: если там загрузка ещё не прошла или
    // упала, снимок пустой — и селект менеджеров молча оказывается неактивным.
    // Догружаем сами, чтобы форма не зависела от чужой удачи.
    if (_managers.isEmpty) _loadManagers();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadManagers() async {
    setState(() {
      _loadingManagers = true;
      _managersError = null;
    });
    try {
      final managers = await _repo.adminManagers();
      if (!mounted) return;
      setState(() {
        _managers = managers;
        _loadingManagers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingManagers = false;
        _managersError = '$e';
      });
    }
  }

  Future<void> _loadClients(String managerId) async {
    setState(() {
      _loadingClients = true;
      _clientsError = null;
      _clients = [];
      _selectedClientId = null;
    });
    try {
      final apiClients = await _repo.adminManagerClients(managerId);
      if (!mounted) return;
      setState(() {
        _clients = apiClients;
        _loadingClients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingClients = false;
        _clientsError = '$e';
      });
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
      // Клавиатура — viewInsets, системная навигация Android — viewPadding.
      // Без второго нижняя кнопка уезжает под кнопки навигации.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.viewPaddingOf(context).bottom,
      ),
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
                  _managerField(),
                  const SizedBox(height: 16),

                  // Client
                  _label('КЛИЕНТ'),
                  const SizedBox(height: 6),
                  _clientField(),
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

  /// Заглушка на месте селекта: пустой Dropdown Flutter гасит сам, и без
  /// подписи поле выглядит просто сломанным.
  Widget _fieldPlaceholder(String text, {Color? color, VoidCallback? onRetry}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border.all(color: color ?? AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color ?? AppColors.textHint, fontSize: 13),
            ),
          ),
          if (onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: const Text(
                'ПОВТОРИТЬ',
                style: TextStyle(
                  color: AppColors.brandRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fieldLoading(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandRed),
          ),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _managerField() {
    if (_loadingManagers) return _fieldLoading('Загрузка менеджеров...');
    if (_managersError != null) {
      return _fieldPlaceholder(
        'Не удалось загрузить менеджеров',
        color: AppColors.brandRed,
        onRetry: _loadManagers,
      );
    }
    if (_managers.isEmpty) {
      return _fieldPlaceholder(
        'Менеджеров нет — заведите пользователя с ролью «менеджер»',
        onRetry: _loadManagers,
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedManagerId,
      isExpanded: true,
      decoration: _fieldDecoration('Выберите менеджера'),
      items: _managers
          .map((m) => DropdownMenuItem(
                value: m['id'].toString(),
                child: Text(m['name']?.toString() ?? m['username']?.toString() ?? ''),
              ))
          .toList(),
      onChanged: (v) {
        setState(() => _selectedManagerId = v);
        if (v != null) _loadClients(v);
      },
    );
  }

  Widget _clientField() {
    final managerId = _selectedManagerId;
    if (managerId == null) {
      return _fieldPlaceholder('Сначала выберите менеджера');
    }
    if (_loadingClients) return _fieldLoading('Загрузка клиентов...');
    if (_clientsError != null) {
      return _fieldPlaceholder(
        'Не удалось загрузить клиентов',
        color: AppColors.brandRed,
        onRetry: () => _loadClients(managerId),
      );
    }
    if (_clients.isEmpty) {
      // Клиент необязателен, поэтому это не ошибка — просто объясняем пустоту.
      return _fieldPlaceholder(
        'У менеджера нет клиентов — задачу можно поставить без клиента',
        onRetry: () => _loadClients(managerId),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedClientId,
      isExpanded: true,
      decoration: _fieldDecoration('Выберите клиента'),
      items: _clients
          .map((c) => DropdownMenuItem(
                value: c['id'].toString(),
                child: Text(c['name']?.toString() ?? ''),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedClientId = v),
    );
  }

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
