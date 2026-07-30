import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/screens/orders/order_screen.dart';
import 'package:autoterra/services/data_repository.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/core/theme.dart';

class MockDataRepository extends Mock implements DataRepository {}

void main() {
  late MockDataRepository mockRepo;

  setUp(() {
    mockRepo = MockDataRepository();
  });

  Widget createTestWidget(DataRepository repo) {
    return MaterialApp(
      theme: AppTheme.light,
      home: OrderScreen(repository: repo),
    );
  }

  testWidgets('OrderScreen should obscure exact stock quantities and show status labels', (WidgetTester tester) async {
    // 1. Prepare Mock Data
    final mockConfig = OrderConfigData(
      client: Client(
        id: '1', inn: '123', name: 'Test', category: ClientCategory.b, 
        region: 'Msk', city: 'Msk', contact: 'Me', phone: '123', 
        distributorId: '1', status: ClientStatus.active, createdAt: DateTime.now()
      ),
      distributor: const Distributor(id: '1', name: 'D1', inn: '1', regions: [], phone: '1', email: '1'),
      stores: [
        StoreData(id: '1', name: 'Store 1', address: 'Addr', isActive: true, createdAt: DateTime.utc(2026))
      ],
      categories: const ['C1'],
      brands: const ['B1'],
    );

    // Ассортимент грузится постранично, отдельно от справочников формы.
    final catalog = Paginated<ProductData>(
      items: [
        ProductData(
          id: 'p1', distributorId: '1', sku: 'SKU1', name: 'Product In Stock',
          category: 'C1', brand: 'B1', volume: 1.0, price: 100.0,
          quantity: 10, status: StockStatus.inStock, updatedAt: DateTime.now()
        ),
        ProductData(
          id: 'p2', distributorId: '1', sku: 'SKU2', name: 'Product Low Stock',
          category: 'C1', brand: 'B1', volume: 1.0, price: 100.0,
          quantity: 3, status: StockStatus.low, updatedAt: DateTime.now()
        ),
      ],
      pageInfo: const PageInfo(
        page: 1, pageSize: 20, count: 2, totalPages: 1,
        hasNext: false, hasPrevious: false,
      ),
    );

    when(() => mockRepo.orderConfig()).thenAnswer((_) async => mockConfig);
    when(() => mockRepo.products(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          search: any(named: 'search'),
          category: any(named: 'category'),
          brand: any(named: 'brand'),
          inStockOnly: any(named: 'inStockOnly'),
        )).thenAnswer((_) async => catalog);

    // 2. Render UI
    await tester.pumpWidget(createTestWidget(mockRepo));
    await tester.pump(); // Start fetching
    await tester.pumpAndSettle(); // Finish loading

    // 3. Verify Privacy
    // Exact quantities (10 and 3) should NOT be present in the stock status area
    // (We check for text patterns like "10 шт" or "3 шт")
    expect(find.textContaining('10 шт'), findsNothing);
    expect(find.textContaining('3 шт'), findsNothing);
    expect(find.textContaining('10 шт.'), findsNothing);
    expect(find.textContaining('3 шт.'), findsNothing);

    // 4. Verify status labels
    expect(find.text('В НАЛИЧИИ'), findsOneWidget);
    expect(find.text('МАЛО'), findsOneWidget);
    
    // Ensure titles are visible to confirm we are on the right screen
    expect(find.text('PRODUCT IN STOCK'), findsOneWidget);
    expect(find.text('PRODUCT LOW STOCK'), findsOneWidget);
  });
}
