import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import '../../services/data_repository.dart';
import '../../core/theme.dart';

class DistributorStockScreen extends StatefulWidget {
  const DistributorStockScreen({super.key});

  @override
  State<DistributorStockScreen> createState() => _DistributorStockScreenState();
}

class _DistributorStockScreenState extends State<DistributorStockScreen> {
  final DataRepository _repo = DataRepository();
  List<ProductData> _products = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.distributorStock();
      if (mounted) {
        setState(() {
          _products = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _pickAndUploadExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) throw 'Не удалось прочитать файл';

      final excel = Excel.decodeBytes(bytes);
      final List<Map<String, dynamic>> items = [];

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        for (int i = 1; i < sheet.maxRows; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          final sku = row[0]?.value?.toString();
          if (sku == null || sku.isEmpty) continue;

          items.add({
            'sku': sku,
            'name': row[1]?.value?.toString() ?? 'Без названия',
            'category': row[2]?.value?.toString() ?? 'Общее',
            'brand': row[3]?.value?.toString() ?? 'AutoTerra',
            'price': double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0.0,
            'quantity': int.tryParse(row[5]?.value?.toString() ?? '0') ?? 0,
            'status': (int.tryParse(row[5]?.value?.toString() ?? '0') ?? 0) > 0 ? 'inStock' : 'outOfStock',
          });
        }
      }

      if (items.isEmpty) throw 'Файл пуст или имеет неверный формат';

      await _repo.distributorStockUpload(items);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Успешно загружено: ${items.length} поз.'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetch();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAddProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddProductSheet(onAdded: _fetch),
    );
  }

  List<ProductData> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) {
      final q = _searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
             p.sku.toLowerCase().contains(q) ||
             p.brand.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandWhite,
      appBar: AppBar(
        backgroundColor: AppColors.brandBlack,
        title: const Text(
          'УПРАВЛЕНИЕ СКЛАДОМ',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddProductSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetch,
          ),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
              onPressed: _pickAndUploadExcel,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'ПОИСК ПО SKU ИЛИ НАЗВАНИЮ',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF171717)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: const OutlineInputBorder(borderSide: BorderSide.none),
                hintStyle: TextStyle(
                  color: const Color(0xFF171717).withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
                : _filteredProducts.isEmpty
                    ? const Center(child: Text('ТОВАРЫ НЕ НАЙДЕНЫ'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) => _ProductStockCard(
                          product: _filteredProducts[index],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ProductStockCard extends StatelessWidget {
  final ProductData product;
  const _ProductStockCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = product.quantity <= 0;
    final bool isLowStock = product.quantity > 0 && product.quantity < 10;
    final Color statusColor = (isOutOfStock || isLowStock) ? AppColors.brandRed : AppColors.brandBlack;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isOutOfStock ? const Color(0xFFF5F5F5) : Colors.white,
        border: Border.all(color: AppColors.brandBlack, width: 1),
      ),
      child: Opacity(
        opacity: isOutOfStock ? 0.7 : 1.0,
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
                      product.sku.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    '${product.price} ₽',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                product.name.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, height: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                '${product.brand.toUpperCase()} · ${product.volume} Л',
                style: const TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.w800, fontSize: 11),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.brandBlack),
                      const SizedBox(width: 8),
                      const Text('ОСТАТОК:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(
                        '${product.quantity} ШТ',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: statusColor),
                      ),
                    ],
                  ),
                  if (isOutOfStock)
                    const Text('НЕТ В НАЛИЧИИ', style: TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.w900, fontSize: 10))
                  else if (isLowStock)
                    const Text('МАЛО', style: TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.w900, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddProductSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const AddProductSheet({required this.onAdded});

  @override
  State<AddProductSheet> createState() => AddProductSheetState();
}

class AddProductSheetState extends State<AddProductSheet> {
  final _skuCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _catCtrl = TextEditingController(text: 'Общее');
  final _brandCtrl = TextEditingController(text: 'AutoTerra');
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() {
    _skuCtrl.dispose();
    _nameCtrl.dispose();
    _catCtrl.dispose();
    _brandCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_skuCtrl.text.isEmpty || _nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SKU и Название обязательны')));
      return;
    }

    setState(() => _saving = true);
    try {
      await DataRepository().addProduct({
        'sku': _skuCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'category': _catCtrl.text.trim(),
        'brand': _brandCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0,
        'quantity': int.tryParse(_qtyCtrl.text) ?? 0,
      });

      if (!mounted) return;
      widget.onAdded();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Товар добавлен'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('НОВЫЙ ТОВАР', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 20),
          TextField(controller: _skuCtrl, decoration: const InputDecoration(labelText: 'АРТИКУЛ (SKU) *')),
          const SizedBox(height: 12),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'НАЗВАНИЕ *')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _catCtrl, decoration: const InputDecoration(labelText: 'КАТЕГОРИЯ'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'БРЕНД'))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ЦЕНА (₽)'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ОСТАТОК (ШТ)'))),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
              child: _saving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('ДОБАВИТЬ ТОВАР', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
