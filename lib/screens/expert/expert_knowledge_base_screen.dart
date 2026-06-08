import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/auth_service.dart';

class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
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
    final isExpert = authService.currentRole == UserRole.aiExpert;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        title: const Text(
          'БАЗА ЗНАНИЙ',
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
            return const Center(child: CircularProgressIndicator(color: AppColors.brandRed));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          
          var cards = snapshot.data!;
          if (!isExpert) {
            cards = cards.where((c) => c.isApproved).toList();
          } else {
            cards.sort((a, b) {
              if (a.isApproved == b.isApproved) return 0;
              return a.isApproved ? 1 : -1;
            });
          }

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
                isExpert: isExpert,
              ),
            ),
          );
        },
      ),
      floatingActionButton: isExpert 
        ? FloatingActionButton(
            onPressed: () => _showEditSheet(),
            backgroundColor: AppColors.brandRed,
            child: const Icon(Icons.add, color: Colors.white),
          )
        : null,
    );
  }

  void _showEditSheet([KnowledgeCard? card]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditKnowledgeCardSheet(
        card: card,
        onSaved: _refresh,
      ),
    );
  }
}

class _KnowledgeCardTile extends StatelessWidget {
  final KnowledgeCard card;
  final VoidCallback onUpdate;
  final bool isExpert;

  const _KnowledgeCardTile({required this.card, required this.onUpdate, required this.isExpert});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: AppColors.border, width: 1),
          borderRadius: BorderRadius.zero,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.brandRed, width: 4)),
        ),
        child: ExpansionTile(
          shape: const Border(), // Remove default line
          title: Text(
            card.problem.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: AppColors.brandBlack,
              letterSpacing: 0.5,
            ),
          ),
          subtitle: isExpert ? Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: card.isApproved ? AppColors.brandBlack : AppColors.brandRed,
                child: Text(
                  card.isApproved ? 'ОПУБЛИКОВАНО' : 'ЧЕРНОВИК',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ЭКСПЕРТ: ${card.approvingExpert.toUpperCase()}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
            ],
          ) : null,
          childrenPadding: const EdgeInsets.all(16),
          expandedAlignment: Alignment.centerLeft,
          children: [
            if (card.causes.isNotEmpty) ...[
              _infoSection('ПРИЧИНЫ', card.causes),
              const SizedBox(height: 12),
            ],
            _infoSection('РЕШЕНИЕ', card.solution),
            if (card.skus.isNotEmpty) ...[
              const SizedBox(height: 12),
              _infoSection('МАТЕРИАЛЫ', card.skus.join(', ')),
            ],
            if (isExpert) ...[
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
                          backgroundColor: AppColors.brandBlack,
                          shape: const BeveledRectangleBorder(),
                        ),
                        child: const Text('ОДОБРИТЬ'),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showEditSheet(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandBlack,
                        side: const BorderSide(color: AppColors.brandBlack),
                        shape: const BeveledRectangleBorder(),
                      ),
                      child: const Text('ИЗМЕНИТЬ'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditKnowledgeCardSheet(
        card: card,
        onSaved: onUpdate,
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
            color: AppColors.brandRed,
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

class _EditKnowledgeCardSheet extends StatefulWidget {
  final KnowledgeCard? card;
  final VoidCallback onSaved;
  const _EditKnowledgeCardSheet({this.card, required this.onSaved});

  @override
  State<_EditKnowledgeCardSheet> createState() => _EditKnowledgeCardSheetState();
}

class _EditKnowledgeCardSheetState extends State<_EditKnowledgeCardSheet> {
  final _problemCtrl = TextEditingController();
  final _causesCtrl = TextEditingController();
  final _solutionCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.card != null) {
      _problemCtrl.text = widget.card!.problem;
      _causesCtrl.text = widget.card!.causes;
      _solutionCtrl.text = widget.card!.solution;
    }
  }

  Future<void> _save() async {
    if (_problemCtrl.text.isEmpty || _solutionCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      if (widget.card == null) {
        await DataRepository().createKnowledgeCard({
          'problem': _problemCtrl.text.trim(),
          'causes': _causesCtrl.text.trim(),
          'solution': _solutionCtrl.text.trim(),
          'status': 'approved', 
        });
      } else {
        await DataRepository().updateKnowledgeCard(
          widget.card!.id,
          problem: _problemCtrl.text.trim(),
          causes: _causesCtrl.text.trim(),
          solution: _solutionCtrl.text.trim(),
        );
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(color: Colors.white),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.card == null ? 'НОВАЯ КАРТОЧКА' : 'РЕДАКТИРОВАНИЕ',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1, color: AppColors.brandRed),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                TextField(
                  controller: _problemCtrl,
                  decoration: const InputDecoration(labelText: 'ПРОБЛЕМА *'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _causesCtrl,
                  decoration: const InputDecoration(labelText: 'ПРИЧИНЫ'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _solutionCtrl,
                  decoration: const InputDecoration(labelText: 'РЕШЕНИЕ *'),
                  maxLines: 6,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: Text(_loading ? 'СОХРАНЕНИЕ...' : 'СОХРАНИТЬ КАРТОЧКУ'),
            ),
          ),
        ],
      ),
    );
  }
}
