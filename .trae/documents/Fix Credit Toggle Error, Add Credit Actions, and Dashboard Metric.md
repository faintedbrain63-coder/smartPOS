## Error Fix: Credit Mode Toggle
- Root cause: `DropdownButton` shows `value: 'credit'` when credit mode is enabled, but its items exclude `'credit'`, triggering an assertion.
- Evidence:
  - Sets `'credit'` in `setCreditMode` (lib/presentation/providers/checkout_provider.dart:166–172).
  - Dropdown items include `'cash'`, `'card'`, `'mobile'` only (lib/presentation/screens/checkout/checkout_screen.dart:579–617).
- Change:
  - Add a `DropdownMenuItem(value: 'credit', child: Text('Credit'))` to the items.
  - Disable changing method while credit mode is active: `onChanged: checkoutProvider.isCredit ? null : (value) { ... }`.

## Credits Page: Mark Paid & Delete
- Add actions per ledger entry in `CreditsScreen` (lib/presentation/screens/credits/credits_screen.dart):
  - Mark as Paid:
    - Compute outstanding via `getOutstandingForSale(saleId)`.
    - Call `insertCreditPayment(saleId, amount: outstanding, paidAt: now)` which auto-marks sale `completed` when outstanding reaches 0.
  - Delete Credit:
    - Call `deleteSale(saleId)`; `credit_payments` rows cascade-delete per schema.
  - UI: Add a popup menu or trailing action buttons next to “Record Payment”.

## Dashboard: Today’s Credit
- Add a new card under “Today’s Overview” (lib/presentation/screens/dashboard/dashboard_screen.dart) titled `Today's Credit` with icon `Icons.credit_card`.
- Provide the value from `SaleProvider.todayCreditAmount`, formatted with `CurrencyProvider`.
- Implement `todayCreditAmount` in `SaleProvider` (lib/presentation/providers/sale_provider.dart): sum of `sale.totalAmount` where `sale.transactionStatus == 'credit'` and `sale.saleDate` is today.

## Verification
- Build and run on the Android emulator.
- Steps:
  - Toggle to Credit mode: no dropdown assertion; method shows “Credit”.
  - Credits tab: open a customer ledger, use “Mark as Paid” to close a sale; confirm status updates to `Paid` and outstanding becomes 0.
  - Delete credit: confirm removal of a credit sale and its payments.
  - Dashboard: confirm `Today's Credit` shows the sum of credit sales created today.

## Notes
- No schema changes needed; uses existing `sales` and `credit_payments` tables.
- Follows existing Provider/Repository patterns, minimal edits across three files.
