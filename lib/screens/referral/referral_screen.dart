import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/brand_icon.dart';

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

  /// Текст приглашения. Приложение никому ничего не отправляет само — ссылку
  /// разносит сам клиент через свой мессенджер, поэтому текст должен быть
  /// самодостаточным: и ссылка, и код на случай ручной регистрации.
  String? _inviteText({String? forName}) {
    final code = _refCode;
    final link = _inviteLink;
    if (code == null || link == null) return null;
    final greeting = (forName == null || forName.trim().isEmpty)
        ? 'Приглашаю вас в AutoTerra.'
        : 'Приглашаю «${forName.trim()}» в AutoTerra.';
    return '$greeting\n\n'
        'Зарегистрируйтесь по ссылке — она сразу свяжет ваш аккаунт с моим:\n'
        '$link\n\n'
        'Если регистрируетесь вручную, введите код приглашения: $code';
  }

  /// Открывает системное «Поделиться». Это единственный способ, которым
  /// приглашение доходит до второго СТО, — до этого запись видна только
  /// пригласившему.
  Future<void> _sendInvite({String? forName}) async {
    final text = _inviteText(forName: forName);
    if (text == null) {
      _toast('КОД ЕЩЁ ЗАГРУЖАЕТСЯ, ПОВТОРИТЕ ЧЕРЕЗ СЕКУНДУ');
      return;
    }
    await Share.share(text, subject: 'Приглашение в AutoTerra');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAddDialog() async {
    final innCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String? error;
    var busy = false;

    // Возвращает название СТО, если запись создана, — по нему сразу открываем
    // «Поделиться», иначе приглашение так и останется висеть только в ЛК.
    final createdName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          // Клавиатура — viewInsets, системная навигация Android — viewPadding.
          // Без второго кнопка «ДОБАВИТЬ» уезжает под кнопки навигации.
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom +
                MediaQuery.viewPaddingOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Colors.white),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ПРИГЛАСИТЬ СТО',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  // Главный вопрос клиентов: «как человек получит приглашение?».
                  // Отвечаем прямо в форме — само приложение ничего не шлёт.
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: AppColors.canvas,
                    child: const Text(
                      'Запись закрепит за вами это СТО по ИНН — вас свяжут, '
                      'даже если оно зарегистрируется без вашей ссылки.\n\n'
                      'Бонус начислится после того, как СТО при регистрации '
                      'подтвердит, что пригласили его вы.\n\n'
                      'Само приглашение отправите вы — после сохранения '
                      'откроется «Поделиться» с готовой ссылкой.',
                      style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: innCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 12,
                    decoration: const InputDecoration(
                      labelText: 'ИНН СТО *',
                      helperText: '10 цифр для организации, 12 — для ИП',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'НАЗВАНИЕ СТО *'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.brandRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final inn = innCtrl.text.trim();
                              final name = nameCtrl.text.trim();
                              // Проверяем только длину: контрольную сумму не
                              // считаем — в базе полно СТО с номерами, которые
                              // её не проходят.
                              if (inn.length != 10 && inn.length != 12) {
                                setSheetState(() => error = 'ИНН — 10 цифр для организации, 12 для ИП');
                                return;
                              }
                              if (name.isEmpty) {
                                setSheetState(() => error = 'Укажите название СТО');
                                return;
                              }
                              setSheetState(() {
                                error = null;
                                busy = true;
                              });
                              try {
                                await DataRepository().createReferral({
                                  'inviteeInn': inn,
                                  'inviteeName': name,
                                });
                                if (sheetContext.mounted) Navigator.pop(sheetContext, name);
                              } catch (e) {
                                // У ApiException toString() — это уже текст с
                                // сервера («Нельзя пригласить самого себя» и
                                // т.п.), показываем его как есть.
                                setSheetState(() {
                                  busy = false;
                                  error = '$e';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandRed),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('ДОБАВИТЬ И ОТПРАВИТЬ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    innCtrl.dispose();
    nameCtrl.dispose();
    if (createdName == null || !mounted) return;

    _reload();
    // Без этого шага приглашение остаётся только записью в ЛК пригласившего.
    await _sendInvite(forName: createdName);
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
          onResend: () => _sendInvite(forName: referral.inviteeName),
        ),
      ),
    );
  }

  /// Ступени ставки приходят с сервера — в приложении их не зашиваем, иначе
  /// после смены условий экран будет обещать не те проценты.
  List<({double from, double rate})> get _tiers {
    final raw = _stats['bonusTiers'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((item) => (
              from: (item['from'] as num? ?? 0).toDouble(),
              rate: (item['rate'] as num? ?? 0).toDouble(),
            ))
        .toList();
  }

  double? get _activityMin => (_stats['activityMin'] as num?)?.toDouble();

  Widget _buildHowItWorks(NumberFormat fmt) {
    final tiers = _tiers;

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
          // Бонус — процент от подтверждённых закупок и выполненных заказов
          // приглашённого, см. api/services/referral_bonus.py.
          _step('3', 'ПРОЦЕНТ ОТ ЕГО ЗАКУПОК КАПАЕТ НА ВАШ БОНУСНЫЙ СЧЁТ'),
          _step('4', 'ЧЕМ БОЛЬШЕ ОН ЗАКУПАЕТ, ТЕМ ВЫШЕ ВАША СТАВКА'),
          if (tiers.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('СТАВКА ПО ОБОРОТУ СТО', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            const SizedBox(height: 8),
            ...tiers.map(
              (tier) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tier.from == 0 ? 'ДО ${fmt.format(tiers.length > 1 ? tiers[1].from : 0)} ₽' : 'ОТ ${fmt.format(tier.from)} ₽',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    Text(
                      '${tier.rate}%',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.brandRed),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_activityMin != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.canvas,
              child: Text(
                'ЗАКУПАЙТЕСЬ САМИ ОТ ${fmt.format(_activityMin)} ₽ В МЕСЯЦ — '
                'ИНАЧЕ НАКОПЛЕННЫЕ БОНУСЫ СГОРАЮТ',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textSecondary),
              ),
            ),
          ],
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
                onPressed: () => _sendInvite(),
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

  /// Повторная отправка ссылки: пока СТО не зарегистрировалось, запись живёт
  /// только в ЛК пригласившего, и её нужно чем-то «дожать».
  final VoidCallback onResend;

  const _ReferralCard({
    required this.referral,
    required this.fmt,
    required this.onResend,
  });

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
              // Галочка только после согласования — условие выполнено ещё не
              // значит, что подарок выдан.
              _stepIcon('БОНУС', referral.giftApproved),
            ],
          ),
          // Приглашённый должен сам подтвердить, что его привели именно вы —
          // иначе подарка не будет. Пишем это прямо, чтобы ожидание бонуса не
          // упиралось в невидимое условие.
          if (referral.awaitingConfirmation && referral.isRegistered) ...[
            const SizedBox(height: 12),
            _giftBanner(
              icon: Icons.help_outline,
              color: AppColors.textSecondary,
              text: 'СТО ЕЩЁ НЕ ПОДТВЕРДИЛО ПРИГЛАШЕНИЕ — БОНУС НЕ НАЧИСЛИТСЯ',
            ),
          ],
          if (referral.confirmationDeclined) ...[
            const SizedBox(height: 12),
            _giftBanner(
              icon: Icons.person_off_outlined,
              color: AppColors.brandRed,
              text: 'СТО УКАЗАЛО, ЧТО ЕГО ПРИГЛАСИЛИ НЕ ВЫ',
            ),
          ],
          // Пока СТО не зарегистрировалось, запись никак ему не видна: система
          // свяжет их только когда оно придёт по ссылке или заведётся с этим
          // ИНН. Поэтому здесь прямо говорим, чего ждём, и даём переотправить.
          if (!referral.isRegistered) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.canvas,
              child: Row(
                children: [
                  const Icon(Icons.schedule_send, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ЖДЁМ РЕГИСТРАЦИЮ. ОТПРАВЬТЕ ССЫЛКУ, ЕСЛИ ЕЩЁ НЕ ОТПРАВИЛИ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onResend,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'ОТПРАВИТЬ',
                        style: TextStyle(
                          color: AppColors.brandRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Сколько этот СТО принёс и по какой ставке — иначе сумма на
          // бонусном счёте выглядит взявшейся ниоткуда.
          if (referral.hasPurchase) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ЗАКУПИЛ: ${fmt.format(referral.purchaseAmount)} ₽ · СТАВКА ${referral.bonusRate}%',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                Text(
                  '+${fmt.format(referral.bonusEarned)} ₽',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.brandRed),
                ),
              ],
            ),
          ],
          // Подарок проходит согласование у дистрибьютора: до его решения
          // конкретную скидку обещать нельзя (п. 7 ТЗ).
          if (referral.giftPending) ...[
            const SizedBox(height: 12),
            _giftBanner(
              icon: Icons.hourglass_empty,
              color: AppColors.textSecondary,
              text: 'ПОДАРОК НА СОГЛАСОВАНИИ У ДИСТРИБЬЮТОРА',
            ),
          ],
          if (referral.giftDeclined) ...[
            const SizedBox(height: 12),
            _giftBanner(
              icon: Icons.block,
              color: AppColors.brandRed,
              text: referral.giftComment == null
                  ? 'ПОДАРОК НЕ СОГЛАСОВАН'
                  : 'НЕ СОГЛАСОВАН: ${referral.giftComment!.toUpperCase()}',
            ),
          ],
          if (referral.gift != null && referral.giftApproved) ...[
            const SizedBox(height: 12),
            _giftBanner(
              icon: Icons.card_giftcard,
              color: AppColors.success,
              text: referral.gift!.toUpperCase(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _giftBanner({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
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

  Widget _arrow() => const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: BrandIcon(BrandIcons.arrowRight, size: 10, color: AppColors.border));
}

