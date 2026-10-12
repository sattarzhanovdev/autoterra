import 'package:flutter/material.dart';
import '../../services/data_repository.dart';

/// Choice labels and values come from Django, including future categories.
class ClientSettingsCard extends StatefulWidget {
  final String clientId;
  final DataRepository? repository;
  final VoidCallback? onChanged;
  const ClientSettingsCard({
    super.key,
    required this.clientId,
    this.repository,
    this.onChanged,
  });

  @override
  State<ClientSettingsCard> createState() => _ClientSettingsCardState();
}

class _ClientSettingsCardState extends State<ClientSettingsCard> {
  late final _repo = widget.repository ?? DataRepository();
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.clientSettings(widget.clientId);
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось загрузить настройки клиента');
      }
    }
  }

  String _label(String field, String choices) {
    final value = _data!['client'][field];
    for (final choice in _data![choices] as List) {
      if (choice['value'] == value) return choice['label'].toString();
    }
    return value.toString();
  }

  Future<void> _edit() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _SettingsDialog(data: _data!, repo: _repo, id: widget.clientId),
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
    return ListTile(
      title: Text('Статус: ${_label('status', 'statuses')}'),
      subtitle: Text('Категория: ${_label('category', 'categories')}'),
      trailing: _data!['canEdit'] == true
          ? IconButton(
              tooltip: 'Изменить статус и категорию',
              onPressed: _edit,
              icon: const Icon(Icons.edit),
            )
          : null,
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final DataRepository repo;
  final String id;
  const _SettingsDialog({
    required this.data,
    required this.repo,
    required this.id,
  });
  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late String _status = widget.data['client']['status'];
  late String _category = widget.data['client']['category'];
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.repo.updateClientSettings(widget.id, {
        'status': _status,
        'category': _category,
      });
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Не удалось сохранить настройки клиента';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Настройки клиента'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Статус'),
            items: [
              for (final c in widget.data['statuses'] as List)
                DropdownMenuItem(
                  value: c['value'] as String,
                  child: Text(c['label'], overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _saving ? null : (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Категория'),
            items: [
              for (final c in widget.data['categories'] as List)
                DropdownMenuItem(
                  value: c['value'] as String,
                  child: Text(c['label'], overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _saving ? null : (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          const Text(
            'Категория «Магазин» даёт доступ к наценке. Блокировка и архив ограничивают доступ клиента.',
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
