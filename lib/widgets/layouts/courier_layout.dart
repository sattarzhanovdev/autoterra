import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../common/paginated_list_view.dart';

import '../../screens/profile/profile_screen.dart';

class CourierLayout extends StatefulWidget {
  final Widget? child;
  const CourierLayout({super.key, this.child});

  @override
  State<CourierLayout> createState() => _CourierLayoutState();
}

class _CourierLayoutState extends State<CourierLayout> {
  int _currentIndex = 0;
  final DataRepository _repository = DataRepository();

  /// Разбивка по статусам делается запросами к серверу, а не фильтрацией
  /// загруженного списка: иначе вкладка показывала бы только те задачи,
  /// что попали в первую страницу общего списка.
  late final PaginationController<CourierTask> _assignedController;
  late final PaginationController<CourierTask> _inProgressController;

  @override
  void initState() {
    super.initState();
    _assignedController = PaginationController<CourierTask>(
      fetchPage: (page) =>
          _repository.courierMyTasks(page: page, status: 'assigned'),
    );
    _inProgressController = PaginationController<CourierTask>(
      fetchPage: (page) =>
          _repository.courierMyTasks(page: page, status: 'in_progress'),
    );
  }

  @override
  void dispose() {
    _assignedController.dispose();
    _inProgressController.dispose();
    super.dispose();
  }

  Future<void> _fetchTasks() async {
    await Future.wait([
      _assignedController.refresh(),
      _inProgressController.refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      CourierTasksScreen(
        assignedController: _assignedController,
        inProgressController: _inProgressController,
        onRefresh: _fetchTasks,
      ),
      _CourierRouteScreen(
        controller: _inProgressController,
        onRefresh: _fetchTasks,
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF171717), width: 2)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF171717),
          selectedItemColor: const Color(0xFFF01D2C),
          unselectedItemColor: Colors.white.withOpacity(0.5),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.square_list_fill, size: 24),
              label: 'ЗАДАЧИ',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.map_fill, size: 24),
              label: 'МАРШРУТ',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_fill, size: 24),
              label: 'ПРОФИЛЬ',
            ),
          ],
        ),
      ),
    );
  }
}

class CourierTasksScreen extends StatelessWidget {
  final PaginationController<CourierTask> assignedController;
  final PaginationController<CourierTask> inProgressController;
  final VoidCallback onRefresh;

  const CourierTasksScreen({
    super.key,
    required this.assignedController,
    required this.inProgressController,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF171717),
          title: const Text('ЛОГИСТИКА / КУРЬЕР'),
          actions: [
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFFF01D2C),
            indicatorWeight: 4,
            labelColor: Color(0xFFF01D2C),
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            tabs: [
              Tab(text: 'НОВЫЕ'),
              Tab(text: 'В РАБОТЕ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTaskList(assignedController),
            _buildTaskList(inProgressController),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(PaginationController<CourierTask> controller) {
    return PaginatedListView<CourierTask>(
      controller: controller,
      emptyMessage: 'НЕТ ЗАДАЧ В ЭТОМ РАЗДЕЛЕ',
      itemBuilder: (context, task, _) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: CourierTaskCard(task: task, onUpdated: onRefresh),
      ),
    );
  }
}

class CourierTaskCard extends StatefulWidget {
  final CourierTask task;
  final VoidCallback onUpdated;
  final DataRepository? repository;

  const CourierTaskCard({
    super.key,
    required this.task,
    required this.onUpdated,
    this.repository,
  });

  @override
  State<CourierTaskCard> createState() => _CourierTaskCardState();
}

class _CourierTaskCardState extends State<CourierTaskCard> {
  bool _processing = false;
  late final DataRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DataRepository();
  }

  Future<void> _handleAction() async {
    setState(() => _processing = true);
    try {
      if (widget.task.status == CourierTaskStatus.assigned) {
        await _repository.updateCourierTaskStatus(
          widget.task.id,
          status: 'in_progress',
        );
      } else if (widget.task.status == CourierTaskStatus.inProgress) {
        final source = await showModalBottomSheet<ImageSource>(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('ПОДТВЕРЖДЕНИЕ ДОСТАВКИ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppColors.brandBlack),
                  title: const Text('СДЕЛАТЬ ФОТО', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.brandBlack),
                  title: const Text('ВЫБРАТЬ ИЗ ГАЛЕРЕИ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );

        if (source == null) {
          setState(() => _processing = false);
          return;
        }

        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: source,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 50,
        );

        if (image != null) {
          final bytes = await image.readAsBytes();
          await _repository.updateCourierTaskStatus(
            widget.task.id,
            status: 'delivered',
            imageBytes: bytes,
            fileName: 'proof_${widget.task.id}.jpg',
          );
        } else {
          setState(() => _processing = false);
          return;
        }
      }
      widget.onUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isColorLab = widget.task.taskType == 'pickup';

    return Container(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: const BeveledRectangleBorder(
          side: BorderSide(color: Color(0xFF171717), width: 1),
          borderRadius: BorderRadius.only(topRight: Radius.circular(15)),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(4, 4),
          ),
        ],
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  color: isColorLab
                      ? const Color(0xFFF01D2C)
                      : const Color(0xFF171717),
                  child: Text(
                    widget.task.typeDisplay.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Text(
                  widget.task.timeSlot,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Color(0xFF171717),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.task.clientName.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: Color(0xFFF01D2C),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  CupertinoIcons.location_solid,
                  size: 20,
                  color: Color(0xFFF01D2C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.task.address.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF171717),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.task.comment?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                'КОММЕНТАРИЙ: ${widget.task.comment}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _processing ? null : _handleAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.task.status == CourierTaskStatus.assigned
                      ? const Color(0xFFF01D2C)
                      : const Color(0xFF171717),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const BeveledRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                    ),
                  ),
                ),
                child: _processing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.task.status == CourierTaskStatus.assigned
                            ? 'ПРИНЯТЬ В РАБОТУ'
                            : 'ЗАВЕРШИТЬ (ФОТО)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourierRouteScreen extends StatelessWidget {
  final PaginationController<CourierTask> controller;
  final VoidCallback onRefresh;

  const _CourierRouteScreen({
    required this.controller,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        title: const Text('ЛОГИСТИКА / КУРЬЕР'),
        actions: [
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: PaginatedListView<CourierTask>(
        controller: controller,
        emptyMessage: 'НЕТ АКТИВНЫХ ЗАДАЧ В ПУТИ',
        itemBuilder: (context, task, _) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: Color(0xFFF01D2C), width: 5),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              task.address.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            subtitle: Text(
              '${task.timeSlot} · ${task.clientName}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              // Could navigate to detail or show on map
            },
          ),
        ),
      ),
    );
  }
}
