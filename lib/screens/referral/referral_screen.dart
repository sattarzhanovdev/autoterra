import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late Future<List<Referral>> _future;

  @override
  void initState() {
    super.initState();
    _future = const DataRepository().referrals();
  }

  Future<void> _refresh() async {
    final next = const DataRepository().referrals();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ru_RU');
    const refCode = 'AT-MASTER-2847';

    return Scaffold(
      appBar: AppBar(title: const Text('Рекомендовать автосервис')),
      body: FutureBuilder<List<Referral>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final referrals = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHowItWorks(),
                  const SizedBox(height: 16),
                  _buildRefCode(context, refCode),
                  const SizedBox(height: 20),
                  _buildStats(referrals, fmt),
                  const SizedBox(height: 20),
                  const Text(
                    'Мои приглашения',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (referrals.isEmpty)
                    const Text(
                      'Приглашений пока нет',
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  else
                    ...referrals.map(
                      (r) => _ReferralCard(referral: r, fmt: fmt),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Как это работает',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _step('1', 'Отправьте реферальный код другому автосервису'),
            _step('2', 'Сервис регистрируется в своём регионе'),
            _step('3', 'Делает первый заказ от 30 000 ₽'),
            _step('4', 'Вы получаете подарок после подтверждения покупки'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Подарок начисляется только за реальный подтверждённый заказ',
                style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                n,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefCode(BuildContext context, String code) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ваш реферальный код',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: 1,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy_outlined,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Код скопирован'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Поделиться ссылкой'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.message_outlined, size: 18),
                    label: const Text('Отправить в WhatsApp'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(List<Referral> referrals, NumberFormat fmt) {
    final met = referrals.where((r) => r.conditionMet).length;
    final buyers = referrals.where((r) => r.hasPurchase).length;
    final purchaseAmount = referrals.fold<double>(
      0,
      (sum, item) => sum + item.purchaseAmount,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _stat('Приглашено', '${referrals.length}', AppColors.primary),
                _vDiv(),
                _stat(
                  'Зарегистрировано',
                  '${referrals.where((r) => r.isRegistered).length}',
                  AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _stat('С покупками', '$buyers', AppColors.warning),
                _vDiv(),
                _stat(
                  'Продажи клиентов',
                  '${fmt.format(purchaseAmount)} ₽',
                  AppColors.success,
                ),
                _vDiv(),
                _stat('Подарки', '$met', AppColors.success),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: value.length > 9 ? 18 : 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _vDiv() {
    return Container(width: 1, height: 36, color: AppColors.border);
  }
}

class _ReferralCard extends StatelessWidget {
  final Referral referral;
  final NumberFormat fmt;
  const _ReferralCard({required this.referral, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: referral.conditionMet
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    referral.conditionMet
                        ? Icons.check_circle_outline
                        : Icons.store_outlined,
                    color: referral.conditionMet
                        ? AppColors.success
                        : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        referral.inviteeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'ИНН: ${referral.inviteeInn} · ${referral.region}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _step2('Регистрация', referral.isRegistered),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 10,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 6),
                _step2('Первый заказ', referral.hasPurchase),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 10,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 6),
                _step2('Подарок', referral.conditionMet),
              ],
            ),
            if (referral.hasPurchase) ...[
              const SizedBox(height: 10),
              Text(
                'Сумма заказа: ${fmt.format(referral.purchaseAmount)} ₽',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (referral.gift != null && referral.conditionMet) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.card_giftcard,
                      color: AppColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      referral.gift!,
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _step2(String label, bool done) {
    return Column(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: done ? AppColors.success : AppColors.border,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: done ? AppColors.success : AppColors.textHint,
          ),
        ),
      ],
    );
  }
}
