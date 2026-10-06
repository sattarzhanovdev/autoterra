import 'package:flutter/material.dart';
import '../../services/data_repository.dart';

class ClientDiscountCard extends StatefulWidget {
  final String clientId;
  final DataRepository? repository;
  final VoidCallback? onChanged;
  const ClientDiscountCard({
    super.key,
    required this.clientId,
    this.repository,
    this.onChanged,
  });

  @override
  State<ClientDiscountCard> createState() => _ClientDiscountCardState();
}

class _ClientDiscountCardState extends State<ClientDiscountCard> {
  late final DataRepository _repo = widget.repository ?? DataRepository();
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.clientDiscount(widget.clientId);
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить скидку');
    }
  }

  Future<void> _edit() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DiscountDialog(
        repository: _repo,
        clientId: widget.clientId,
        value: _data!['personalDiscountPercent']?.toString(),
      ),
    );
    if (mounted && result != null) {
      setState(() => _data = result);
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ListTile(
        title: Text(_error!),
        trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      );
    }
    if (_data == null) return const LinearProgressIndicator();
    final value = _data!['personalDiscountPercent'];
    return ListTile(
      title: const Text('Персональная скидка, %'),
      subtitle: Text(
        value == null
            ? 'Не задана — действует скидка по рангу'
            : '$value% на весь ассортимент',
      ),
      trailing: _data!['canEdit'] == true
          ? IconButton(
              tooltip: 'Изменить скидку',
              onPressed: _edit,
              icon: const Icon(Icons.edit),
            )
          : const Icon(Icons.lock_outline),
    );
  }
}

class _DiscountDialog extends StatefulWidget {
  final DataRepository repository;
  final String clientId;
  final String? value;
  const _DiscountDialog({
    required this.repository,
    required this.clientId,
    this.value,
  });
  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late final _controller = TextEditingController(text: widget.value ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save({bool reset = false}) async {
    final raw = _controller.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (!reset &&
        (value == null ||
            !value.isFinite ||
            value < 0 ||
            value > 100 ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw))) {
      setState(
        () =>
            _error = 'Введите число от 0 до 100, до двух знаков после запятой',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.updateClientDiscount(
        widget.clientId,
        reset ? null : raw,
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Не удалось сохранить скидку';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Персональная скидка, %'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Скидка от 0 до 100%',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '0% отменяет скидку по рангу. Персональная цена товара имеет приоритет.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      TextButton(
        onPressed: _saving ? null : () => _save(reset: true),
        child: const Text('По рангу'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Сохранение…' : 'Сохранить'),
      ),
    ],
  );
}
