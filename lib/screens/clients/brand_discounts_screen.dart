import 'package:flutter/material.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';

class ClientBrandDiscountsTile extends StatelessWidget {
  final String clientId;
  final DataRepository? repository;
  final VoidCallback? onChanged;
  const ClientBrandDiscountsTile({
    super.key,
    required this.clientId,
    this.repository,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.discount_outlined),
    title: const Text('Скидки по брендам'),
    subtitle: const Text('Выбрать бренды и задать персональный процент'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BrandDiscountsScreen(
          clientId: clientId,
          repository: repository,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

class BrandDiscountsScreen extends StatefulWidget {
  final String clientId;
  final DataRepository? repository;
  final VoidCallback? onChanged;
  const BrandDiscountsScreen({
    super.key,
    required this.clientId,
    this.repository,
    this.onChanged,
  });
  @override
  State<BrandDiscountsScreen> createState() => _BrandDiscountsScreenState();
}

class _BrandDiscountsScreenState extends State<BrandDiscountsScreen> {
  late final _repo = widget.repository ?? DataRepository();
  late final PaginationController<Map<String, dynamic>> _controller;
  final _search = TextEditingController();
  final Set<String> _selected = {};
  bool _onlyDiscounts = false;
  bool _canEdit = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = PaginationController(
      fetchPage: (page) async {
        final result = await _repo.clientBrandDiscounts(
          widget.clientId,
          page: page,
          search: _search.text.trim(),
          discountsOnly: _onlyDiscounts,
        );
        if (mounted) {
          setState(() => _canEdit = result.metadata['canEdit'] == true);
        }
        return result;
      },
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _edit(List<String> brands, {String? percent}) async {
    if (brands.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите не более 200 брендов за один раз'),
        ),
      );
      return;
    }
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _BrandPercentDialog(
        repo: _repo,
        clientId: widget.clientId,
        brands: brands,
        percent: percent,
      ),
    );
    if (!mounted || changed != true) return;
    setState(() => _selected.removeAll(brands));
    await _controller.refresh();
    if (mounted) widget.onChanged?.call();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить скидку ${row['label']}?'),
        content: const Text(
          'Для этого бренда снова будет применяться общая скидка клиента или скидка по рангу. Персональные цены товаров сохраняются.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteBrandDiscount(widget.clientId, row['brand']);
      if (!mounted) return;
      setState(() => _selected.remove(row['brand']));
      await _controller.refresh();
      if (mounted) widget.onChanged?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось удалить скидку. Повторите попытку.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Скидки по брендам')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Поиск бренда',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => _controller.refreshDebounced(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Только установленные скидки'),
                value: _onlyDiscounts,
                onChanged: _busy
                    ? null
                    : (v) {
                        setState(() => _onlyDiscounts = v);
                        _controller.refresh();
                      },
              ),
              if (_canEdit)
                FilledButton(
                  onPressed: _selected.isEmpty || _busy
                      ? null
                      : () => _edit(_selected.toList()),
                  child: Text('Задать скидку (${_selected.length})'),
                ),
            ],
          ),
        ),
        Expanded(
          child: PaginatedListView<Map<String, dynamic>>(
            controller: _controller,
            emptyMessage: 'Бренды не найдены',
            itemBuilder: (context, row, index) => Card(
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _selected.contains(row['brand']),
                    onChanged: _canEdit && !_busy
                        ? (value) => setState(() {
                            if (value == true) {
                              _selected.add(row['brand']);
                            } else {
                              _selected.remove(row['brand']);
                            }
                          })
                        : null,
                    title: Text(row['label']),
                    subtitle: Text(
                      '${row['percent'] == null ? 'Общая скидка / ранг' : '${row['percent']}%'}${row['available'] == false ? '\nБренд временно отсутствует в каталоге' : ''}',
                    ),
                  ),
                  if (_canEdit)
                    Wrap(
                      children: [
                        TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _edit([
                                  row['brand'],
                                ], percent: row['percent']?.toString()),
                          icon: const Icon(Icons.edit),
                          label: const Text('Изменить'),
                        ),
                        if (row['percent'] != null)
                          TextButton.icon(
                            onPressed: _busy ? null : () => _delete(row),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Удалить'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BrandPercentDialog extends StatefulWidget {
  final DataRepository repo;
  final String clientId;
  final List<String> brands;
  final String? percent;
  const _BrandPercentDialog({
    required this.repo,
    required this.clientId,
    required this.brands,
    this.percent,
  });
  @override
  State<_BrandPercentDialog> createState() => _BrandPercentDialogState();
}

class _BrandPercentDialogState extends State<_BrandPercentDialog> {
  late final _percent = TextEditingController(text: widget.percent ?? '');
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _percent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _percent.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null ||
        !value.isFinite ||
        value < 0 ||
        value > 40 ||
        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw)) {
      setState(
        () => _error =
            'Введите процент от 0 до 40, до двух знаков после запятой',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.saveBrandDiscounts(widget.clientId, [
        for (final brand in widget.brands) {'brand': brand, 'percent': raw},
      ]);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Не удалось сохранить скидки. Повторите попытку.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Скидка для брендов: ${widget.brands.length}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _percent,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Скидка, %',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '0% задаёт цену без процентных скидок для бренда. Персональная цена конкретного товара имеет приоритет. Удаление записи вернёт общую скидку или ранг.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Сохранение…' : 'Сохранить'),
      ),
    ],
  );
}
