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

  test('delete credit restores inventory and removes sale', () async {
    final dbHelper = DatabaseHelper();
    final productRepo = ProductRepositoryImpl(dbHelper);
    final saleRepo = SaleRepositoryImpl(dbHelper);

    final productId = await productRepo.insertProduct(const Product(
      name: 'Test Item',
      categoryId: 1,
      costPrice: 10.0,
      sellingPrice: 15.0,
      stockQuantity: 10,
    ));

    final saleId = await saleRepo.insertSale(Sale(
      totalAmount: 45.0,
      saleDate: DateTime.now(),
      paymentAmount: 0.0,
      paymentMethod: 'credit',
      transactionStatus: 'credit',
      dueDate: DateTime.now().add(const Duration(days: 7)),
    ));

    await saleRepo.insertSaleItem(SaleItem(
      saleId: saleId,
      productId: productId,
      quantity: 3,
      unitPrice: 15.0,
      subtotal: 45.0,
    ));

    final p0 = await productRepo.getProductById(productId);
    await productRepo.updateProduct(p0!.copyWith(stockQuantity: p0.stockQuantity - 3));

    final ok = await saleRepo.deleteSaleAndRestoreInventory(saleId);
    expect(ok, true);

    final p1 = await productRepo.getProductById(productId);
    expect(p1!.stockQuantity, 10);

    final sale = await saleRepo.getSaleById(saleId);
    expect(sale, isNull);
  });
}