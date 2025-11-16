## Scope & Goals
- Add Edit option in Credits actions (Edit, Delete, Mark as Paid).
- Edit fields: customer, items/quantities/prices, due date, notes/reference.
- On save: update DB atomically, adjust inventory deltas, refresh aggregates only if changed, and reflect UI immediately without a full reload.

## Data & Transaction Logic
- New repository method: `Future<bool> editCreditSale({required int saleId, required Sale updatedSale, required List<SaleItem> updatedItems})`.
- Steps in a single transaction:
  1. Read existing `sale_items` for `saleId` into `oldItems`.
  2. Compute per-product quantity delta: `delta = newQty - oldQty` (missing old → 0; removed new → 0).
  3. Apply inventory:
     - If `delta > 0`: `UPDATE products SET stock_quantity = stock_quantity - delta`.
     - If `delta < 0`: `UPDATE products SET stock_quantity = stock_quantity + abs(delta)`.
     - Guard: prevent negative stock; throw/abort transaction if violation.
  4. Update `sales` row: `customerId/name`, `totalAmount`, `saleDate` (if editable), `dueDate`, `notes/ref`.
  5. Replace items:
     - Option A (simpler): delete all `sale_items` for `saleId` and insert `updatedItems`.
     - Option B (diff-based upsert): update existing, insert new, delete removed (useful for very large lists).
  6. Optional: insert `order_audit` with `action='edited'` and diff summary.

## Providers & Aggregates
- Add `SaleProvider.editCreditSale(...)`:
  - Calls repository transaction.
  - Updates in-memory `sales` list entry immediately (mutate item, replace items) and `notifyListeners()`.
  - Conditional analytics refresh:
    - If `old.totalAmount != new.totalAmount` or `date/dueDate` affects grouping → call `loadAnalytics()`.
    - Else no reload; aggregates computed from in-memory data if supported.

## UI Changes (Credits)
- Add Edit option to ledger item `PopupMenuButton`.
- Edit form: use a modal bottom sheet or a dedicated screen (to avoid clutter) with:
  - Customer selector: dropdown/autocomplete; updates `customerId/name`.
  - Editable line items list: product picker, quantity, price, subtotal; add/remove rows.
  - Due date picker.
  - Notes/reference text field.
  - Footer: recalculated totals; Save/Cancel.
- On Save:
  - Validate (non-negative qty/prices, inventory availability for increases).
  - Call `SaleProvider.editCreditSale(...)`.
  - Close modal and reflect changes instantly via provider state.
  - Show SnackBar for success/error.

## Inventory Rules
- Credit increases quantities → additional stock reduction by delta.
- Credit decreases quantities → stock returned by delta.
- Removed items → return full old qty.
- New items → subtract new qty.
- No double-adjustment: compute deltas from existing DB state before modifying `sale_items`.

## Database Consistency
- Keep FK cascades intact; `credit_payments` unchanged.
- Update `sales.totalAmount` based on sum of `updatedItems`.
- Ensure transaction rollback on any failure (e.g., negative stock).

## Validation & UX
- Prevent saving if any `quantity <= 0` or if resulting stock would go negative.
- Display inline validation messages.
- Preserve keyboard-friendly editing (numeric pads for qty/price).

## Files To Update
- `lib/domain/repositories/sale_repository.dart` (add method signature).
- `lib/data/repositories/sale_repository_impl.dart` (transaction + deltas).
- `lib/presentation/providers/sale_provider.dart` (edit method, in-memory update + conditional analytics).
- `lib/presentation/screens/credits/credits_screen.dart` (add Edit action + open editor).
- `lib/presentation/screens/credits/edit_credit_sheet.dart` (new modal sheet with form) OR inline builder inside Credits screen.

## Testing
- Unit tests for inventory delta application: increase/decrease/remove/add items.
- Integration test: open Credits, edit a credit, save, assert UI updates and stock adjustments.

## Rollout & Safety
- Transactional edits avoid partial state.
- Conditional analytics refresh reduces unnecessary recomputation.
- Audit entries provide traceability of edits.

## Next Step
- Implement repository transaction and provider method first, then wire UI with a modal bottom sheet for editing, followed by tests to validate deltas and immediate UI updates.