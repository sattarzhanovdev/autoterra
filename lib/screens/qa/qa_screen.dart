import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/auth_service.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/status_badge.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  late final PaginationController<ExpertTicket> _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<ExpertTicket>(
      fetchPage: (page) => DataRepository().tickets(page: page),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _controller.refresh();

  void _reload() {
    _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isExpert = authService.currentRole == UserRole.aiExpert;
    return Scaffold(
      appBar: AppBar(
        title: Text(isExpert ? 'ВСЕ ЗАЯВКИ' : 'МОИ ОБРАЩЕНИЯ'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildTickets(),
      floatingActionButton: isExpert ? null : FloatingActionButton.extended(
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
    return PaginatedListView<ExpertTicket>(
      controller: _controller,
      separator: const SizedBox(height: 12),
      emptyMessage: 'НЕТ АКТИВНЫХ ОБРАЩЕНИЙ',
      itemBuilder: (context, ticket, _) => _TicketCard(
        ticket: ticket,
        onTap: () => _showTicketDetail(ticket),
      ),
    );
  }

  void _showTicketDetail(ExpertTicket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TicketDetailSheet(ticket: ticket, onUpdated: _reload),
    );
  }

  void _showNewTicket() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
    final isExpert = authService.currentRole == UserRole.aiExpert;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        border: Border(
          top: const BorderSide(color: AppColors.brandRed, width: 3),
          left: BorderSide(color: isExpert && ticket.risk == 'high' ? AppColors.brandRed : AppColors.border, width: isExpert && ticket.risk == 'high' ? 4 : 1),
          right: BorderSide(color: AppColors.border, width: 1),
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
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
                  Row(
                    children: [
                      Text(ticket.category.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.brandRed, fontWeight: FontWeight.w900)),
                      if (isExpert && ticket.risk == 'high') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          color: AppColors.brandRed,
                          child: const Text('КРИТИЧЕСКИЙ РИСК', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ],
                  ),
                  StatusBadge.fromTicketStatus(ticket.status),
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

class _TicketDetailSheet extends StatefulWidget {
  final ExpertTicket ticket;
  final VoidCallback? onUpdated;
  const _TicketDetailSheet({required this.ticket, this.onUpdated});

  @override
  State<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends State<_TicketDetailSheet> {
  late ExpertTicket _ticket;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
  }

  @override
  Widget build(BuildContext context) {
    final isExpert = authService.currentRole == UserRole.aiExpert;
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            AppBar(
              title: Text(_ticket.category.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
              automaticallyImplyLeading: false,
              actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))],
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _bubble(_ticket.question, isUser: true, photo: _ticket.photo),
                if (isExpert && (_ticket.aiDraftAnswer != null || _ticket.similarCases.isNotEmpty))
                  _preAnalysisSection(_ticket),
                if (_ticket.aiAnswer != null) _aiBubble(_ticket.aiAnswer!),
                if (_ticket.expertAnswer != null) _expertBubble(_ticket.expertAnswer!),
                
                if (isExpert && _ticket.expertAnswer == null) ...[
                  const SizedBox(height: 24),
                  _ExpertAnswerForm(
                    ticketId: _ticket.id,
                    onSubmitted: (updated) {
                      setState(() => _ticket = updated);
                      widget.onUpdated?.call();
                    },
                  ),
                ] else if (_ticket.status == TicketStatus.aiAnswered && !isExpert) ...[
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
    ),
  );
}

  Widget _preAnalysisSection(ExpertTicket t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandRed.withValues(alpha: 0.05),
        border: Border.all(color: AppColors.brandRed.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, size: 16, color: AppColors.brandRed),
              SizedBox(width: 8),
              Text(
                'AI ПРЕДВАРИТЕЛЬНЫЙ АНАЛИЗ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.brandRed),
              ),
            ],
          ),
          if (t.aiDraftAnswer != null) ...[
            const SizedBox(height: 12),
            const Text('ЧЕРНОВИК ОТВЕТА (на основе БЗ):', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(t.aiDraftAnswer!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
          if (t.similarCases.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('ПОХОЖИЕ КЕЙСЫ:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: t.similarCases.map((id) => Chip(
                label: Text('CARD #$id', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                backgroundColor: AppColors.brandBlack,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
          ],
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

class _ExpertAnswerForm extends StatefulWidget {
  final String ticketId;
  final Function(ExpertTicket) onSubmitted;
  const _ExpertAnswerForm({required this.ticketId, required this.onSubmitted});

  @override
  State<_ExpertAnswerForm> createState() => _ExpertAnswerFormState();
}

class _ExpertAnswerFormState extends State<_ExpertAnswerForm> {
  final _ctrl = TextEditingController();
  final _causesCtrl = TextEditingController();
  bool _createKB = true;
  bool _loading = false;

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final updated = await DataRepository().expertAnswerTicket(
        widget.ticketId,
        answer: _ctrl.text.trim(),
        causes: _causesCtrl.text.trim(),
        createKnowledgeCard: _createKB,
      );
      widget.onSubmitted(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_createKB) ...[
          const Text('ПРИЧИНЫ ВОЗНИКНОВЕНИЯ (для БЗ)', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _causesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Почему возникла эта проблема...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Text('РЕШЕНИЕ / ОТВЕТ ЭКСПЕРТА', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.brandRed, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Техническая рекомендация...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Checkbox(
              value: _createKB,
              onChanged: (v) => setState(() => _createKB = v ?? false),
              activeColor: AppColors.brandRed,
            ),
            const Expanded(
              child: Text(
                'Создать черновик в Базе Знаний на основе этого ответа',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
            child: Text(_loading ? 'ОТПРАВКА...' : 'ОПУБЛИКОВАТЬ ОТВЕТ'),
          ),
        ),
      ],
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
  Uint8List? _webBytes;
  bool _saving = false;

  final _cats = ['ДЕФЕКТЫ', 'ТЕХНОЛОГИЯ', 'СОВМЕСТИМОСТЬ', 'ПОДБОР МАТЕРИАЛА', 'ДРУГОЕ'];

  Future<void> _pickImage() async {
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
              child: Text('ВЫБЕРИТЕ ИСТОЧНИК ФОТО', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
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

    if (source == null) return;

    final picker = ImagePicker();
    final img = await picker.pickImage(source: source);
    if (img != null) {
      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        setState(() {
          _photo = img;
          _webBytes = bytes;
        });
      } else {
        setState(() => _photo = img);
      }
    }
  }

  Future<void> _submit() async {
    if (_category == null || _questionCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final bytes = _webBytes ?? (_photo != null ? await _photo!.readAsBytes() : null);
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
    return SafeArea(
      child: Container(
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
                      : kIsWeb
                        ? Image.memory(_webBytes!, fit: BoxFit.cover)
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
    ),
  );
}
}
