import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';

class ShopMarkupEditor extends StatefulWidget {
  final Client client;
  final DataRepository repository;
  const ShopMarkupEditor({
    super.key,
    required this.client,
    required this.repository,
  });

  @override
  State<ShopMarkupEditor> createState() => _ShopMarkupEditorState();
}

class _ShopMarkupEditorState extends State<ShopMarkupEditor> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text:
          (DataRepository.markupChanges.value[widget.client.id] ??
                  widget.client.markupPercent)
              .toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim().replaceAll(',', '.');
    final value = double.tryParse(text);
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text) ||
        value == null ||
        !value.isFinite ||
        value < 0 ||
        value > 9999.99) {
      setState(
        () => _error =
            'Введите число от 0 до 9999,99, до двух знаков после запятой',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateMyMarkup(text);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Не удалось сохранить: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Моя наценка, %'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Цена продажи рассчитывается от вашей закупочной цены после скидок. Наценка не меняет сумму заказа и оплаты в AutoTerra.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          enabled: !_saving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Наценка, %',
            suffixText: '%',
            errorText: _error,
          ),
          onSubmitted: (_) {
            if (!_saving) _save();
          },
        ),
      ],
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
