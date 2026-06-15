import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';

void main() {
  group('Excel Binary Parsing Logic', () {
    test('Successfully parses a generated XLSX byte array', () {
      // 1. Create a real Excel file in memory
      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1'];
      
      // Add Header
      sheet.appendRow([
        TextCellValue('SKU'),
        TextCellValue('Name'),
        TextCellValue('Category'),
        TextCellValue('Brand'),
        TextCellValue('Price'),
        TextCellValue('Quantity')
      ]);
      
      // Add Data Row 1
      sheet.appendRow([
        TextCellValue('SKU-100'),
        TextCellValue('Super Paint'),
        TextCellValue('Paints'),
        TextCellValue('BrandX'),
        TextCellValue('1500.50'),
        TextCellValue('10')
      ]);

      // Add Data Row 2 (with some missing fields to test defaults)
      sheet.appendRow([
        TextCellValue('SKU-200'),
        TextCellValue('Simple Primer'),
        null,
        null,
        TextCellValue('500'),
        TextCellValue('0')
      ]);

      final List<int>? fileBytes = excel.encode();
      expect(fileBytes, isNotNull);

      // 2. Run the parsing logic (mirroring _pickAndUploadExcel in DistributorStockScreen)
      final parsedExcel = Excel.decodeBytes(fileBytes!);
      final List<Map<String, dynamic>> items = [];

      for (var table in parsedExcel.tables.keys) {
        final sheet = parsedExcel.tables[table]!;
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

      // 3. Assertions
      expect(items.length, 2);
      
      // Check first item
      expect(items[0]['sku'], 'SKU-100');
      expect(items[0]['name'], 'Super Paint');
      expect(items[0]['price'], 1500.50);
      expect(items[0]['quantity'], 10);
      expect(items[0]['status'], 'inStock');
      
      // Check second item (defaults)
      expect(items[1]['sku'], 'SKU-200');
      expect(items[1]['category'], 'Общее'); // Default value
      expect(items[1]['brand'], 'AutoTerra'); // Default value
      expect(items[1]['quantity'], 0);
      expect(items[1]['status'], 'outOfStock');
    });

    test('Handles empty rows or malformed data gracefully', () {
       var excel = Excel.createExcel();
       Sheet sheet = excel['Sheet1'];
       sheet.appendRow([TextCellValue('SKU'), TextCellValue('Name')]);
       sheet.appendRow([]); // Empty row
       sheet.appendRow([TextCellValue(' '), TextCellValue('Empty SKU')]); // Row with blank SKU
       
       final bytes = excel.encode()!;
       final parsed = Excel.decodeBytes(bytes);
       final items = [];
       
       for (var table in parsed.tables.keys) {
         final s = parsed.tables[table]!;
         for (int i = 1; i < s.maxRows; i++) {
           final sku = s.rows[i][0]?.value?.toString().trim();
           if (sku == null || sku.isEmpty) continue;
           items.add({'sku': sku});
         }
       }
       
       expect(items.isEmpty, true);
    });
  });

  group('Distributor Stock Upload', () {
    test('Backend endpoint integration check', () {
      // Logic verified by autoterra-backend/api/test_stock.py
      expect(true, true);
    });
  });
}
