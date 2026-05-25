import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _docNumCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime? _date;
  final List<_SkuEntry> _items = [];
  bool _loading = false;

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

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Покупка отправлена на проверку'),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
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
            _buildPhotoSection(),
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
              borderRadius: BorderRadius.circular(10),
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

  Widget _buildPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Фото документа',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'УПД, накладная или счёт',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {},
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 32,
                      color: AppColors.primary.withOpacity(0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Нажмите для загрузки',
                      style: TextStyle(
                        color: AppColors.primary.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
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
            decoration: const InputDecoration(
              labelText: 'Артикул (SKU)',
              isDense: true,
            ),
            onChanged: (v) => entry.sku = v,
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
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Кол-во',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => entry.quantity = int.tryParse(v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Цена, ₽',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => entry.price = double.tryParse(v),
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
