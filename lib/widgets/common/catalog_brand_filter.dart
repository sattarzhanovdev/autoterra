import 'package:flutter/material.dart';

class _BrandSelection {
  final String? brand;
  const _BrandSelection(this.brand);
}

/// Fetch all catalog brands on every opening, independently of product pages
/// and the current category/search/stock filters.
class CatalogBrandFilter extends StatelessWidget {
  final String? selected;
  final Future<List<String>> Function() loadBrands;
  final ValueChanged<String?> onChanged;
  const CatalogBrandFilter({
    super.key,
    required this.selected,
    required this.loadBrands,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    key: const ValueKey('catalog-brand-filter'),
    onTap: () async {
      final result = await showModalBottomSheet<_BrandSelection>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.85,
          child: _BrandPicker(selected: selected, loadBrands: loadBrands),
        ),
      );
      if (context.mounted && result != null) onChanged(result.brand);
    },
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Бренд',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(selected ?? 'Все бренды')),
          const Icon(Icons.expand_more),
        ],
      ),
    ),
  );
}

class _BrandPicker extends StatefulWidget {
  final String? selected;
  final Future<List<String>> Function() loadBrands;
  const _BrandPicker({required this.selected, required this.loadBrands});

  @override
  State<_BrandPicker> createState() => _BrandPickerState();
}

class _BrandPickerState extends State<_BrandPicker> {
  late Future<List<String>> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = widget.loadBrands();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Бренды каталога',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Поиск бренда',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => _search = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Не удалось загрузить бренды каталога'),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _future = widget.loadBrands();
                            });
                          },
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  );
                }
                final all = <String, String>{};
                for (final raw in snapshot.data ?? <String>[]) {
                  final brand = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
                  if (brand.isNotEmpty) {
                    all.putIfAbsent(brand.toLowerCase(), () => brand);
                  }
                }
                final brands =
                    all.values
                        .where((brand) => brand.toLowerCase().contains(_search))
                        .toList()
                      ..sort(
                        (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                      );
                return ListView(
                  children: [
                    ListTile(
                      title: const Text('Все бренды'),
                      selected: widget.selected == null,
                      onTap: () =>
                          Navigator.pop(context, const _BrandSelection(null)),
                    ),
                    if (brands.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Бренды не найдены'),
                      ),
                    for (final brand in brands)
                      ListTile(
                        title: Text(brand),
                        selected: widget.selected == brand,
                        trailing: widget.selected == brand
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () =>
                            Navigator.pop(context, _BrandSelection(brand)),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
