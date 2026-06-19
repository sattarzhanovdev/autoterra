import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/api_client.dart';
import '../../services/data_repository.dart';

class AddPurchaseScreen extends StatefulWidget {
  final ApiClient? api;
  const AddPurchaseScreen({super.key, this.api});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  late final ApiClient _api;
  final _formKey = GlobalKey<FormState>();
  final _docNumCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime? _date;
  PlatformFile? _pickedFile;
  final List<_SkuEntry> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiClient();
  }

  @override
  void dispose() {
    _docNumCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_SkuEntry()));
  }

  void _removeItem(int i) {
    setState(() => _items.removeAt(i));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result != null) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите дату')));
      return;
    }

    setState(() => _loading = true);

    try {
      final purchaseData = {
        'document_number': _docNumCtrl.text,
        'date': _date!.toIso8601String().split('T')[0],
        'amount': _amountCtrl.text.replaceAll(' ', '').replaceAll(',', '.'),
        'items': _items.map((e) => {
          'sku': e.sku,
          'category': e.category,
          'quantity': e.quantity,
          'price': e.price,
        }).toList(),
      };

      await DataRepository(api: _api).createPurchase(
        purchaseData,
        fileBytes: _pickedFile?.bytes,
        fileName: _pickedFile?.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Покупка успешно добавлена'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (e.details is Map && (e.details as Map)['error'] == 'duplicate_detected') {
        _showDuplicateDialog((e.details as Map)['message'] ?? e.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.brandRed),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.brandRed),
      );
    }
  }

  void _showDuplicateDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.brandBlack,
        shape: const BeveledRectangleBorder(),
        title: const Text(
          'ВНИМАНИЕ',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.brandRed, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              shape: const BeveledRectangleBorder(),
            ),
            child: const Text('ПОНЯТНО'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('ДОБАВИТЬ ПОКУПКУ')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDocumentSection(),
            const SizedBox(height: 16),
            _buildItemsSection(),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  shape: const BeveledRectangleBorder(),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('ОТПРАВИТЬ НА ПРОВЕРКУ'),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSection() {
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
            'ДОКУМЕНТ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _docNumCtrl,
            decoration: const InputDecoration(
              labelText: 'НОМЕР ДОКУМЕНТА *',
              border: OutlineInputBorder(borderRadius: BorderRadius.zero),
            ),
            validator: (v) => v!.isEmpty ? 'Введите номер документа' : null,
          ),
          const SizedBox(height: 16),
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
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'ДАТА ДОКУМЕНТА *',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
              child: Text(
                _date == null
                    ? 'ВЫБЕРИТЕ ДАТУ'
                    : '${_date!.day.toString().padLeft(2, '0')}.${_date!.month.toString().padLeft(2, '0')}.${_date!.year}',
                style: TextStyle(
                  color: _date == null ? AppColors.textHint : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'ОБЩАЯ СУММА, ₽ *',
              prefixIcon: Icon(Icons.attach_money),
              border: OutlineInputBorder(borderRadius: BorderRadius.zero),
            ),
            validator: (v) {
              if (v!.isEmpty) return 'Введите сумму';
              if (double.tryParse(v.replaceAll(' ', '').replaceAll(',', '.')) == null)
                return 'Неверный формат';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _sectionTitle('ФАЙЛ (ЧЕК / НАКЛАДНАЯ)'),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.canvas, border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  Icon(Icons.file_present, color: _pickedFile != null ? AppColors.success : AppColors.brandRed),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_pickedFile?.name ?? 'ВЫБРАТЬ ФАЙЛ (JPG, PDF)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  if (_pickedFile != null) const Icon(Icons.check, color: AppColors.success),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5));

  Widget _buildItemsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SKU / ПОЗИЦИИ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                ),
              ),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('ДОБАВИТЬ'),
                style: TextButton.styleFrom(foregroundColor: AppColors.brandRed),
              ),
            ],
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Добавьте позиции из заказа',
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
            ),
          ..._items.asMap().entries.map((e) => _buildItemEntry(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildItemEntry(int index, _SkuEntry entry) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'ПОЗИЦИЯ ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _removeItem(index),
                child: const Icon(Icons.close, size: 18, color: AppColors.textHint),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'АРТИКУЛ (SKU)',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.zero),
            ),
            onChanged: (v) => entry.sku = v,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'КАТЕГОРИЯ',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.zero),
            ),
            items: AppConstants.skuCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => entry.category = v,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'КОЛ-ВО',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => entry.quantity = int.tryParse(v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'ЦЕНА, ₽',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => entry.price = double.tryParse(v.replaceAll(',', '.')),
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
  String sku = '';
  String? category;
  int? quantity;
  double? price;
}

