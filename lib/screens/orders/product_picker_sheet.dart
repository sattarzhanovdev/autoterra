import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/product_photo.dart';

/// Выбор товара со склада дистрибьютора — оператор добавляет позицию в заказ
/// (например, замену тому, что закончилось).
///
/// Каталог грузится страницами с серверным поиском: у дистрибьютора могут быть
/// сотни позиций, выкачивать их целиком ради одного выбора незачем.
Future<ProductData?> showProductPickerSheet(BuildContext context) {
  return showModalBottomSheet<ProductData>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ProductPickerSheet(),
  );
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _repo = DataRepository();
  final _searchController = TextEditingController();
  final _fmt = NumberFormat('#,##0', 'ru_RU');

  late final PaginationController<ProductData> _controller;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<ProductData>(
      fetchPage: (page) => _repo.distributorStock(
        page: page,
        search: _search.isEmpty ? null : _search,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _search = value.trim();
    // Дебаунс: не дёргаем сервер на каждую букву.
    _controller.refreshDebounced();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          color: AppColors.canvas,
          child: Column(
            children: [
              Container(
                color: AppColors.brandBlack,
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ДОБАВИТЬ ТОВАР',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию, артикулу, бренду',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                  ),
                ),
              ),
              Expanded(
                child: PaginatedListView<ProductData>(
                  controller: _controller,
                  scrollController: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  emptyMessage: 'ТОВАРЫ НЕ НАЙДЕНЫ',
                  itemBuilder: (context, product, _) => _ProductRow(
                    product: product,
                    fmt: _fmt,
                    onTap: () => Navigator.of(context).pop(product),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductRow extends StatelessWidget {
  final ProductData product;
  final NumberFormat fmt;
  final VoidCallback onTap;

  const _ProductRow({required this.product, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Нулевой остаток не блокируем: товар может быть «под заказ», и решение
    // остаётся за оператором — сервер всё равно проверит наличие.
    final isOut = product.quantity == 0 && product.status != StockStatus.onOrder;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: Row(
          children: [
            ProductThumb(
              images: product.images,
              size: 48,
              onTap: () => showProductGallery(
                context,
                images: product.images,
                title: product.name,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.sku} · ${product.brand}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.status == StockStatus.onOrder
                        ? 'ПОД ЗАКАЗ'
                        : 'В НАЛИЧИИ: ${product.quantity}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isOut ? AppColors.brandRed : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${fmt.format(product.price)} ₽',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.add_circle_outline, size: 20, color: AppColors.brandRed),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
