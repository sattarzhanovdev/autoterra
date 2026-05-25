import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _tickets = _mockTickets;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вопрос-Ответ'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Мои обращения'),
            Tab(text: 'База знаний'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildTickets(), _buildKnowledge()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewTicket(),
        backgroundColor: AppColors.info,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Задать вопрос',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTickets() {
    if (_tickets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 220),
            Center(child: Text('Нет обращений')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _TicketCard(
          ticket: _tickets[i],
          onTap: () => _showTicketDetail(_tickets[i]),
        ),
      ),
    );
  }

  Widget _buildKnowledge() {
    final categories = [
      'Дефекты и причины',
      'Технология нанесения',
      'Совместимость материалов',
      'Условия сушки',
      'Подбор системы',
    ];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (context, i) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                color: AppColors.info,
                size: 20,
              ),
            ),
            title: Text(
              categories[i],
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textHint,
            ),
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
      builder: (_) => const _NewTicketSheet(),
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
      case TicketStatus.open:
        statusColor = AppColors.info;
        statusLabel = 'Открыто';
        break;
      case TicketStatus.aiAnswered:
        statusColor = AppColors.warning;
        statusLabel = 'Ответил AI';
        break;
      case TicketStatus.escalated:
        statusColor = AppColors.accent;
        statusLabel = 'У эксперта';
        break;
      case TicketStatus.expertAnswered:
        statusColor = AppColors.success;
        statusLabel = 'Ответ получен';
        break;
      case TicketStatus.closed:
        statusColor = AppColors.textHint;
        statusLabel = 'Закрыто';
        break;
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                ticket.question,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (ticket.aiAnswer != null) ...[
                const SizedBox(height: 8),
                Text(
                  'AI: ${ticket.aiAnswer}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${ticket.createdAt.day}.${ticket.createdAt.month}.${ticket.createdAt.year}',
                style: const TextStyle(color: AppColors.textHint, fontSize: 11),
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
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _bubble(ticket.question, isUser: true),
                if (ticket.aiAnswer != null) _aiBubble(ticket.aiAnswer!),
                if (ticket.expertAnswer != null)
                  _expertBubble(ticket.expertAnswer!),
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _aiBubble(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.smart_toy_outlined,
                size: 14,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              const Text(
                'AI-ответ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _expertBubble(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: AppColors.success,
              ),
              const SizedBox(width: 6),
              const Text(
                'Ответ технолога',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet();

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final _questionCtrl = TextEditingController();
  String? _category;
  final _cats = [
    'Дефекты',
    'Технология',
    'Совместимость',
    'Подбор материала',
    'Другое',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Задать вопрос эксперту',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Категория вопроса *',
                  ),
                  items: _cats
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _questionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Опишите вопрос или проблему *',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Прикрепить фото/видео',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Вопрос отправлен. AI анализирует...'),
                        backgroundColor: AppColors.info,
                      ),
                    );
                  },
                  child: const Text('Отправить вопрос'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final _mockTickets = [
  ExpertTicket(
    id: 't1',
    clientId: 'c1',
    question:
        'Лак пузырится после полной сушки в камере при 60°С. Грунт высох нормально, шпатлёвка была зашлифована P400.',
    category: 'Дефекты',
    aiAnswer:
        'Возможная причина: остаточная влага в шпатлёвке или несовместимость систем. Рекомендую: 1) Проверить полное высыхание шпатлёвки 2) Использовать изолирующий грунт 3) Снизить температуру в первые 10 мин сушки.',
    expertAnswer:
        'Подтверждаю - причина в ускоренной сушке. Шпатлёвка должна выходить при комнатной температуре минимум 2 ч перед камерой. Используйте наш грунт-изолятор (GRN-003) после шпатлёвки.',
    status: TicketStatus.expertAnswered,
    createdAt: DateTime(2025, 4, 20),
  ),
  ExpertTicket(
    id: 't2',
    clientId: 'c1',
    question:
        'Можно ли наносить наш 2K лак поверх однокомпонентного акрила другого бренда?',
    category: 'Совместимость',
    aiAnswer:
        'Наш 2K лак совместим с большинством однокомпонентных акрилов, но нужна дополнительная проверка. Передаю технологу.',
    status: TicketStatus.escalated,
    createdAt: DateTime(2025, 5, 10),
  ),
];
