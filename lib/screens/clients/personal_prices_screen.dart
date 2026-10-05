import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';

class ClientPersonalPricesTile extends StatelessWidget {
  final String clientId;
  const ClientPersonalPricesTile({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.price_change_outlined),
    title: const Text('Персональные цены'),
    subtitle: const Text('Базовые и индивидуальные цены товаров'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PersonalPricesScreen(clientId: clientId),
      ),
    ),
  );
}

class PersonalPricesScreen extends StatefulWidget {
  final String clientId;
  final DataRepository? repository;
  final bool embedded;
  const PersonalPricesScreen({
    super.key,
    required this.clientId,
    this.repository,
    this.embedded = false,
  });

  @override
  State<PersonalPricesScreen> createState() => _PersonalPricesScreenState();
}

class _PersonalPricesScreenState extends State<PersonalPricesScreen> {
  late final DataRepository _repo;
  late final PaginationController<Map<String, dynamic>> _controller;
  final _search = TextEditingController();
  bool _overridesOnly = true;
  bool _canEdit = false;
  final _money = NumberFormat('#,##0.00', 'ru_RU');

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DataRepository();
    _controller = PaginationController(
      fetchPage: (page) async {
        final result = await _repo.clientPrices(
          widget.clientId,
          page: page,
          search: _search.text.trim(),
          overridesOnly: _overridesOnly,
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

  String _price(dynamic value) =>
      '${_money.format(num.tryParse('$value') ?? 0)} ₽';

  Future<void> _edit(Map<String, dynamic> item) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _PriceDialog(
        clientId: widget.clientId,
        item: item,
        repository: _repo,
      ),
    );
    if (changed == true && mounted) await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(title: const Text('Персональные цены')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Найти товар по названию или артикулу',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => _controller.refreshDebounced(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Только персональные цены'),
                subtitle: const Text('Отключите, чтобы найти товар в каталоге'),
                value: _overridesOnly,
                onChanged: (value) {
                  setState(() => _overridesOnly = value);
                  _controller.refresh();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: PaginatedListView<Map<String, dynamic>>(
            controller: _controller,
            emptyMessage: _overridesOnly
                ? 'Персональные цены не заданы'
                : 'Товары не найдены',
            itemBuilder: (context, item, index) {
              final hasOverride = item['overrideId'] != null;
              final active = item['isActive'] == true;
              final updated = DateTime.tryParse(
                item['updatedAt']?.toString() ?? '',
              );
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Артикул: ${item['sku']}'),
                      const SizedBox(height: 8),
                      Text('Базовая цена: ${_price(item['basePrice'])}'),
                      Text('Цена по рангу: ${_price(item['rankPrice'])}'),
                      Text(
                        hasOverride
                            ? 'Персональная цена: ${_price(item['personalPrice'])}${active ? '' : ' · отключена'}'
                            : 'Персональная цена: не задана',
                      ),
                      Text(
                        'Цена для клиента: ${_price(item['price'])}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (item['productActive'] == false)
                        const Text('Товар скрыт из каталога'),
                      if (updated != null)
                        Text(
                          'Изменено: ${DateFormat('dd.MM.yyyy HH:mm').format(updated.toLocal())}',
                        ),
                      if (_canEdit)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _edit(item),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(
                              hasOverride ? 'Изменить цену' : 'Задать цену',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _PriceDialog extends StatefulWidget {
  final String clientId;
  final Map<String, dynamic> item;
  final DataRepository repository;
  const _PriceDialog({
    required this.clientId,
    required this.item,
    required this.repository,
  });

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  late final TextEditingController _price;
  late bool _active;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(
      text: widget.item['personalPrice']?.toString() ?? '',
    );
    _active =
        widget.item['overrideId'] == null || widget.item['isActive'] == true;
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _save({bool delete = false}) async {
    final price = _price.text.trim().replaceAll(',', '.');
    final value = double.tryParse(price);
    if (!delete &&
        (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(price) ||
            value == null ||
            value <= 0 ||
            value >= 10000000000)) {
      setState(
        () => _error =
            'Введите цену больше нуля, не более двух знаков после запятой',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final productId = widget.item['productId'].toString();
      if (delete) {
        await widget.repository.deleteClientPrice(widget.clientId, productId);
      } else {
        await widget.repository.saveClientPrice(
          widget.clientId,
          productId,
          price: price,
          isActive: _active,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Персональная цена'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.item['name']} · ${widget.item['sku']}'),
            TextField(
              controller: _price,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Цена, ₽'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Активна'),
              value: _active,
              onChanged: _busy ? null : (v) => setState(() => _active = v),
            ),
            const Text(
              'При отключении или удалении применяется цена по рангу, а без скидки — базовая. Созданные заказы не меняются.',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.brandRed),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.item['overrideId'] != null)
          TextButton(
            onPressed: _busy ? null : () => _save(delete: true),
            child: const Text('Удалить цену'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Сохранение…' : 'Сохранить'),
        ),
      ],
    ),
  );
}
