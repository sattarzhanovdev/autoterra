import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';

class ManagerTasksScreen extends StatefulWidget {
  const ManagerTasksScreen({super.key});

  @override
  State<ManagerTasksScreen> createState() => _ManagerTasksScreenState();
}

class _ManagerTasksScreenState extends State<ManagerTasksScreen> {
  final _repo = DataRepository();

  /// У каждой вкладки своя лента со своей позицией подгрузки.
  late final PaginationController<ManagerTask> _pendingController;
  late final PaginationController<ManagerTask> _completedController;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _pendingController = PaginationController<ManagerTask>(
      fetchPage: (page) => _repo.managerTasks(page: page, status: 'pending'),
    );
    _completedController = PaginationController<ManagerTask>(
      fetchPage: (page) => _repo.managerTasks(page: page, status: 'completed'),
    );
    // Счётчики во вкладках берутся из метаданных пагинации, поэтому обе ленты
    // должны быть загружены, даже если открыта только одна.
    _pendingController.addListener(_onCountsChanged);
    _completedController.addListener(_onCountsChanged);
    _completedController.loadInitial();
  }

  @override
  void dispose() {
    _pendingController.removeListener(_onCountsChanged);
    _completedController.removeListener(_onCountsChanged);
    _pendingController.dispose();
    _completedController.dispose();
    super.dispose();
  }

  void _onCountsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await Future.wait([
      _pendingController.refresh(),
      _completedController.refresh(),
    ]);
  }

  Future<void> _markDone(ManagerTask task) async {
    try {
      await _repo.managerUpdateTask(task.id, {'status': 'completed'});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        title: const Text(
          'ЗАДАЧИ МЕНЕДЖЕРА',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: const Color(0xFF171717),
            child: Row(
              children: [
                _TabBtn(
                  label: 'АКТИВНЫЕ (${_pendingController.totalCount})',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                _TabBtn(
                  label: 'ВЫПОЛНЕННЫЕ (${_completedController.totalCount})',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _buildList(_pendingController, isPending: true),
          _buildList(_completedController, isPending: false),
        ],
      ),
    );
  }

  Widget _buildList(
    PaginationController<ManagerTask> controller, {
    required bool isPending,
  }) {
    return PaginatedListView<ManagerTask>(
      controller: controller,
      emptyMessage: isPending ? 'НЕТ АКТИВНЫХ ЗАДАЧ' : 'НЕТ ВЫПОЛНЕННЫХ ЗАДАЧ',
      itemBuilder: (_, task, __) => _TaskCard(
        task: task,
        onMarkDone: isPending ? () => _markDone(task) : null,
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? const Color(0xFFF01D2C) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFFF01D2C) : Colors.white60,
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

class _TaskCard extends StatefulWidget {
  final ManagerTask task;
  final VoidCallback? onMarkDone;

  const _TaskCard({required this.task, this.onMarkDone});

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _processing = false;

  bool get _isOverdue {
    final dl = widget.task.deadline;
    return dl != null &&
        widget.task.status == ManagerTaskStatus.pending &&
        dl.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    final task = widget.task;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(
          side: BorderSide(
            color: _isOverdue ? const Color(0xFFF01D2C) : const Color(0xFF171717),
            width: _isOverdue ? 2 : 1,
          ),
          borderRadius: const BorderRadius.only(topRight: Radius.circular(15)),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.clientName.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Color(0xFFF01D2C),
                    letterSpacing: 0.5,
                  ),
                ),
                if (task.deadline != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: _isOverdue
                        ? const Color(0xFFF01D2C)
                        : const Color(0xFFF5F5F5),
                    child: Text(
                      fmt.format(task.deadline!),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _isOverdue ? Colors.white : const Color(0xFF171717),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              task.text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF171717),
                height: 1.4,
              ),
            ),
            if (task.comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.comment,
                style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
              ),
            ],
            if (widget.onMarkDone != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _processing
                      ? null
                      : () async {
                          setState(() => _processing = true);
                          await Future.microtask(() => widget.onMarkDone?.call());
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF171717),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const BeveledRectangleBorder(
                      borderRadius: BorderRadius.only(topRight: Radius.circular(10)),
                    ),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'ВЫПОЛНЕНО',
                          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12),
                        ),
                ),
              ),
            ],
            if (task.status == ManagerTaskStatus.completed) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                child: const Text(
                  'ВЫПОЛНЕНО',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2E7D32),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
