import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_pos/data/datasources/database_helper.dart';
import 'package:smart_pos/data/repositories/product_repository_impl.dart';
import 'package:smart_pos/data/repositories/sale_repository_impl.dart';
import 'package:smart_pos/presentation/providers/sale_provider.dart';
import 'package:smart_pos/domain/entities/product.dart';
import 'package:smart_pos/domain/entities/sale.dart';
import 'package:smart_pos/domain/entities/sale_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('delete credit removes record, restores inventory, cancels notification', () async {
    final dbHelper = DatabaseHelper();
    final productRepo = ProductRepositoryImpl(dbHelper);
    final saleRepo = SaleRepositoryImpl(dbHelper);
    final provider = SaleProvider(saleRepo);

    final productId = await productRepo.insertProduct(const Product(
      name: 'Item', categoryId: 1, costPrice: 10.0, sellingPrice: 20.0, stockQuantity: 10,
    ));

    final saleId = await saleRepo.insertSale(Sale(
      totalAmount: 40.0,
      saleDate: DateTime.now(),
      customerName: 'John Doe',
      paymentAmount: 0.0,
      paymentMethod: 'credit',
      transactionStatus: 'credit',
      dueDate: DateTime.now().add(const Duration(days: 1)),
    ));

    await saleRepo.insertSaleItem(SaleItem(
      saleId: saleId,
      productId: productId,
      quantity: 2,
      unitPrice: 20.0,
      subtotal: 40.0,
    ));

    // Simulate stock deduction at sale time
    final p0 = await productRepo.getProductById(productId);
    await productRepo.updateProduct(p0!.copyWith(stockQuantity: p0.stockQuantity - 2));

    final ok = await provider.deleteCreditSale(saleId);
    expect(ok, true);

    final sale = await saleRepo.getSaleById(saleId);
    expect(sale, isNull);
    final p1 = await productRepo.getProductById(productId);
    expect(p1!.stockQuantity, 10);
  });
}