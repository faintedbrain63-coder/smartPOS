## Objectives
- Add Edit option alongside existing actions (Edit, Delete, Mark as Paid).
- Allow editing customer, items/quantities/prices, due date, and notes/reference (if schema supports it).
- Save applies instantly: database update in a single transaction, inventory adjusted by differences, UI reflects changes immediately without a full reload, analytics refresh only when values change.

## Data & Transaction Logic
- Implement `editCreditSale({required int saleId, required Sale updatedSale, required List<SaleItem> updatedItems})` in repository:
  1. Read current items: `SELECT * FROM sale_items WHERE sale_id=?` → `oldItems`.
  2. Compute per-product deltas: `delta = newQty - oldQty`; missing old→0; removed new→0.
  3. Inventory adjustments (guard against negative stock):
     - `delta > 0` → subtract `delta` from product stock (requires stock check).
     - `delta < 0` → add `abs(delta)` back to stock.
  4. Update `sales` row fields: `customerId/name`, `dueDate`, totals (recomputed from updated items), optional notes/reference if column exists.
  5. Replace `sale_items`: delete by `sale_id` then insert `updatedItems` (simpler and reliable for offline editing).
  6. Add `order_audit` entry: `action='edited'` with timestamp.
- Ensure full rollback on any failure.
- Add (or complete) `getSaleById(int id)` in repository impl to load the existing sale for editing.

## Provider Changes
- Add `SaleProvider.editCreditSale(int id, Sale updated, List<SaleItem> updatedItems)`:
  - Calls repository transaction.
  - Updates in-memory `_sales` list entry immediately (mutate the sale and items) and `notifyListeners()` so the Credit list updates without reload.
  - Conditional analytics refresh:
    - If `totalAmount`, `saleDate`, `dueDate`, or `customerId` changes impact aggregates → call `loadAnalytics()`.
    - Otherwise skip to avoid unnecessary recomputation.

## UI Changes (Credits)
- Add Edit option to popup menu in `lib/presentation/screens/credits/credits_screen.dart:148`.
- On select Edit:
  - Open a modal bottom sheet (inline builder in the same file to avoid new files) with fields:
    - Customer selector (dropdown/autocomplete) sourced from existing customer repository.
    - Line items editor: product picker, quantity, price, subtotal; add/remove rows.
    - Due date picker.
    - Notes/reference field only if schema has corresponding columns.
    - Footer showing recalculated total.
  - Validation: quantities > 0, prices ≥ 0, delta stock check (prevent negative stock).
  - Save:
    - Build `updatedSale` and `updatedItems`.
    - Call `SaleProvider.editCreditSale(...)`.
    - Close sheet; Credit list reflects new values immediately via provider state.
    - Show SnackBar success/error.

## Inventory & Totals Rules
- New item → subtract `newQty` from stock.
- Removed item → add `oldQty` to stock.
- Existing item → apply `delta`.
- Recompute `totalAmount` from item subtotals each save.

## Database Consistency
- Keep existing FK cascades; do not alter schema.
- If notes/reference columns exist, update them; otherwise omit from form and update payload.

## Testing
- Unit tests: verify inventory adjustments for add/remove/increase/decrease items.
- Integration test: edit a credit in the Credits screen, save, assert ledger updates and inventory reflects deltas.

## Files To Update
- `lib/domain/repositories/sale_repository.dart` (edit method signature; ensure `getSaleById` is implemented in impl).
- `lib/data/repositories/sale_repository_impl.dart` (transactional edit + deltas + guard + item replacement + audit).
- `lib/presentation/providers/sale_provider.dart` (edit method and conditional analytics refresh; in-memory sale update).
- `lib/presentation/screens/credits/credits_screen.dart` (add Edit action; implement modal sheet and save flow).

## Acceptance Criteria
- Editing a credit immediately updates the Credit list UI without a full reload.
- Database reflects changes instantly and atomically.
- Inventory adjusts by exact delta; negative stock prevented.
- Analytics recalc only when relevant values change.
- No duplicate calculations or double-updates; state remains consistent offline.