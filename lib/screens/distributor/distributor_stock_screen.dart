import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../core/theme.dart';

class DistributorStockScreen extends StatefulWidget {
  const DistributorStockScreen({super.key});

  @override
  State<DistributorStockScreen> createState() => _DistributorStockScreenState();
}

class _DistributorStockScreenState extends State<DistributorStockScreen> {
  final DataRepository _repo = DataRepository();
  late final PaginationController<ProductData> _controller;
  bool _isUploading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Поиск выполняется на сервере: при пагинации фильтровать загруженную
    // страницу на клиенте нельзя — совпадения с других страниц потерялись бы.
    _controller = PaginationController<ProductData>(
      fetchPage: (page) => _repo.distributorStock(
        page: page,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetch() => _controller.refresh();

  void _onSearchChanged(String value) {
    _searchQuery = value;
    _controller.refreshDebounced();
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

      // Парсинг выполняется на сервере: поддерживается шаблон WB
      // «Общие характеристики» (многострочная шапка, колонки по названию,
      // фото/габариты/баркод и т.д.). Отправляем сырой файл.
      final res = await _repo.distributorStockUploadFile(bytes, file.name);

      final created = res['created'] ?? 0;
      final updated = res['updated'] ?? 0;
      final errors = (res['errors'] as List?) ?? const [];

      if (mounted) {
        final summary = 'Загружено: +$created новых, $updated обновлено'
            '${errors.isNotEmpty ? ' · предупреждений: ${errors.length}' : ''}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(summary),
            backgroundColor: errors.isEmpty ? AppColors.success : AppColors.warning,
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
              onChanged: _onSearchChanged,
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
            child: PaginatedListView<ProductData>(
              controller: _controller,
              emptyMessage: 'ТОВАРЫ НЕ НАЙДЕНЫ',
              itemBuilder: (context, product, _) =>
                  _ProductStockCard(product: product),
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
