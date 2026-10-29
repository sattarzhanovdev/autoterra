import '../../services/screen_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/share_origin.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/brand_icon.dart';
import '../../core/constants.dart';
import 'bonus_history_screen.dart';
import '../../widgets/common/referral_progress.dart';

class ReferralScreen extends StatefulWidget {
  final DataRepository? repository;
  const ReferralScreen({super.key, this.repository});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late final ScreenRefresh _liveRefresh;

  late final PaginationController<Referral> _controller;
  late final DataRepository _repo;

  /// Сводка приходит тем же ответом и считается по всей базе, а не по
  /// загруженной странице — поэтому храним её отдельно от списка.
  Map<String, dynamic> _stats = const {};

  @override
  void initState() {
    super.initState();
    _liveRefresh = ScreenRefresh(
      active: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false),
      refresh: () => _controller.refresh(preservePages: true),
    );
    _repo = widget.repository ?? DataRepository();
    _controller = PaginationController<Referral>(
      fetchPage: (page) async {
        final (result, stats) = await _repo.referrals(page: page);
        if (mounted) setState(() => _stats = stats);
        return result;
      },
    );
  }

  @override
  void dispose() {
    _liveRefresh.dispose();
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
        ? 'Приглашаю вас в ${AppConstants.appName}.'
        : 'Приглашаю «${forName.trim()}» в ${AppConstants.appName}.';
    final appLink = AppConstants.appStoreUrl.isEmpty
        ? ''
        : 'Приложение для Android:\n${AppConstants.appStoreUrl}\n\n';
    return '$greeting\n\n'
        'Для регистрации используйте ссылку с моим кодом приглашения:\n'
        '$link\n\n'
        '$appLink'
        'При регистрации без ссылки укажите код приглашения: $code';
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
    await Share.share(
      text,
      subject: 'Приглашение в ${AppConstants.appName}',
      sharePositionOrigin: shareOriginFrom(context),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            bottom:
                MediaQuery.viewInsetsOf(sheetContext).bottom +
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
                      'Укажите ИНН и название СТО. После регистрации с этим ИНН '
                      'приглашённому СТО потребуется подтвердить приглашение.\n\n'
                      'Бонусы начисляются за подтверждённые закупки и выполненные '
                      'заказы после подтверждения приглашения.\n\n'
                      'После сохранения откроется «Поделиться», чтобы вы могли '
                      'отправить ссылку приглашённому СТО.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
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
                    decoration: const InputDecoration(
                      labelText: 'НАЗВАНИЕ СТО *',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.brandRed,
                        fontSize: 14,
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
                                setSheetState(
                                  () => error =
                                      'ИНН — 10 цифр для организации, 12 для ИП',
                                );
                                return;
                              }
                              if (name.isEmpty) {
                                setSheetState(
                                  () => error = 'Укажите название СТО',
                                );
                                return;
                              }
                              setSheetState(() {
                                error = null;
                                busy = true;
                              });
                              try {
                                await _repo.createReferral({
                                  'inviteeInn': inn,
                                  'inviteeName': name,
                                });
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext, name);
                                }
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandRed,
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
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
            _buildBalance(fmt),
            const SizedBox(height: 16),
            _buildHowItWorks(fmt),
            const SizedBox(height: 16),
            _buildRefCode(context),
            const SizedBox(height: 20),
            _buildStats(fmt),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'МОИ ПРИГЛАШЕНИЯ',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: _showAddDialog,
                  child: const Text(
                    'ДОБАВИТЬ +',
                    style: TextStyle(
                      color: AppColors.brandRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
        itemBuilder: (context, referral, _) => _ReferralCard(
          referral: referral,
          tiers: _tiers,
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
        .map(
          (item) => (
            from: (item['from'] as num? ?? 0).toDouble(),
            rate: (item['rate'] as num? ?? 0).toDouble(),
          ),
        )
        .toList();
  }

  double? get _activityMin => (_stats['activityMin'] as num?)?.toDouble();

  Widget _buildHowItWorks(NumberFormat fmt) {
    final tiers = _tiers;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'КАК ЭТО РАБОТАЕТ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _step(
            '1',
            'Отправьте коллеге или представителю магазина автозапчастей или автосервиса свою ссылку или код приглашения.',
          ),
          _step(
            '2',
            'Приглашённый участник регистрируется по вашей ссылке или коду. Если он указывает ИНН, ему нужно подтвердить, что приглашение получил от вас.',
          ),
          _step(
            '3',
            'После подтверждения его заказов бонусы поступят на ваш бонусный счёт. Размер бонусов можно посмотреть в таблице заказов.',
          ),
          _step(
            '4',
            'Ставка рассчитывается отдельно для каждого приглашённого участника и зависит от общей суммы его заказов.',
          ),
          const Material(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Условия программы', style: TextStyle(fontSize: 14)),
              children: [
                Text(
                  'ООО «АвтоТерра Плюс» может изменять условия и ставки бонусной программы. Новые условия применяются только к заказам, подтверждённым после вступления изменений в силу. Ранее начисленные бонусы сохраняются. Актуальные ставки указаны в таблице бонусов.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
          if (tiers.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'СТАВКИ НАЧИСЛЕНИЯ БОНУСОВ',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...tiers.map(
              (tier) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tier.from == 0 && tiers.length > 1
                            ? 'До ${fmt.format(tiers[1].from)} ₽'
                            : 'От ${fmt.format(tier.from)} ₽',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${NumberFormat('0.##', 'ru_RU').format(tier.rate)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brandRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (tiers.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Ставка новой подтверждённой операции зависит от накопленного оборота приглашённого. Ранее начисленные бонусы не пересчитываются.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (_activityMin != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.canvas,
              child: Text(
                'Для сохранения бонусного баланса ваш собственный подтверждённый оборот должен составлять не менее ${fmt.format(_activityMin)} ₽ за календарный месяц. '
                'При невыполнении условия накопленный бонусный баланс аннулируется.',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: const EdgeInsets.all(4),
            color: AppColors.brandRed,
            child: Center(
              child: Text(
                n,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefCode(BuildContext context) {
    final code = _refCode;
    final link = _inviteLink;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandBlack,
        border: Border.all(color: AppColors.brandBlack),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ВАШ РЕФЕРАЛЬНЫЙ КОД',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (code == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Загружаем…',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: AppColors.brandRed,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Скопировать код',
                  icon: const Icon(Icons.copy, color: Colors.white),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('КОД СКОПИРОВАН')),
                    );
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ССЫЛКА СКОПИРОВАНА')),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 13, color: Colors.white54),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        link,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  shape: const BeveledRectangleBorder(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalance(NumberFormat fmt) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Бонусный баланс',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        Text(
          'Доступно: ${fmt.format(double.tryParse('${_stats['bonusBalance']}') ?? 0)} ₽',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        Text('Приглашённых: ${_stats['invitedCount'] ?? 0}'),
        Text(
          'Подтверждённый оборот: ${fmt.format(double.tryParse('${_stats['purchaseAmount']}') ?? 0)} ₽',
        ),
        Text(
          'Всего начислено бонусов: ${fmt.format(double.tryParse('${_stats['totalEarned']}') ?? 0)} ₽',
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BonusHistoryScreen(repository: _repo),
            ),
          ),
          child: const Text('История бонусов'),
        ),
      ],
    ),
  );

  Widget _buildStats(NumberFormat fmt) {
    int stat(String key) => (_stats[key] as num? ?? 0).toInt();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _stat('СТО', '${stat('invitedCount')}'),
          _stat('АКТИВНЫЕ', '${stat('buyersCount')}'),
          _stat('С БОНУСАМИ', '${stat('giftCount')}'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: AppColors.brandBlack,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  final Referral referral;
  final List<({double from, double rate})> tiers;
  final NumberFormat fmt;

  /// Повторная отправка ссылки: пока СТО не зарегистрировалось, запись живёт
  /// только в ЛК пригласившего, и её нужно чем-то «дожать».
  final VoidCallback onResend;

  const _ReferralCard({
    required this.referral,
    required this.tiers,
    required this.fmt,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  referral.inviteeName.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              if (referral.conditionMet)
                const Icon(Icons.verified, color: AppColors.success, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ИНН: ${referral.inviteeInn} · ${referral.region.toUpperCase()}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          ReferralProgress(volume: referral.purchaseAmount, tiers: tiers),
          Row(
            children: [
              _stepIcon('РЕГИСТРАЦИЯ', referral.isRegistered),
              _arrow(),
              _stepIcon('ЗАКАЗЫ', referral.hasPurchase),
              _arrow(),
              // Галочка по факту начисления: согласование убрано, бонус
              // начисляется после выполнения условий программы.
              _stepIcon('БОНУС', referral.bonusEarned > 0),
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
              text:
                  'Ожидается подтверждение приглашения от СТО. До подтверждения бонусы по этому приглашению не начисляются.',
            ),
          ],
          if (referral.confirmationDeclined) ...[
            const SizedBox(height: 12),
            _giftBanner(
              icon: Icons.person_off_outlined,
              color: AppColors.brandRed,
              text:
                  'Приглашённое СТО не подтвердило связь с вами. Бонусы по этому приглашению не начисляются.',
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
                  const Icon(
                    Icons.schedule_send,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ожидается регистрация СТО. Отправьте ссылку-приглашение.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
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
                          fontSize: 14,
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
                Expanded(
                  child: Text(
                    'Подтверждённый оборот: ${fmt.format(referral.purchaseAmount)} ₽ · ставка ${NumberFormat('0.##', 'ru_RU').format(referral.bonusRate)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+${fmt.format(referral.bonusEarned)} ₽',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brandRed,
                  ),
                ),
              ],
            ),
          ],
          // Плоский подарок остался только у старых связок — новые получают
          // процент на бонусный счёт автоматически, без согласования.
          if (referral.gift != null) ...[
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
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
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
          Icon(
            done ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: done ? AppColors.brandBlack : AppColors.border,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: done ? AppColors.brandBlack : AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: Icon(BrandIcons.arrowRight, size: 10, color: AppColors.border),
  );
}
