import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_pos/data/datasources/database_helper.dart';
import 'package:smart_pos/data/repositories/product_repository_impl.dart';
import 'package:smart_pos/data/repositories/sale_repository_impl.dart';
import 'package:smart_pos/domain/entities/product.dart';
import 'package:smart_pos/domain/entities/sale.dart';
import 'package:smart_pos/domain/entities/sale_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('edit credit adjusts inventory by delta and updates totals', () async {
    final dbHelper = DatabaseHelper();
    final productRepo = ProductRepositoryImpl(dbHelper);
    final saleRepo = SaleRepositoryImpl(dbHelper);

    final productId = await productRepo.insertProduct(const Product(
      name: 'Delta Item', categoryId: 1, costPrice: 10.0, sellingPrice: 20.0, stockQuantity: 10,
    ));

    final saleId = await saleRepo.insertSale(Sale(
      totalAmount: 40.0,
      saleDate: DateTime.now(),
      customerName: 'Jane',
      paymentAmount: 0.0,
      paymentMethod: 'credit',
      transactionStatus: 'credit',
      dueDate: DateTime.now().add(const Duration(days: 2)),
    ));

    await saleRepo.insertSaleItem(SaleItem(
      saleId: saleId,
      productId: productId,
      quantity: 2,
      unitPrice: 20.0,
      subtotal: 40.0,
    ));

    // simulate stock deduction at sale time
    final p0 = await productRepo.getProductById(productId);
    await productRepo.updateProduct(p0!.copyWith(stockQuantity: p0.stockQuantity - 2));

    // edit: increase quantity to 5 (delta +3) => stock decreases by additional 3
    final updatedSale = (await saleRepo.getSaleById(saleId))!.copyWith(totalAmount: 100.0);
    final updatedItems = [
      const SaleItem(saleId: 0, productId: 0, quantity: 0, unitPrice: 0, subtotal: 0),
    ];
    final items = await saleRepo.getSaleItems(saleId);
    final newItems = [items.first.copyWith(quantity: 5, subtotal: 100.0)];

    final ok = await saleRepo.editCreditSale(saleId: saleId, updatedSale: updatedSale, updatedItems: newItems);
    expect(ok, true);

    final p1 = await productRepo.getProductById(productId);
    expect(p1!.stockQuantity, 5); // 10 - 2 - 3
    final s1 = await saleRepo.getSaleById(saleId);
    expect(s1!.totalAmount, 100.0);
  });
}