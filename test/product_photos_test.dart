import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/screens/orders/order_screen.dart';
import 'package:autoterra/services/data_repository.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/core/theme.dart';
import 'package:autoterra/widgets/common/product_photo.dart';

class MockDataRepository extends Mock implements DataRepository {}

/// Ссылка, из которой Image грузит картинку (у миниатюр провайдер обёрнут
/// в ResizeImage ради экономии памяти).
String? _urlOf(Image image) {
  final provider = image.image;
  if (provider is ResizeImage) {
    final inner = provider.imageProvider;
    return inner is NetworkImage ? inner.url : null;
  }
  return provider is NetworkImage ? provider.url : null;
}

/// Фото товара в клиентском разделе «Ассортимент»: миниатюра в карточке и
/// полноэкранная галерея по нажатию. Ссылки приходят с бэкенда (до 15 шт.),
/// сами файлы нигде не хранятся.
void main() {
  const photos = [
    'https://cdn.example.com/1.webp',
    'https://cdn.example.com/2.webp',
    'https://cdn.example.com/3.webp',
  ];

  OrderConfigData buildConfig() => OrderConfigData(
        client: Client(
          id: '1', inn: '123', name: 'Test', category: ClientCategory.b,
          region: 'Msk', city: 'Msk', contact: 'Me', phone: '123',
          distributorId: '1', status: ClientStatus.active, createdAt: DateTime.now(),
        ),
        distributor: const Distributor(id: '1', name: 'D1', inn: '1', regions: [], phone: '1', email: '1'),
        stores: [
          StoreData(id: '1', name: 'Store 1', address: 'Addr', isActive: true, createdAt: DateTime.utc(2026)),
        ],
        categories: const ['C1'],
        brands: const ['B1'],
      );

  Paginated<ProductData> buildCatalog() => Paginated<ProductData>(
        items: [
          ProductData(
            id: 'p1', distributorId: '1', sku: 'SKU1', name: 'Лак с фото',
            category: 'C1', brand: 'B1', volume: 1.0, price: 100.0,
            images: photos,
            quantity: 10, status: StockStatus.inStock, updatedAt: DateTime.now(),
          ),
          ProductData(
            id: 'p2', distributorId: '1', sku: 'SKU2', name: 'Грунт без фото',
            category: 'C1', brand: 'B1', volume: 1.0, price: 100.0,
            quantity: 10, status: StockStatus.inStock, updatedAt: DateTime.now(),
          ),
        ],
        pageInfo: const PageInfo(
          page: 1, pageSize: 20, count: 2, totalPages: 1,
          hasNext: false, hasPrevious: false,
        ),
      );

  MockDataRepository buildRepo() {
    final repo = MockDataRepository();
    when(() => repo.orderConfig()).thenAnswer((_) async => buildConfig());
    when(() => repo.products(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          search: any(named: 'search'),
          category: any(named: 'category'),
          brand: any(named: 'brand'),
          inStockOnly: any(named: 'inStockOnly'),
        )).thenAnswer((_) async => buildCatalog());
    return repo;
  }

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

  testWidgets('Ассортимент показывает миниатюру фото и счётчик кадров', (tester) async {
    await tester.pumpWidget(wrap(OrderScreen(repository: buildRepo())));
    await tester.pumpAndSettle();

    // У товара с фото — миниатюра с первой ссылкой.
    final thumbs = tester.widgetList<ProductThumb>(find.byType(ProductThumb)).toList();
    final withPhoto = thumbs.firstWhere((t) => t.images.isNotEmpty);
    expect(withPhoto.images, photos);

    // В карточке отрисован сетевой Image с первой ссылкой товара.
    // Миниатюра декодируется под свой размер, поэтому провайдер обёрнут в ResizeImage.
    expect(tester.widgetList<Image>(find.byType(Image)).map(_urlOf), contains(photos.first));

    // Счётчик «сколько всего фото» — подсказка, что есть галерея.
    expect(find.text('${photos.length}'), findsWidgets);

    // У товара без фото — заглушка вместо картинки.
    expect(thumbs.any((t) => t.images.isEmpty), isTrue);
    expect(find.byIcon(Icons.photo_outlined), findsWidgets);
  });

  testWidgets('Нажатие на фото открывает галерею со всеми кадрами', (tester) async {
    await tester.pumpWidget(wrap(OrderScreen(repository: buildRepo())));
    await tester.pumpAndSettle();

    final thumb = find.byWidgetPredicate(
      (w) => w is ProductThumb && w.images.isNotEmpty && w.size == 64,
    );
    await tester.tap(thumb.first);
    await tester.pumpAndSettle();

    // Заголовок галереи и счётчик текущего кадра.
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('ЛАК С ФОТО')), findsOneWidget);
    expect(find.text('1 / ${photos.length}'), findsOneWidget);

    // В галерее — все кадры товара.
    final galleryUrls = tester
        .widgetList<Image>(find.descendant(of: find.byType(PageView), matching: find.byType(Image)))
        .map(_urlOf)
        .toSet();
    expect(galleryUrls, contains(photos.first));

    // Свайп к следующему кадру.
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / ${photos.length}'), findsOneWidget);
  });

  testWidgets('Товар без фото не открывает галерею', (tester) async {
    await tester.pumpWidget(wrap(
      Scaffold(
        body: ProductThumb(
          images: const [],
          onTap: () => showProductGallery(
            tester.element(find.byType(Scaffold)),
            images: const [],
            title: 'Без фото',
          ),
        ),
      ),
    ));

    await tester.tap(find.byType(ProductThumb));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);
  });
}
