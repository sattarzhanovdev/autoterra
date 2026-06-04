import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/api_client.dart';
import '../../widgets/common/attachment_picker.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _innCtrl = TextEditingController();
  final _docNumCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime? _date;
  List<PlatformFile> _attachments = [];
  final List<_SkuEntry> _items = [];
  bool _loading = false;
  final _api = const ApiClient();

  @override
  void initState() {
    super.initState();
    _loadClientInn();
  }

  @override
  void dispose() {
    _innCtrl.dispose();
    _docNumCtrl.dispose();
    _amountCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadClientInn() async {
    try {
      final result = await _api.me();
      final client = result['client'];
      if (mounted && client is Map<String, dynamic>) {
        _innCtrl.text = client['inn']?.toString() ?? '';
      }
    } catch (_) {
      // The field remains editable if profile preload is unavailable.
    }
  }

  void _addItem() {
    setState(() => _items.add(_SkuEntry()));
  }

  void _removeItem(int i) {
    final item = _items.removeAt(i);
    item.dispose();
    setState(() {});
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      _showError('Выберите дату документа');
      return;
    }
    if (_items.isEmpty) {
      _showError('Добавьте хотя бы одну SKU-позицию');
      return;
    }
    if (_attachments.isEmpty) {
      _showError('Прикрепите документ или фото покупки');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await _api.createPurchase(
        inn: _innCtrl.text,
        documentNumber: _docNumCtrl.text.trim(),
        date: _date!,
        totalAmount: double.parse(_amountCtrl.text.replaceAll(' ', '').replaceAll(',', '.')),
        items: _items.map((item) => item.toJson()).toList(),
        attachments: _attachments,
      );
      final purchase = result['purchase'];
      final status = purchase is Map<String, dynamic>
          ? purchase['status']?.toString()
          : 'pending_verification';
      if (mounted) {
        _showStatus(status ?? 'pending_verification');
        context.pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showError(_purchaseErrorMessage(error));
      }
    } on TimeoutException {
      if (mounted) {
        _showError('Сервер недоступен. Проверьте подключение и попробуйте снова.');
      }
    } catch (_) {
      if (mounted) {
        _showError('Не удалось отправить покупку. Попробуйте позже.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _purchaseErrorMessage(ApiException error) {
    final details = error.details;
    final code = details is Map<String, dynamic> ? details['code']?.toString() : null;
    switch (code) {
      case 'purchase_duplicate':
        return 'Этот документ уже отправлен на проверку.';
      case 'inn_mismatch':
        return 'ИНН не совпадает с профилем клиента.';
      case 'invalid_items':
      case 'items_required':
        return 'Проверьте SKU-позиции и количество.';
      case 'invalid_amount':
        return 'Введите корректную сумму документа.';
      default:
        return error.message.isNotEmpty ? error.message : 'Ошибка проверки документа.';
    }
  }

  void _showStatus(String status) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Покупка отправлена. Статус: ${_statusLabel(status)}')),
          ],
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_verification':
      case 'pending':
        return 'ожидает подтверждения';
      case 'duplicate_review':
        return 'проверка возможного дубля';
      case 'under_review':
        return 'ручная проверка';
      case 'verified':
        return 'подтверждена';
      case 'rejected':
        return 'отклонена';
      default:
        return 'на проверке';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить покупку')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDocumentSection(),
            const SizedBox(height: 16),
            AttachmentPicker(
              title: 'Документ покупки',
              emptyText: 'УПД, накладная, чек, PDF или фото документа',
              files: _attachments,
              onChanged: (files) => setState(() => _attachments = files),
            ),
            const SizedBox(height: 16),
            _buildItemsSection(),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Отправить на проверку'),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Документ',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _innCtrl,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: 'ИНН клиента *',
                counterText: '',
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Введите ИНН';
                if (value.length < 10) return 'ИНН должен содержать 10-12 цифр';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _docNumCtrl,
              decoration: const InputDecoration(
                labelText: 'Номер документа (УПД/накладная) *',
              ),
              validator: (v) => v!.isEmpty ? 'Введите номер документа' : null,
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _date = date);
              },
              borderRadius: BorderRadius.zero,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата документа *',
                ),
                child: Text(
                  _date == null
                      ? 'Выберите дату'
                      : '${_date!.day.toString().padLeft(2, '0')}.${_date!.month.toString().padLeft(2, '0')}.${_date!.year}',
                  style: TextStyle(
                    color: _date == null
                        ? AppColors.textHint
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Общая сумма, ₽ *',
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (v) {
                if (v!.isEmpty) return 'Введите сумму';
                if (double.tryParse(v.replaceAll(' ', '')) == null)
                  return 'Неверный формат';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'SKU / Позиции',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Добавить'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
            ),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Добавьте позиции из заказа',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              ),
            ..._items.asMap().entries.map(
              (e) => _buildItemEntry(e.key, e.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemEntry(int index, _SkuEntry entry) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandWhite,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.borderMuted),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Позиция ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _removeItem(index),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: entry.skuCtrl,
            decoration: const InputDecoration(
              labelText: 'Артикул (SKU)',
              isDense: true,
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Введите SKU' : null,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Категория',
              isDense: true,
            ),
            items: AppConstants.skuCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => entry.category = v,
            validator: (v) => v == null ? 'Выберите категорию' : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: entry.quantityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Кол-во',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final value = int.tryParse(v ?? '');
                    if (value == null || value <= 0) return 'Кол-во';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: entry.priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Цена, ₽',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (value == null || value < 0) return 'Цена';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkuEntry {
  final skuCtrl = TextEditingController();
  final quantityCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  String? category;

  Map<String, dynamic> toJson() {
    return {
      'sku': skuCtrl.text.trim(),
      'name': skuCtrl.text.trim(),
      'category': category,
      'quantity': int.parse(quantityCtrl.text),
      'price': double.parse(priceCtrl.text.replaceAll(',', '.')),
    };
  }

  void dispose() {
    skuCtrl.dispose();
    quantityCtrl.dispose();
    priceCtrl.dispose();
  }
}
