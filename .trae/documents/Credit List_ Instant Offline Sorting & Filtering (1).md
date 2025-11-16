## Objectives
- Add filtering (All, Unpaid, Paid, Overdue) and sorting (Date Created, Due Date, Amount) to the Credits list.
- Updates apply instantly in the UI without full refresh; work entirely offline over the local list.
- Overdue items are visually highlighted consistently.

## Current State
- Credits ledger is shown via a modal bottom sheet fed by `getCustomerLedger(customerId)` containing `sale_id`, `total_amount`, `payment_amount`, `due_date`, `sale_date`, `later_paid`, and `outstanding`.
- Overdue highlight is already based on `due_date` and `outstanding` using color.

## UI Controls
- Add two dropdowns at the top of the ledger sheet:
  - Filter: All, Unpaid, Paid, Overdue.
  - Sort: Date Created (Newest → Oldest), Date Created (Oldest → Newest), Due Date (Soonest → Latest), Amount (Highest → Lowest), Amount (Lowest → Highest).
- Place them inside the modal sheet header area above the list.

## Filtering Logic
- All: return all rows.
- Unpaid: `outstanding > 0`.
- Paid: `outstanding <= 0`.
- Overdue: `outstanding > 0 && dueDate != null && dueDate.isBefore(today)`.

## Sorting Logic
- Date Created: sort by `sale_date` descending or ascending.
- Due Date: sort by `due_date` ascending with nulls last.
- Amount: sort by `total_amount` descending or ascending.

## Reactive State
- Use `StatefulBuilder` inside the bottom sheet to keep local state:
  - `currentFilter` and `currentSort`.
  - `visibleLedger = applySort(applyFilter(ledger, currentFilter), currentSort)`.
  - Call `setState` on dropdown change to update immediately without a provider reload.

## Overdue Visuals
- Keep existing color logic and add an optional red border/icon for overdue.
- Ensure highlighting recomputes after filter/sort since it depends on `due_date` and `outstanding`.

## Implementation Steps
1. Update `CreditsScreen._showLedger` to wrap content in `StatefulBuilder`.
2. Add filter and sort dropdowns above `ListView.builder`.
3. Implement safe date parsing helpers for `sale_date`/`due_date` strings.
4. Apply filter and sort functions over the `ledger` list to produce `visibleLedger`.
5. Keep offline behavior by reusing the already-fetched `ledger` list; no extra DB queries.

## Testing
- Widget test: provide a mock `ledger` list with mixed paid/unpaid/overdue entries; assert item count/order changes immediately when toggling filter/sort.
- Manual emulator check: switch filters and sorts, confirm instant UI updates and overdue highlighting.

## Acceptance Criteria
- Filter/sort controls visible and responsive.
- Changing filter or sort updates the Credit list instantly.
- All logic works offline using local ledger data.
- Overdue items consistently highlighted.