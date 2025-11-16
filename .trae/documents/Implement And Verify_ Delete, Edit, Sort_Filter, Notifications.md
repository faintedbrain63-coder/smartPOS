## Why You Didn't See Changes
- The delete-credit backend was added, but UI features from the last three prompts (Edit Credit, Sort/Filter, Local Notifications) were not yet wired into the Credits UI and app settings, so the emulator appeared unchanged.
- I will implement all requested UI and system features, then run and verify on the emulator.

## Deliverables To Implement
- Delete Credit: Confirm wiring and visible UI feedback; verify inventory restoration and analytics refresh.
- Edit Credit: Add Edit option and an editor modal for customer/items/due date/notes with inventory delta updates and immediate UI refresh.
- Sort/Filter: Add instant offline filtering (All/Unpaid/Paid/Overdue) and sorting (Date, Due, Amount) in the ledger modal with reactive state.
- Notifications: Schedule local notifications for due dates, reschedule on edit, and cancel on mark paid/delete; add settings toggle.

## Step-by-Step Plan
1. Wire Delete Credit UI feedback:
   - Ensure `SaleProvider.deleteCreditSale` success shows SnackBar and the ledger removes the entry instantly.
   - Verify analytics refresh occurs from provider.
2. Implement Edit Credit:
   - Repository: Keep `editCreditSale` transactional update with inventory deltas.
   - Provider: Add `editCreditSale` to update in-memory sales and conditionally refresh analytics.
   - UI: Add `Edit` to popup menu; add bottom-sheet editor.
     - Customer selector, line items editor (add/remove, quantity, price), due date picker, notes/reference (if schema field exists).
     - Validate quantities/prices; prevent negative stock; compute totals.
     - Save → call provider; close modal; list updates instantly.
3. Add Sort/Filter (offline, instant):
   - In `_showLedger`, wrap content in `StatefulBuilder`.
   - Add dropdowns for Filter and Sort; apply `applyFilter` then `applySort` over the local ledger list; `setState` for instant updates.
   - Keep overdue highlight (red) based on `outstanding > 0` and `due_date < today`.
4. Add Local Notifications:
   - Dependencies: `flutter_local_notifications`, `timezone`.
   - Service: `NotificationService` singleton for `init`, `scheduleCreditDue`, `cancelForSale`, `rescheduleCreditDue` (IDs use `saleId`).
   - Provider hooks:
     - After credit create/edit → schedule/reschedule if enabled and due date in future.
     - After mark paid/delete → cancel.
   - Settings:
     - `NotificationProvider` with `shared_preferences` key `credit_notifications_enabled`.
     - Add a toggle tile in Settings screen.
   - Startup: If enabled, schedule for all unpaid future-due credits to recover after app restarts.
5. Verification:
   - Build and run in emulator.
   - Create a credit; edit quantities/due date; check inventory deltas, totals, and instant UI refresh.
   - Toggle filters/sorts; observe immediate changes.
   - Confirm due-date notification scheduling/rescheduling/cancellation in logs.

## Outcome
- Credits UI gains Edit, Delete, Mark Paid, Filter/Sort controls.
- Inventory and analytics adjust correctly, instantly reflecting changes.
- Local offline notifications remind store owners at due dates and align with edits and payments.

## Next
- Proceed to implement these changes and run the emulator to verify everything end-to-end.