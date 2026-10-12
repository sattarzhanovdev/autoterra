import 'package:flutter/material.dart';
import '../../services/data_repository.dart';

class DistributorProfileEditor extends StatefulWidget {
  final Map<String, dynamic> distributor;
  final DataRepository repository;
  const DistributorProfileEditor({
    super.key,
    required this.distributor,
    required this.repository,
  });
  @override
  State<DistributorProfileEditor> createState() =>
      _DistributorProfileEditorState();
}

class _DistributorProfileEditorState extends State<DistributorProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.distributor['name']);
  late final _email = TextEditingController(text: widget.distributor['email']);
  late final _phone = TextEditingController(text: widget.distributor['phone']);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.updateDistributorProfile({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
      });
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Не удалось сохранить: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Данные организации'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              enabled: !_saving,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Название организации',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Введите название' : null,
            ),
            TextFormField(
              controller: _email,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              maxLength: 254,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  v == null ||
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                  ? 'Введите email'
                  : null,
            ),
            TextFormField(
              controller: _phone,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              maxLength: 32,
              decoration: const InputDecoration(labelText: 'Телефон'),
              validator: (v) {
                final raw = v?.trim() ?? '';
                final digits = raw.replaceAll(RegExp(r'\D'), '').length;
                return !RegExp(r'^[+0-9()\s-]+$').hasMatch(raw) ||
                        digits < 7 ||
                        digits > 15
                    ? 'Введите телефон: от 7 до 15 цифр'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'ИНН и регионы изменяет администратор: они связаны с клиентами, ассортиментом и интеграцией.',
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
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
