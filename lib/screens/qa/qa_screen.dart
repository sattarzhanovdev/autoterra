import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Future<List<ExpertTicket>> _future;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _future = DataRepository().tickets();
  }

  Future<void> _refresh() async {
    final next = DataRepository().tickets();
    setState(() => _future = next);
    await next;
  }

  void _reload() {
    setState(() {
      _future = DataRepository().tickets();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ВОПРОС-ОТВЕТ'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'МОИ ОБРАЩЕНИЯ'),
            Tab(text: 'БАЗА ЗНАНИЙ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildTickets(), _buildKnowledge()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewTicket(),
        backgroundColor: AppColors.brandBlack,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'ЗАДАТЬ ВОПРОС',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildTickets() {
    return FutureBuilder<List<ExpertTicket>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.brandRed));
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final tickets = snapshot.data!;
        if (tickets.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 220),
                Center(child: Text('НЕТ АКТИВНЫХ ОБРАЩЕНИЙ')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _TicketCard(
              ticket: tickets[i],
              onTap: () => _showTicketDetail(tickets[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKnowledge() {
    final categories = [
      'ДЕФЕКТЫ И ПРИЧИНЫ',
      'ТЕХНОЛОГИЯ НАНЕСЕНИЯ',
      'СОВМЕСТИМОСТЬ МАТЕРИАЛОВ',
      'УСЛОВИЯ СУШКИ',
      'ПОДБОР СИСТЕМЫ',
    ];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (context, i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
          child: ListTile(
            leading: const Icon(Icons.menu_book_outlined, color: AppColors.brandRed),
            title: Text(categories[i], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.brandBlack),
            onTap: () {},
          ),
        ),
      ),
    );
  }

  void _showTicketDetail(ExpertTicket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TicketDetailSheet(ticket: ticket),
    );
  }

  void _showNewTicket() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewTicketSheet(onCreated: _reload),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final ExpertTicket ticket;
  final VoidCallback? onTap;
  const _TicketCard({required this.ticket, this.onTap});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    switch (ticket.status) {
      case TicketStatus.open: statusColor = AppColors.info; statusLabel = 'ОТКРЫТО'; break;
      case TicketStatus.aiAnswered: statusColor = AppColors.warning; statusLabel = 'ОТВЕТИЛ AI'; break;
      case TicketStatus.escalated: statusColor = AppColors.accent; statusLabel = 'У ЭКСПЕРТА'; break;
      case TicketStatus.expertAnswered: statusColor = AppColors.success; statusLabel = 'ОТВЕТ ПОЛУЧЕН'; break;
      case TicketStatus.closed: statusColor = AppColors.textHint; statusLabel = 'ЗАКРЫТО'; break;
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ticket.category.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w900)),
                  Text(statusLabel, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 12),
              Text(ticket.question, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${ticket.createdAt.day}.${ticket.createdAt.month}.${ticket.createdAt.year}', style: const TextStyle(color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.bold)),
                  if (ticket.photo != null) const Icon(Icons.image_outlined, size: 16, color: AppColors.textHint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketDetailSheet extends StatelessWidget {
  final ExpertTicket ticket;
  const _TicketDetailSheet({required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          AppBar(
            title: Text(ticket.category.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
            automaticallyImplyLeading: false,
            actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _bubble(ticket.question, isUser: true, photo: ticket.photo),
                if (ticket.aiAnswer != null) _aiBubble(ticket.aiAnswer!),
                if (ticket.expertAnswer != null) _expertBubble(ticket.expertAnswer!),
                if (ticket.status == TicketStatus.aiAnswered) ...[
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () {}, // Escalation logic
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandRed,
                      side: const BorderSide(color: AppColors.brandRed),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('ПОЗВАТЬ ЭКСПЕРТА / ТЕХНОЛОГА', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, {required bool isUser, String? photo}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: ShapeDecoration(
          color: isUser ? AppColors.brandBlack : AppColors.canvas,
          shape: BeveledRectangleBorder(
            side: isUser ? BorderSide.none : const BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photo != null) ...[
              const Icon(Icons.image_outlined, color: Colors.white, size: 20),
              const SizedBox(height: 8),
            ],
            Text(text, style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary, fontSize: 14, fontWeight: isUser ? FontWeight.w500 : FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _aiBubble(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: const ShapeDecoration(
        color: AppColors.canvas,
        shape: BeveledRectangleBorder(side: BorderSide(color: AppColors.brandRed, width: 1), borderRadius: BorderRadius.zero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.smart_toy_outlined, size: 16, color: AppColors.brandRed), SizedBox(width: 8), Text('AI-ОТВЕТ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.brandRed))]),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _expertBubble(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: const ShapeDecoration(
        color: AppColors.brandBlack,
        shape: BeveledRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.verified_user_outlined, size: 16, color: AppColors.success), SizedBox(width: 8), Text('ОТВЕТ ТЕХНОЛОГА', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.success))]),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _NewTicketSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _NewTicketSheet({required this.onCreated});

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final _questionCtrl = TextEditingController();
  String? _category;
  XFile? _photo;
  bool _saving = false;

  final _cats = ['ДЕФЕКТЫ', 'ТЕХНОЛОГИЯ', 'СОВМЕСТИМОСТЬ', 'ПОДБОР МАТЕРИАЛА', 'ДРУГОЕ'];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.camera);
    if (img != null) setState(() => _photo = img);
  }

  Future<void> _submit() async {
    if (_category == null || _questionCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final bytes = _photo != null ? await _photo!.readAsBytes() : null;
      await DataRepository().createExpertTicket({
        'category': _category,
        'question': _questionCtrl.text,
      }, fileBytes: bytes, fileName: _photo?.name);
      
      if (!mounted) return;
      widget.onCreated();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(color: Colors.white),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          AppBar(
            title: const Text('НОВЫЙ ВОПРОС', style: TextStyle(fontWeight: FontWeight.w900)),
            automaticallyImplyLeading: false,
            actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'КАТЕГОРИЯ ВОПРОСА *'),
                  items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _questionCtrl, decoration: const InputDecoration(labelText: 'ОПИШИТЕ ПРОБЛЕМУ *', alignLabelWithHint: true), maxLines: 5),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(color: AppColors.canvas, border: Border.all(color: AppColors.border)),
                    child: _photo == null 
                      ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: AppColors.brandRed), Text('ДОБАВИТЬ ФОТО ДЕФЕКТА', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))])
                      : Image.file(File(_photo!.path), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandRed),
                    child: Text(_saving ? 'ОТПРАВКА...' : 'ОТПРАВИТЬ ЭКСПЕРТУ'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

