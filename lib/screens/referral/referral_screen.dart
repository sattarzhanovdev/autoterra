import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late final PaginationController<Referral> _controller;

  /// Сводка приходит тем же ответом и считается по всей базе, а не по
  /// загруженной странице — поэтому храним её отдельно от списка.
  Map<String, dynamic> _stats = const {};

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<Referral>(
      fetchPage: (page) async {
        final (result, stats) = await DataRepository().referrals(page: page);
        if (mounted) setState(() => _stats = stats);
        return result;
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reload() {
    _controller.refresh();
  }

  String? get _refCode => _stats['referralCode'] as String?;

  String? get _inviteLink => _stats['inviteLink'] as String?;

  void _share() {
    final code = _refCode;
    final link = _inviteLink;
    if (code == null || link == null) return;
    Share.share(
      'Присоединяйтесь к AutoTerra! Регистрация по моей ссылке: $link\n'
      'Или введите код при регистрации: $code',
      subject: 'Приглашение в AutoTerra',
    );
  }

  void _showAddDialog() {
    final innCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ПРИГЛАСИТЬ СТО', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 16),
              TextFormField(controller: innCtrl, decoration: const InputDecoration(labelText: 'ИНН СТО *')),
              const SizedBox(height: 12),
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'НАЗВАНИЕ СТО *')),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (innCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
                    await DataRepository().createReferral({
                      'inviteeInn': innCtrl.text,
                      'inviteeName': nameCtrl.text,
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      _reload();
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandRed),
                  child: const Text('ДОБАВИТЬ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ru_RU');

    return Scaffold(
      appBar: AppBar(title: const Text('РЕФЕРАЛЬНАЯ ПРОГРАММА')),
      body: PaginatedListView<Referral>(
        controller: _controller,
        emptyMessage: 'ПРИГЛАШЕНИЙ ПОКА НЕТ',
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHowItWorks(fmt),
            const SizedBox(height: 16),
            _buildRefCode(context),
            const SizedBox(height: 20),
            _buildStats(fmt),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('МОИ ПРИГЛАШЕНИЯ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                TextButton(
                  onPressed: _showAddDialog,
                  child: const Text('ДОБАВИТЬ +', style: TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
        itemBuilder: (context, referral, _) => _ReferralCard(
          referral: referral,
          fmt: fmt,
          threshold: (_stats['bonusThreshold'] as num?)?.toDouble(),
        ),
      ),
    );
  }

  Widget _buildHowItWorks(NumberFormat fmt) {
    // Порог и подарок настраиваются на сервере — в тексте показываем то, что
    // действует сейчас, а не зашитые в приложение цифры.
    final threshold = (_stats['bonusThreshold'] as num?)?.toInt();
    final gift = (_stats['bonusGift'] as String?)?.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('КАК ЭТО РАБОТАЕТ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 16),
          _step('1', 'ОТПРАВЬТЕ ССЫЛКУ ИЛИ КОД ДРУГОМУ СТО'),
          _step('2', 'СТО РЕГИСТРИРУЕТСЯ ПО НЕЙ И ДЕЛАЕТ ЗАКАЗЫ'),
          _step(
            '3',
            threshold == null
                ? 'СУММА ПОДТВЕРЖДЁННЫХ ЗАКАЗОВ ДОСТИГАЕТ ПОРОГА'
                : 'СУММА ПОДТВЕРЖДЁННЫХ ЗАКАЗОВ ДОСТИГАЕТ ${fmt.format(threshold)} ₽',
          ),
          _step(
            '4',
            (gift == null || gift.isEmpty)
                ? 'ВЫ ПОЛУЧАЕТЕ ПОДАРОК'
                : 'ВЫ ПОЛУЧАЕТЕ: ${gift.toUpperCase()}',
          ),
        ],
      ),
    );
  }

  Widget _step(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 20, height: 20, color: AppColors.brandRed, child: Center(child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildRefCode(BuildContext context) {
    final code = _refCode;
    final link = _inviteLink;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.brandBlack, border: Border.all(color: AppColors.brandBlack)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ВАШ РЕФЕРАЛЬНЫЙ КОД', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
          const SizedBox(height: 12),
          if (code == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Загружаем…',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white54),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(child: Text(code, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.brandRed, letterSpacing: 2))),
                IconButton(
                  tooltip: 'Скопировать код',
                  icon: const Icon(Icons.copy, color: Colors.white),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('КОД СКОПИРОВАН')));
                  },
                ),
              ],
            ),
            if (link != null) ...[
              const SizedBox(height: 4),
              // Ссылка — основной путь: по ней новый сервис регистрируется, и
              // система сама свяжет его с пригласившим.
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ССЫЛКА СКОПИРОВАНА')));
                },
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 13, color: Colors.white54),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        link,
                        style: const TextStyle(fontSize: 10, color: Colors.white54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share, size: 16),
                label: const Text('ПОДЕЛИТЬСЯ ССЫЛКОЙ'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandRed, shape: const BeveledRectangleBorder()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(NumberFormat fmt) {
    int stat(String key) => (_stats[key] as num? ?? 0).toInt();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          _stat('СТО', '${stat('invitedCount')}'),
          _stat('АКТИВНЫЕ', '${stat('buyersCount')}'),
          _stat('БОНУСЫ', '${stat('giftCount')}'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.brandBlack)),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  final Referral referral;
  final NumberFormat fmt;

  /// Порог бонуса приходит с сервера. Пока он не загружен, прогресс до бонуса
  /// не показываем — иначе он врал бы про зашитую в приложение сумму.
  final double? threshold;

  const _ReferralCard({required this.referral, required this.fmt, this.threshold});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(referral.inviteeName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              if (referral.conditionMet) const Icon(Icons.verified, color: AppColors.success, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text('ИНН: ${referral.inviteeInn} · ${referral.region.toUpperCase()}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          const Divider(height: 24),
          Row(
            children: [
              _stepIcon('РЕГИСТРАЦИЯ', referral.isRegistered),
              _arrow(),
              _stepIcon('ЗАКАЗЫ', referral.hasPurchase),
              _arrow(),
              _stepIcon('БОНУС', referral.conditionMet),
            ],
          ),
          if (referral.hasPurchase && !referral.conditionMet && threshold != null && threshold! > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (referral.purchaseAmount / threshold!).clamp(0.0, 1.0),
              backgroundColor: AppColors.canvas,
              color: AppColors.brandRed,
              minHeight: 4,
            ),
            const SizedBox(height: 4),
            Text(
              'ДО БОНУСА: ${fmt.format((threshold! - referral.purchaseAmount).clamp(0, double.infinity))} ₽',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textSecondary),
            ),
          ],
          if (referral.gift != null && referral.conditionMet) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.success.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard, size: 14, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(referral.gift!.toUpperCase(), style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepIcon(String label, bool done) {
    return Expanded(
      child: Column(
        children: [
          Icon(done ? Icons.check_box : Icons.check_box_outline_blank, size: 16, color: done ? AppColors.brandBlack : AppColors.border),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: done ? AppColors.brandBlack : AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _arrow() => const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward, size: 10, color: AppColors.border));
}

