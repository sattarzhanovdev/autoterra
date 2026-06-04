import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/attachment_picker.dart';
import '../../widgets/common/section_header.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Future<List<ExpertTicket>> _ticketsFuture;
  late Future<List<KnowledgeCard>> _cardsFuture;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _ticketsFuture = const DataRepository().tickets();
    _cardsFuture = const DataRepository().knowledgeCards();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _ticketsFuture = const DataRepository().tickets();
      _cardsFuture = const DataRepository().knowledgeCards();
    });
    await Future.wait([_ticketsFuture, _cardsFuture]);
  }

  void _reload() {
    setState(() {
      _ticketsFuture = const DataRepository().tickets();
      _cardsFuture = const DataRepository().knowledgeCards();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ВОПРОС-ОТВЕТ'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppColors.brandRed,
          tabs: const [
            Tab(text: 'МОИ ОБРАЩЕНИЯ'),
            Tab(text: 'БАЗА ЗНАНИЙ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildTicketsTab(), _buildKnowledgeTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewTicket(),
        backgroundColor: AppColors.brandBlack,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'ЗАДАТЬ ВОПРОС',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildTicketsTab() {
    return FutureBuilder<List<ExpertTicket>>(
      future: _ticketsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
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
                Center(child: Text('Нет активных обращений', style: TextStyle(fontWeight: FontWeight.w600))),
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

  Widget _buildKnowledgeTab() {
    return FutureBuilder<List<KnowledgeCard>>(
      future: _cardsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final cards = snapshot.data!;
        if (cards.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 220),
                Center(child: Text('База знаний пуста', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          );
        }

        final grouped = <String, List<KnowledgeCard>>{};
        for (final c in cards) {
          grouped.putIfAbsent(c.category, () => []).add(c);
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: entry.key.toUpperCase()),
                  const SizedBox(height: 10),
                  ...entry.value.map((card) => _KnowledgeCardWidget(card: card)),
                  const SizedBox(height: 20),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showTicketDetail(ExpertTicket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TicketDetailSheet(ticket: ticket, onUpdate: _reload),
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
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandBlack.withOpacity(0.05),
                      border: Border.all(color: AppColors.brandBlack, width: 1),
                    ),
                    child: Text(
                      ticket.category.toUpperCase(),
                      style: const TextStyle(fontSize: 9, color: AppColors.brandBlack, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                  const Spacer(),
                  StatusBadge(label: _statusLabel(ticket.status), color: _statusColor(ticket.status)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ticket.question,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd.MM.yyyy').format(ticket.createdAt),
                    style: const TextStyle(color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (ticket.risk == 'high')
                    const Row(
                      children: [
                        Icon(Icons.report_problem_sharp, size: 14, color: AppColors.brandRed),
                        SizedBox(width: 4),
                        Text('КРИТИЧНО', style: TextStyle(color: AppColors.brandRed, fontSize: 10, fontWeight: FontWeight.w900)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(TicketStatus s) {
    switch(s) {
      case TicketStatus.open: return 'ОТКРЫТО';
      case TicketStatus.aiAnswered: return 'AI ОТВЕТ';
      case TicketStatus.escalated: return 'У ЭКСПЕРТА';
      case TicketStatus.expertAnswered: return 'ОТВЕТ ПОЛУЧЕН';
      case TicketStatus.closed: return 'ЗАКРЫТО';
    }
  }

  Color _statusColor(TicketStatus s) {
    switch(s) {
      case TicketStatus.open: return AppColors.brandBlack;
      case TicketStatus.aiAnswered: return AppColors.brandBlack;
      case TicketStatus.escalated: return AppColors.warning;
      case TicketStatus.expertAnswered: return AppColors.success;
      case TicketStatus.closed: return AppColors.textHint;
    }
  }
}

class _KnowledgeCardWidget extends StatelessWidget {
  final KnowledgeCard card;
  const _KnowledgeCardWidget({required this.card});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(card.title.isEmpty ? card.problem : card.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.2)),
        subtitle: Text(card.problem, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                if (card.causes != null) ...[
                  const Text('ПРИЧИНЫ ВОЗНИКНОВЕНИЯ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.brandBlack, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(card.causes!, style: const TextStyle(fontSize: 13, height: 1.4)),
                  const SizedBox(height: 16),
                ],
                const Text('ТЕХНОЛОГИЧЕСКОЕ РЕШЕНИЕ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.brandBlack, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(card.solution, style: const TextStyle(fontSize: 13, height: 1.4)),
                if (card.restrictions != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: AppColors.brandRed, borderRadius: BorderRadius.zero),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_sharp, size: 18, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(child: Text(card.restrictions!, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
                ],
                if (card.skus.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: card.skus.map((sku) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.brandBlack, width: 1)),
                      child: Text(sku, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketDetailSheet extends StatefulWidget {
  final ExpertTicket ticket;
  final VoidCallback onUpdate;
  const _TicketDetailSheet({required this.ticket, required this.onUpdate});

  @override
  State<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends State<_TicketDetailSheet> {
  bool _escalating = false;

  Future<void> _escalate() async {
    setState(() => _escalating = true);
    try {
      await const ApiClient().expertAnswerTicket(widget.ticket.id, {'status': 'escalated'});
      if (!mounted) return;
      widget.onUpdate();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вопрос передан технологу'), backgroundColor: AppColors.warning));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _escalating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          Container(width: 48, height: 4, margin: const EdgeInsets.only(top: 12), color: AppColors.brandBlack),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(child: Text(t.category.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5))),
                IconButton(icon: const Icon(Icons.close_sharp), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 2, color: AppColors.brandBlack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _bubble(t.question, isUser: true),
                if (t.aiAnswer != null) _aiBubble(t.aiAnswer!),
                if (t.expertAnswer != null) _expertBubble(t.expertAnswer!),

                if (t.status == TicketStatus.aiAnswered && t.expertAnswer == null) ...[
                  const SizedBox(height: 32),
                  const Text('AI-ПОМОЩНИК ПРЕДЛОЖИЛ РЕШЕНИЕ. ЕСЛИ ОНО НЕ ПОМОГЛО, ПЕРЕДАЙТЕ ВОПРОС ТЕХНОЛОГУ.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _escalating ? null : _escalate,
                    icon: const Icon(Icons.person_search_sharp),
                    label: Text(_escalating ? 'ПЕРЕДАЕМ...' : 'ВЫЗВАТЬ ЭКСПЕРТА'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                  ),
                ],

                if (t.status == TicketStatus.escalated) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.warning, width: 2)),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_empty_sharp, color: AppColors.warning, size: 24),
                        SizedBox(width: 16),
                        Expanded(child: Text('ВОПРОС НА РАССМОТРЕНИИ У ТЕХНОЛОГА. ОЖИДАЙТЕ ОТВЕТА В ТЕЧЕНИЕ 1-4 ЧАСОВ.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                _section('ВЛОЖЕНИЯ'),
                AttachmentList(attachments: t.attachments),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, {required bool isUser}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isUser ? AppColors.brandBlack : AppColors.brandWhite,
          border: isUser ? null : Border.all(color: AppColors.brandBlack, width: 1.5),
        ),
        child: Text(text, style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary, fontSize: 14, height: 1.4)),
      ),
    );
  }

  Widget _aiBubble(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: AppColors.brandBlack, width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.smart_toy_sharp, size: 16, color: AppColors.brandBlack),
              SizedBox(width: 8),
              Text('AI-ОТВЕТ (БАЗА ЗНАНИЙ)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.brandBlack)),
            ],
          ),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _expertBubble(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(color: AppColors.brandBlack),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_sharp, size: 16, color: AppColors.brandRed),
              SizedBox(width: 8),
              Text('ОТВЕТ ТЕХНОЛОГА', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.5)),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.0)),
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
  List<PlatformFile> _attachments = [];
  bool _saving = false;
  final _cats = ['ДЕФЕКТЫ', 'ТЕХНОЛОГИЯ', 'СОВМЕСТИМОСТЬ', 'ПОДБОР МАТЕРИАЛА', 'ОБОРУДОВАНИЕ', 'ДРУГОЕ'];

  Future<void> _submit() async {
    if (_questionCtrl.text.trim().isEmpty || _category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ВЫБЕРИТЕ КАТЕГОРИЮ И ОПИШИТЕ ВОПРОС')));
      return;
    }
    setState(() => _saving = true);
    try {
      await const ApiClient().createTicket({'question': _questionCtrl.text.trim(), 'category': _category}, attachments: _attachments);
      if (!mounted) return;
      widget.onCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ВОПРОС ОТПРАВЛЕН'), backgroundColor: AppColors.brandBlack));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.brandRed));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.zero),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          Container(width: 48, height: 4, margin: const EdgeInsets.only(top: 12), color: AppColors.brandBlack),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text('НОВОЕ ОБРАЩЕНИЕ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close_sharp), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 2, color: AppColors.brandBlack),
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
                const SizedBox(height: 20),
                TextFormField(
                  controller: _questionCtrl,
                  decoration: const InputDecoration(labelText: 'ОПИСАНИЕ ПРОБЛЕМЫ *', alignLabelWithHint: true),
                  maxLines: 6,
                ),
                const SizedBox(height: 24),
                AttachmentPicker(
                  title: 'ФОТО/ВИДЕО ПОДТВЕРЖДЕНИЕ',
                  emptyText: 'ЗАГРУЗИТЕ МЕДИАФАЙЛЫ',
                  files: _attachments,
                  onChanged: (files) => setState(() => _attachments = files),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), backgroundColor: AppColors.brandRed),
                    child: Text(_saving ? 'ОТПРАВКА...' : 'ОТПРАВИТЬ ЭКСПЕРТУ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
