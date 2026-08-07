import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/export_sheet.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../widgets/common/brand_icon.dart';

class ManagerClientsScreen extends StatefulWidget {
  /// Подменяется в тестах; в приложении создаётся сам.
  final DataRepository? repository;

  const ManagerClientsScreen({super.key, this.repository});

  @override
  State<ManagerClientsScreen> createState() => _ManagerClientsScreenState();
}

class _ManagerClientsScreenState extends State<ManagerClientsScreen> {
  late final DataRepository _repo;
  late final PaginationController<Client> _controller;

  String? _filterStatus;
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DataRepository();
    // Фильтры уходят на сервер — отбирать записи внутри загруженной страницы
    // нельзя, подходящие клиенты остались бы на других страницах.
    _controller = PaginationController<Client>(
      fetchPage: (page) => _repo.managerClientsFiltered(
        page: page,
        status: _filterStatus,
        category: _filterCategory,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() => _controller.refresh();

  void _openRegistration() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegistrationSheet(
        onCreated: () {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  /// Выгрузка идёт с теми же фильтрами, что и список на экране.
  void _openExport() {
    showClientExportSheet(
      context,
      status: _filterStatus,
      visibleCount: _controller.totalCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandWhite,
      appBar: AppBar(
        backgroundColor: AppColors.brandBlack,
        title: const Text(
          'КЛИЕНТЫ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            tooltip: 'Скачать список',
            onPressed: _openExport,
            icon: const Icon(Icons.download_outlined, color: Colors.white),
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: PaginatedListView<Client>(
              controller: _controller,
              emptyMessage: 'НЕТ КЛИЕНТОВ',
              itemBuilder: (_, client, __) => _ClientCard(
                client: client,
                onTap: () => context.push(
                  '${AppRoutes.managerClients}/${client.id}',
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegistration,
        backgroundColor: AppColors.brandRed,
        foregroundColor: Colors.white,
        shape: const BeveledRectangleBorder(
          borderRadius: BorderRadius.only(topRight: Radius.circular(14)),
        ),
        icon: const Icon(Icons.add),
        label: const Text(
          'РЕГИСТРАЦИЯ КЛИЕНТА',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppColors.brandBlack,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'ВСЕ',
              selected: _filterStatus == null && _filterCategory == null,
              onTap: () => setState(() {
                _filterStatus = null;
                _filterCategory = null;
                _load();
              }),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'АКТИВНЫЕ',
              selected: _filterStatus == 'active',
              onTap: () => setState(() {
                _filterStatus = 'active';
                _filterCategory = null;
                _load();
              }),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'НОВЫЕ',
              selected: _filterStatus == 'new',
              onTap: () => setState(() {
                _filterStatus = 'new';
                _filterCategory = null;
                _load();
              }),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'КАТ. A',
              selected: _filterCategory == 'a',
              onTap: () => setState(() {
                _filterCategory = 'a';
                _filterStatus = null;
                _load();
              }),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'КАТ. B',
              selected: _filterCategory == 'b',
              onTap: () => setState(() {
                _filterCategory = 'b';
                _filterStatus = null;
                _load();
              }),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'КАТ. C',
              selected: _filterCategory == 'c',
              onTap: () => setState(() {
                _filterCategory = 'c';
                _filterStatus = null;
                _load();
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: selected ? AppColors.brandRed : Colors.white.withOpacity(0.1),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback onTap;

  const _ClientCard({required this.client, required this.onTap});

  String get _statusLabel {
    switch (client.status) {
      case ClientStatus.newClient: return 'НОВЫЙ';
      case ClientStatus.pending: return 'ОЖИДАНИЕ';
      case ClientStatus.underReview: return 'НА ПРОВЕРКЕ';
      case ClientStatus.active: return 'АКТИВНЫЙ';
      case ClientStatus.blocked: return 'ЗАБЛОКИРОВАН';
      case ClientStatus.archived: return 'АРХИВ';
    }
  }

  Color get _statusColor {
    switch (client.status) {
      case ClientStatus.active: return AppColors.statusActive;
      case ClientStatus.blocked: return AppColors.statusBlocked;
      case ClientStatus.archived: return AppColors.statusNew;
      default: return AppColors.statusPending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: const BeveledRectangleBorder(
            side: BorderSide(color: AppColors.brandBlack, width: 1),
            borderRadius: BorderRadius.only(topRight: Radius.circular(15)),
          ),
          shadows: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(3, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: AppColors.brandBlack,
                    child: Text(
                      'КАТ. ${client.categoryLabel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: _statusColor.withOpacity(0.1),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                client.name.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppColors.brandBlack,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ИНН: ${client.inn}',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.bold),
              ),
              if (client.distributorName != null) ...[
                const SizedBox(height: 2),
                Text(
                  'ДИСТРИБЬЮТОР: ${client.distributorName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(BrandIcons.location, size: 13, color: AppColors.brandRed),
                  const SizedBox(width: 4),
                  Text(
                    '${client.city}, ${client.region}',
                    style: const TextStyle(fontSize: 11, color: AppColors.brandBlack, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Registration Bottom Sheet ──────────────────────────────────────────────────

// Business type options that map to backend category values.
const _kBusinessTypes = [
  ('a', 'A — Дилерский салон'),
  ('b', 'B — Автосервис с кузовным цехом'),
  ('c', 'C — Гаражный / малый сервис'),
];

class _RegistrationSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _RegistrationSheet({required this.onCreated});

  @override
  State<_RegistrationSheet> createState() => _RegistrationSheetState();
}

class _RegistrationSheetState extends State<_RegistrationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _repo = DataRepository();

  final _innCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  String? _category;

  // Regions and distributors are loaded from the API so we get real UUIDs.
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _distributors = [];
  bool _metaLoading = true;

  // Selected values hold the full map (id + name) so the UI can show names
  // while the API call sends only the id.
  Map<String, dynamic>? _selectedRegion;
  Map<String, dynamic>? _selectedDistributor;

  String? _apiError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    // Load independently so a failure in one doesn't block the other.
    List<Map<String, dynamic>> regions = [];
    List<Map<String, dynamic>> distributors = [];

    await Future.wait([
      _repo.getRegions()
          .then((v) => regions = v)
          .catchError((_) => regions = []),
      _repo.getDistributors()
          .then((v) => distributors = v)
          .catchError((_) => distributors = []),
    ]);

    if (mounted) {
      setState(() {
        _regions = regions;
        _distributors = distributors;
        _metaLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _innCtrl.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _apiError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _repo.managerCreateClient({
        'inn': _innCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'category': _category!,
        // Backend reads 'regionId' (UUID), NOT the region name string.
        'regionId': _selectedRegion!['id'],
        'city': _cityCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'contact': _contactCtrl.text.trim(),
        if (_selectedDistributor != null) 'distributorId': _selectedDistributor!['id'],
      });
      widget.onCreated();
    } catch (e) {
      if (mounted) setState(() => _apiError = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // SafeArea keeps content above the Android gesture zone / nav bar.
      // viewInsets.bottom (keyboard height) is added separately inside the
      // scrollable so the form lifts when the keyboard appears.
      bottom: true,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ─────────────────────────────────────────────────
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.zero,
              ),
            ),
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'РЕГИСТРАЦИЯ КЛИЕНТА',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1,
                      color: AppColors.brandBlack,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20, color: AppColors.brandBlack),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            // ── Loading metadata ─────────────────────────────────────────────
            if (_metaLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: AppColors.brandRed),
              )
            else ...[
              // ── Inline API error banner ────────────────────────────────────
              if (_apiError != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: AppColors.brandRed.withValues(alpha: 0.08),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: AppColors.brandRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _apiError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.brandRed,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // ── Scrollable form ────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  // Add keyboard height so the form scrolls above the keyboard.
                  // SafeArea already handles the nav bar — do NOT add viewPadding here.
                  padding: EdgeInsets.fromLTRB(
                    20, 0, 20,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ИНН — backend requires exactly 10 or 12 digits
                        _Field(
                          controller: _innCtrl,
                          label: 'ИНН',
                          required: true,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Обязательное поле';
                            final digits = v.trim();
                            if (!RegExp(r'^\d+$').hasMatch(digits)) return 'Только цифры';
                            if (digits.length != 10 && digits.length != 12) {
                              return 'ИНН: 10 или 12 цифр';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        // Название организации
                        _Field(
                          controller: _nameCtrl,
                          label: 'НАЗВАНИЕ ОРГАНИЗАЦИИ',
                          required: true,
                        ),
                        const SizedBox(height: 14),
                        // Тип объекта / категория
                        _FieldLabel(label: 'ТИП ОБЪЕКТА / КАТЕГОРИЯ', required: true),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _category,
                          isExpanded: true,
                          decoration: _inputDecoration('Выберите тип объекта'),
                          items: _kBusinessTypes
                              .map((t) => DropdownMenuItem(
                                    value: t.$1,
                                    child: Text(t.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _category = v),
                          validator: (v) => v == null ? 'Выберите тип объекта' : null,
                        ),
                        const SizedBox(height: 14),
                        // Регион — loaded from API, sends UUID to backend
                        _FieldLabel(label: 'РЕГИОН', required: true),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedRegion,
                          isExpanded: true,
                          decoration: _inputDecoration(
                            _regions.isEmpty ? 'Нет доступных регионов' : 'Выберите регион',
                          ),
                          items: _regions
                              .map((r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(
                                      r['name']?.toString() ?? r['id'].toString(),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ))
                              .toList(),
                          onChanged: _regions.isEmpty
                              ? null
                              : (v) => setState(() => _selectedRegion = v),
                          validator: (v) => v == null ? 'Выберите регион' : null,
                        ),
                        const SizedBox(height: 14),
                        // Дистрибьютор — optional; auto-assigned from region if omitted
                        _FieldLabel(label: 'ДИСТРИБЬЮТОР'),
                        const SizedBox(height: 4),
                        const Text(
                          'Если не указан — назначается автоматически по региону',
                          style: TextStyle(fontSize: 10, color: AppColors.textHint, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedDistributor,
                          isExpanded: true,
                          decoration: _inputDecoration('Выберите дистрибьютора (необязательно)'),
                          items: [
                            const DropdownMenuItem<Map<String, dynamic>>(
                              value: null,
                              child: Text(
                                'Авто (по региону)',
                                style: TextStyle(fontSize: 13, color: AppColors.textHint, fontStyle: FontStyle.italic),
                              ),
                            ),
                            ..._distributors.map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(
                                    d['name']?.toString() ?? d['id'].toString(),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                )),
                          ],
                          onChanged: (v) => setState(() => _selectedDistributor = v),
                        ),
                        const SizedBox(height: 14),
                        // Город
                        _Field(controller: _cityCtrl, label: 'ГОРОД'),
                        const SizedBox(height: 14),
                        // Контактное лицо
                        _Field(controller: _contactCtrl, label: 'КОНТАКТНОЕ ЛИЦО'),
                        const SizedBox(height: 14),
                        // Телефон
                        _Field(
                          controller: _phoneCtrl,
                          label: 'ТЕЛЕФОН',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        // Email
                        _Field(
                          controller: _emailCtrl,
                          label: 'EMAIL',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 28),
                        // Менеджер — информационная строка, не редактируется
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          color: AppColors.brandWhite,
                          child: const Row(
                            children: [
                              Icon(BrandIcons.person, size: 14, color: AppColors.textHint),
                              SizedBox(width: 8),
                              Text(
                                'Менеджер будет назначен автоматически (вы)',
                                style: TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Submit
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandRed,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.brandRed.withValues(alpha: 0.5),
                              elevation: 0,
                              shape: const BeveledRectangleBorder(
                                borderRadius: BorderRadius.only(topRight: Radius.circular(14)),
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'ЗАРЕГИСТРИРОВАТЬ',
                                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared form helpers ────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: AppColors.textHint,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.brandRed),
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, required: required),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: _inputDecoration(''),
          validator: validator ??
              (required
                  ? (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null
                  : null),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: AppColors.brandWhite,
      border: InputBorder.none,
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.zero,
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.brandBlack, width: 1.5),
        borderRadius: BorderRadius.zero,
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.brandRed, width: 1.5),
        borderRadius: BorderRadius.zero,
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.brandRed, width: 1.5),
        borderRadius: BorderRadius.zero,
      ),
      errorStyle: const TextStyle(
        color: AppColors.brandRed,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
