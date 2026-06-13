import 'package:flutter/material.dart';
import '../../services/data_repository.dart';

class DistributorStockScreen extends StatefulWidget {
  const DistributorStockScreen({super.key});

  @override
  State<DistributorStockScreen> createState() => _DistributorStockScreenState();
}

class _DistributorStockScreenState extends State<DistributorStockScreen> {
  final DataRepository _repo = DataRepository();
  List<ProductData> _products = [];
  bool _isLoading = true;
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
      setState(() {
        _products = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  List<ProductData> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }
    return _products.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             p.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             p.brand.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'УПРАВЛЕНИЕ СКЛАДОМ',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetch,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
            onPressed: () {
              // TODO: Implement Excel upload
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Загрузка Excel в разработке')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
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
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF01D2C)))
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
    final bool lowStock = product.quantity < 10;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: Color(0xFF171717), width: 1),
          borderRadius: BorderRadius.zero,
        ),
      ),
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
                  color: const Color(0xFF171717),
                  child: Text(
                    product.sku.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
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
              style: const TextStyle(
                color: Color(0xFFF01D2C),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF171717)),
                    const SizedBox(width: 8),
                    const Text(
                      'ОСТАТОК:',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${product.quantity} ШТ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: lowStock ? const Color(0xFFF01D2C) : const Color(0xFF171717),
                      ),
                    ),
                  ],
                ),
                if (lowStock)
                  const Text(
                    'МАЛО',
                    style: TextStyle(
                      color: Color(0xFFF01D2C),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
