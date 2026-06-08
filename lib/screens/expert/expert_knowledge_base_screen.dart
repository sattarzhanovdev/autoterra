import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';

class ExpertKnowledgeBaseScreen extends StatefulWidget {
  const ExpertKnowledgeBaseScreen({super.key});

  @override
  State<ExpertKnowledgeBaseScreen> createState() => _ExpertKnowledgeBaseScreenState();
}

class _ExpertKnowledgeBaseScreenState extends State<ExpertKnowledgeBaseScreen> {
  final DataRepository _repo = DataRepository();
  late Future<List<KnowledgeCard>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.knowledgeCards();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repo.knowledgeCards();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        title: const Text(
          'БАЗА ЗНАНИЙ AI',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<KnowledgeCard>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF01D2C)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final cards = snapshot.data!;
          if (cards.isEmpty) {
            return const Center(child: Text('БАЗА ЗНАНИЙ ПУСТА'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cards.length,
              itemBuilder: (context, index) => _KnowledgeCardTile(
                card: cards[index],
                onUpdate: _refresh,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement create card
        },
        backgroundColor: const Color(0xFFF01D2C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _KnowledgeCardTile extends StatelessWidget {
  final KnowledgeCard card;
  final VoidCallback onUpdate;

  const _KnowledgeCardTile({required this.card, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: Color(0xFF171717), width: 1),
          borderRadius: BorderRadius.zero,
        ),
      ),
      child: ExpansionTile(
        title: Text(
          card.problem.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: Color(0xFF171717),
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: card.isApproved ? const Color(0xFF171717) : const Color(0xFFF01D2C),
              child: Text(
                card.isApproved ? 'ОПУБЛИКОВАНО' : 'ЧЕРНОВИК',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'ЭКСПЕРТ: ${card.approvingExpert.toUpperCase()}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        expandedAlignment: Alignment.centerLeft,
        children: [
          _infoSection('ПРИЧИНЫ', card.causes),
          const SizedBox(height: 12),
          _infoSection('РЕШЕНИЕ', card.solution),
          if (card.skus.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoSection('МАТЕРИАЛЫ', card.skus.join(', ')),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              if (!card.isApproved)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await DataRepository().updateKnowledgeCard(card.id, isApproved: true);
                        onUpdate();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF171717),
                      shape: const BeveledRectangleBorder(),
                    ),
                    child: const Text('ОДОБРИТЬ'),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF171717),
                    side: const BorderSide(color: Color(0xFF171717)),
                    shape: const BeveledRectangleBorder(),
                  ),
                  child: const Text('ИЗМЕНИТЬ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFF01D2C),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
