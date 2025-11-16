## Problem & Current Behavior
- Deleting a credit uses `deleteSale(id)` which only removes the row from `sales` (`lib/data/repositories/sale_repository_impl.dart:112–120`).
- `sale_items` are deleted via ON DELETE CASCADE, but product stocks are NOT restored.
- UI in `CreditsScreen` calls repository directly and does not refresh dashboard/analytics; the ledger modal closes without forcing a rebuild.

## Target Behavior
- Remove credit from the UI instantly.
- Restore inventory quantities for all items in the deleted sale.
- Recalculate and refresh: Today’s Sales, Today’s Credit, Total Credit, analytics.
- Clean database: delete sale + cascade payments/items.

## Repository Changes (Atomic Transaction)
- Add method in `SaleRepository`:
  - `Future<bool> deleteSaleAndRestoreInventory(int saleId)`.
- Implement in `SaleRepositoryImpl`:
  - Use a `db.transaction` to:
    1. Read `sale_items` for `saleId`.
    2. For each item: `UPDATE products SET stock_quantity = stock_quantity + quantity WHERE id = product_id`.
    3. `DELETE FROM sales WHERE id = ?` (cascades delete `sale_items` and `credit_payments`).
    4. Optionally insert `order_audit` with action `deleted`.
  - Return true/false.

## Provider Changes
- In `SaleProvider` add `Future<bool> deleteCreditSale(int id)` that:
  - Calls `_saleRepository.deleteSaleAndRestoreInventory(id)`.
  - On success: `await loadSales(); await loadAnalytics();` to refresh dashboard/analytics.
  - Returns status for UI feedback.
- `todayCreditAmount` already exists; recalculations use refreshed sales list.

## UI Changes (CreditsScreen)
- Replace direct repo call in `_deleteCredit` with provider flow:
  - `final saleProvider = context.read<SaleProvider>();`
  - `final ok = await saleProvider.deleteCreditSale(saleId);`
  - On success:
    - Close ledger modal (`Navigator.pop` if open).
    - Call `_load()` (reload customers) and `setState(() {})` to rebuild list and refresh FutureBuilders (customer summaries/outstanding).
  - Show a SnackBar based on result.
- The ledger item popup menu already exists; wire it to the new method.

## Database Consistency & Performance
- FK cascades already defined in `database_helper.dart` for `sale_items` and `credit_payments`.
- Transaction ensures inventory restoration and sale deletion happen atomically.

## Verification Steps
1. Create a credit sale with 2 items (e.g., quantities 1 and 3).
2. Observe Dashboard: Today’s Sales and Today’s Credit increment.
3. Delete the credit via Credits page popup:
   - UI ledger entry disappears.
   - Product stock increases by the deleted quantities.
   - Dashboard and analytics values decrease accordingly.
4. Reopen Credits page: outstanding totals reflect deletion.

## Files To Update
- `lib/domain/repositories/sale_repository.dart` (new method signature).
- `lib/data/repositories/sale_repository_impl.dart` (transactional implementation).
- `lib/presentation/providers/sale_provider.dart` (new delete method; refresh logic).
- `lib/presentation/screens/credits/credits_screen.dart` (use provider, refresh UI after deletion).

## Rollback Safety
- All changes are localized to repository/provider/UI; DB schema unchanged.
- Transaction guarantees no partial state if errors occur.
