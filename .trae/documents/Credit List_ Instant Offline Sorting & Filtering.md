## Objectives
- Add filtering (All, Unpaid, Paid, Overdue) and sorting (Date Created, Due Date, Amount) to the Credits list.
- Updates apply instantly in the UI without full refresh, work offline over the in-memory list.
- Overdue items remain highlighted visually.

## Current Data
- Ledger rows from `getCustomerLedger(customerId)` include: `sale_id`, `total_amount`, `payment_amount`, `due_date`, `sale_date`, `later_paid`, `outstanding`.
- Existing overdue highlighting: red when `due_date < today` and `outstanding > 0`.

## UI Controls
- Add controls at the top of the ledger bottom sheet:
  - Filter dropdown: `All`, `Unpaid`, `Paid`, `Overdue`.
  - Sort dropdown: `Date Created (Newest → Oldest)`, `Date Created (Oldest → Newest)`, `Due Date (Soonest → Latest)`, `Amount (Highest → Lowest)`, `Amount (Lowest → Highest)`.
- Use a `StatefulBuilder` inside the modal sheet to manage local state without affecting global providers.

## Filtering Logic
- `All`: return all rows.
- `Unpaid`: `outstanding > 0`.
- `Paid`: `outstanding <= 0`.
- `Overdue`: `outstanding > 0 && dueDate != null && dueDate.isBefore(today)`.

## Sorting Logic
- Date Created: sort by `sale_date` descending or ascending.
- Due Date: sort by `due_date` nulls last, ascending.
- Amount: sort by `total_amount` numeric descending/ascending.

## State & Reactivity
- Maintain two local variables in the sheet: `currentFilter`, `currentSort`.
- Compute `visibleLedger = applyFilter(ledger, currentFilter)`; then `visibleLedger = applySort(visibleLedger, currentSort)`.
- Call `setState` on change to update list immediately without re-fetching.

## Implementation Steps
1. In `CreditsScreen._showLedger`, wrap content in `StatefulBuilder` and add filter/sort dropdowns above the `ListView.builder`.
2. Implement helper functions within the builder closure to parse `due_date/sale_date` strings to `DateTime?` safely.
3. Apply filtering and sorting over the `ledger` list to produce `visibleLedger`.
4. Keep existing overdue color logic; it will continue to highlight red.

## Offline Guarantee
- Operate purely on the `ledger` list that was already fetched from the local database; no network calls.

## Testing
- Unit-style widget test: set `ledger` with mixed paid/unpaid/overdue entries; assert filter toggles update item count immediately.
- Manual: switch sort options and verify order changes without reloading.

## Acceptance Criteria
- Filter/sort controls visible at the top of the ledger sheet.
- Changing filter or sort updates the list instantly.
- All logic works offline using the existing ledger data.
- Overdue items show highlighted styling consistently.