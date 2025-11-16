import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:smart_pos/main.dart';
import 'package:smart_pos/data/datasources/database_helper.dart';
import 'package:smart_pos/data/repositories/customer_repository_impl.dart';
import 'package:smart_pos/data/repositories/product_repository_impl.dart';
import 'package:smart_pos/data/repositories/sale_repository_impl.dart';
import 'package:smart_pos/domain/entities/customer.dart';
import 'package:smart_pos/domain/entities/product.dart';
import 'package:smart_pos/domain/entities/sale.dart';
import 'package:smart_pos/domain/entities/sale_item.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Live delete credit updates UI and restores inventory', (tester) async {
    final db = DatabaseHelper();
    final customerRepo = CustomerRepositoryImpl(db);
    final productRepo = ProductRepositoryImpl(db);
    final saleRepo = SaleRepositoryImpl(db);

    final customerId = await customerRepo.insertCustomer(const Customer(name: 'Test Customer'));
    final productId = await productRepo.insertProduct(const Product(
      name: 'Credit Item',
      categoryId: 1,
      costPrice: 10.0,
      sellingPrice: 20.0,
      stockQuantity: 10,
    ));

    final saleId = await saleRepo.insertSale(Sale(
      totalAmount: 60.0,
      saleDate: DateTime.now(),
      customerName: 'Test Customer',
      customerId: customerId,
      paymentAmount: 0.0,
      paymentMethod: 'credit',
      transactionStatus: 'credit',
      dueDate: DateTime.now().add(const Duration(days: 7)),
    ));

    await saleRepo.insertSaleItem(SaleItem(
      saleId: saleId,
      productId: productId,
      quantity: 3,
      unitPrice: 20.0,
      subtotal: 60.0,
    ));

    // reduce product stock to reflect the credit sale
    final p0 = await productRepo.getProductById(productId);
    await productRepo.updateProduct(p0!.copyWith(stockQuantity: p0.stockQuantity - 3));

    // Launch app
    runApp(const SmartPOSApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Navigate to Credits tab
    final creditsTab = find.text('Credits');
    expect(creditsTab, findsOneWidget);
    await tester.tap(creditsTab);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Ensure Test Customer is visible
    expect(find.text('Test Customer'), findsWidgets);
    await tester.tap(find.text('Test Customer').first);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Ledger should show the sale row
    final saleTitle = find.text('Sale #$saleId');
    expect(saleTitle, findsOneWidget);

    // Open popup menu and select Delete Credit
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await tester.tap(find.text('Delete Credit'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Ledger should no longer show the sale
    expect(saleTitle, findsNothing);

    // Inventory restored
    final p1 = await productRepo.getProductById(productId);
    expect(p1!.stockQuantity, 10);
  });
}