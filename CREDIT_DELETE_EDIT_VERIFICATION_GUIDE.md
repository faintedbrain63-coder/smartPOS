# Credit Delete & Edit - Verification Guide

## Overview
This guide provides step-by-step instructions to verify that the Delete Credit and Edit Credit features work correctly as per requirements.

---

## PROBLEM 1 — DELETE CREDIT VERIFICATION

### Correct Behavior
When deleting a credit:
1. ✅ Credit record is completely removed from database
2. ✅ Credit disappears from UI immediately (no refresh needed)
3. ✅ Product quantities are returned to inventory
4. ✅ All totals are recalculated (Today's Sales, Today's Credits, Dashboard)
5. ✅ Scheduled notification is cancelled
6. ✅ The deletion behaves as if the credit never existed

### Test Steps

#### Test 1.1: Basic Delete Credit
1. **Create a credit sale**
   - Go to POS/Checkout
   - Add Product A (quantity: 3, price: ₱100)
   - Switch to Credit mode
   - Enter customer name: "Test Customer"
   - Set due date: Tomorrow
   - Complete sale
   - **Note:** Initial inventory of Product A before sale

2. **Verify credit was created**
   - Go to Credits screen
   - Find "Test Customer" in list
   - Tap to view ledger
   - Confirm credit appears with:
     - Total: ₱300
     - Status: Due (orange)
     - Outstanding: ₱300

3. **Check inventory was reduced**
   - Go to Products screen
   - Find Product A
   - **Verify:** Stock reduced by 3

4. **Delete the credit**
   - In Credits screen → Customer ledger
   - Tap ⋮ menu on the credit
   - Select "Delete Credit"
   - Read confirmation dialog
   - Tap "Delete"

5. **Verify deletion**
   - ✅ Credit disappears from ledger immediately
   - ✅ If customer has no other credits, they disappear from customer list
   - ✅ Success message appears: "✓ Credit deleted successfully. Inventory restored."

6. **Check inventory was restored**
   - Go to Products screen
   - Find Product A
   - ✅ **Verify:** Stock is back to original amount (increased by 3)

7. **Check database**
   - Go to Credits screen
   - Search for "Test Customer"
   - ✅ **Verify:** Customer no longer appears (or has outstanding: ₱0)

8. **Check Dashboard**
   - Go to Dashboard
   - ✅ **Verify:** Today's Sales decreased by ₱300
   - ✅ **Verify:** Today's Credits decreased by ₱300

#### Test 1.2: Delete Credit with Multiple Items
1. Create credit with:
   - Product A (qty: 2, price: ₱100)
   - Product B (qty: 5, price: ₱50)
   - Total: ₱450
   - Customer: "Multi Item Test"

2. Note inventory before delete:
   - Product A: X units
   - Product B: Y units

3. Delete the credit

4. **Verify:**
   - ✅ Credit removed from UI
   - ✅ Product A inventory: X + 2
   - ✅ Product B inventory: Y + 5
   - ✅ Dashboard totals decreased by ₱450

---

## PROBLEM 2 — EDIT CREDIT VERIFICATION

### Correct Behavior
When editing a credit:
1. ✅ Changes are saved to database
2. ✅ Inventory adjusts based on quantity delta
3. ✅ UI updates immediately
4. ✅ Analytics and dashboard totals recalculate
5. ✅ If due date changed, notification is rescheduled

### Test Steps

#### Test 2.1: Increase Credit Quantity
1. **Create a credit sale**
   - Product: iPhone 15 Pro
   - Quantity: 2
   - Unit Price: ₱999
   - Total: ₱1,998
   - Customer: "Quantity Test"
   - Note initial iPhone inventory: X units

2. **Edit credit — Increase quantity**
   - Go to Credits → Find customer → View ledger
   - Tap ⋮ → Select "Edit Credit"
   - Change quantity from 2 to 5
   - UI should show new total: ₱4,995
   - Tap "Save"

3. **Verify edit succeeded**
   - ✅ Success message: "✓ Credit updated successfully. Inventory adjusted."
   - ✅ Credit shows new total: ₱4,995
   - ✅ Outstanding updated accordingly

4. **Check inventory delta**
   - Go to Products → Find iPhone
   - ✅ **Verify:** Stock = X - 5 (decreased by additional 3)
   - **Console log should show:** Stock decreased by 3

5. **Check console output**
   ```
   ✏️ EDIT CREDIT: Old quantities: {<product_id>: 2}
   ✏️ EDIT CREDIT: New quantities: {<product_id>: 5}
   ✅ EDIT CREDIT: Stock decreased for "iPhone 15 Pro" ... (-3)
   🎉 EDIT CREDIT: Transaction completed successfully
   ```

#### Test 2.2: Decrease Credit Quantity
1. **Using same credit from Test 2.1**
   - Current quantity: 5
   - Current iPhone inventory: X - 5

2. **Edit credit — Decrease quantity**
   - Edit credit
   - Change quantity from 5 to 1
   - New total should show: ₱999
   - Tap "Save"

3. **Verify edit succeeded**
   - ✅ Credit updated to ₱999
   - ✅ Ledger reflects new amount

4. **Check inventory delta**
   - Go to Products → Find iPhone
   - ✅ **Verify:** Stock = X - 1 (returned 4 units to inventory)
   - **Console log should show:** Stock increased by 4

5. **Check console output**
   ```
   ✏️ EDIT CREDIT: Old quantities: {<product_id>: 5}
   ✏️ EDIT CREDIT: New quantities: {<product_id>: 1}
   ✅ EDIT CREDIT: Stock increased for "iPhone 15 Pro" ... (+4)
   🎉 EDIT CREDIT: Transaction completed successfully
   ```

#### Test 2.3: Edit Due Date
1. **Create a credit**
   - Product: Any
   - Quantity: 1
   - Due Date: Today + 3 days
   - Customer: "Date Test"

2. **Edit due date**
   - Edit credit
   - Change due date to Today + 7 days
   - Tap "Save"

3. **Verify notification rescheduled**
   - ✅ Success message appears
   - **Console should show:**
   ```
   📱 PROVIDER: Notification rescheduled for sale <id>
   ```

#### Test 2.4: Edit with Insufficient Stock
1. **Create a credit**
   - Product: Headphones (assume 10 in stock)
   - Quantity: 2
   - After sale, stock: 8

2. **Attempt to edit with insufficient stock**
   - Edit credit
   - Try to change quantity from 2 to 15 (needs 13 additional, but only 8 available)
   - Tap "Save"

3. **Verify validation**
   - ✅ Error message appears
   - ✅ Credit NOT updated
   - ✅ Inventory NOT changed
   - **Error:** "Insufficient stock for 'Headphones' - need 13 more, but only 8 available"

---

## Console Logging

### Delete Credit Expected Logs
```
🗑️ UI: User confirmed delete for sale <id>
🗑️ DELETE CREDIT: Starting deletion for sale_id=<id>
🗑️ DELETE CREDIT: Found <n> items to restore
✅ DELETE CREDIT: Inventory restored for "<product_name>" (ID: <id>): X → Y (+Z)
🗑️ DELETE CREDIT: Deleted <n> payment records
🗑️ DELETE CREDIT: Deleted <n> sale items
✅ DELETE CREDIT: Sale <id> deleted from database
✅ DELETE CREDIT: Audit entry created
🎉 DELETE CREDIT: Transaction completed successfully
📱 PROVIDER: Delete successful, refreshing state...
📱 PROVIDER: Notification cancelled for sale <id>
✅ PROVIDER: DeleteCredit completed
✅ UI: Delete successful, reloading ledger data from database
✅ UI: Ledger refreshed, credit removed from view
```

### Edit Credit Expected Logs
```
✏️ UI: User clicked Save for sale <id>
📱 PROVIDER: Initiating edit for credit sale <id>
✏️ EDIT CREDIT: Starting edit for sale_id=<id> with <n> items
✏️ EDIT CREDIT: Old quantities: {product_id: qty}
✏️ EDIT CREDIT: New quantities: {product_id: qty}
✏️ EDIT CREDIT: Processing <n> unique products for inventory adjustments
✅ EDIT CREDIT: Stock decreased/increased for "<product>" ... (±delta)
✏️ EDIT CREDIT: New total calculated: <amount>
✅ EDIT CREDIT: Sale record updated
✅ EDIT CREDIT: Inserted <n> new sale items
✅ EDIT CREDIT: Audit entry created
🎉 EDIT CREDIT: Transaction completed successfully
📱 PROVIDER: Edit successful, updating in-memory state...
📱 PROVIDER: Notification rescheduled for sale <id>
✅ PROVIDER: EditCredit completed
✅ UI: Edit successful, reloading ledger data from database
✅ UI: Ledger refreshed, credit updated in view
```

---

## Error Scenarios

### Scenario 1: Delete Non-Existent Credit
- **Expected:** Error message, no crash
- **Log:** `❌ DELETE CREDIT: Sale <id> does not exist`

### Scenario 2: Edit Non-Existent Credit  
- **Expected:** Error message, no crash
- **Log:** `❌ EDIT CREDIT: Sale <id> does not exist`

### Scenario 3: Edit with Invalid Quantity (0 or negative)
- **Expected:** Validation error before submission
- **Message:** "Invalid quantity for item N. Must be greater than 0."

### Scenario 4: Network/Database Error During Delete
- **Expected:** Error message, transaction rolled back
- **Log:** `❌ DELETE CREDIT FAILED for sale_id=<id>`
- **Verify:** Credit still exists, inventory NOT changed

---

## Critical Verification Checklist

### Delete Credit ✓
- [ ] Credit completely removed from database
- [ ] Credit disappears from UI immediately
- [ ] Inventory restored for all products
- [ ] Dashboard totals recalculated
- [ ] Analytics updated
- [ ] Notification cancelled
- [ ] No status change to "Paid" (this was the bug!)

### Edit Credit ✓
- [ ] Changes saved to database
- [ ] Quantity increase → inventory decreases
- [ ] Quantity decrease → inventory increases
- [ ] UI updates immediately without refresh
- [ ] Total amount recalculated correctly
- [ ] Due date changes → notification rescheduled
- [ ] Dashboard/analytics updated
- [ ] Insufficient stock validation works

---

## Regression Tests

### Test After Both Features Work
1. Create 3 credits for same customer
2. Delete credit #2
3. Verify credits #1 and #3 still exist
4. Edit credit #1
5. Verify credit #3 unaffected
6. Record payment on credit #3
7. Delete credit #1
8. Verify only credit #3 remains

---

## Database Verification (Optional)

If you have access to the database directly:

### After Delete
```sql
-- Should return 0 rows
SELECT * FROM sales WHERE id = <deleted_sale_id>;

-- Should return 0 rows
SELECT * FROM sale_items WHERE sale_id = <deleted_sale_id>;

-- Verify audit entry
SELECT * FROM order_audit WHERE sale_id = <deleted_sale_id> AND action = 'deleted';
```

### After Edit
```sql
-- Verify updated total
SELECT total_amount FROM sales WHERE id = <edited_sale_id>;

-- Verify updated items
SELECT product_id, quantity FROM sale_items WHERE sale_id = <edited_sale_id>;

-- Verify audit entry
SELECT * FROM order_audit WHERE sale_id = <edited_sale_id> AND action = 'updated';
```

---

## Success Criteria

✅ **Delete Credit works correctly when:**
- Credit is completely removed (not just status changed)
- Inventory is fully restored
- UI updates instantly
- All totals recalculate
- Notifications are cancelled

✅ **Edit Credit works correctly when:**
- Changes persist to database
- Inventory adjusts by exact delta
- UI updates instantly
- Validation prevents invalid edits
- Notifications are rescheduled when needed

---

## Troubleshooting

### Delete not working?
1. Check console for error logs starting with `❌ DELETE CREDIT`
2. Verify `deleteSaleAndRestoreInventory` is being called (not `deleteSale`)
3. Check if transaction is rolling back due to error

### Edit not working?
1. Check console for error logs starting with `❌ EDIT CREDIT`
2. Verify quantity validation passes
3. Check for insufficient stock errors
4. Verify transaction completes successfully

### UI not refreshing?
1. Verify `reloadLedgerData()` is called after delete/edit
2. Check `recompute()` is called after reload
3. Verify `setState()` or `notifyListeners()` is triggered

---

## Report Issues

If any test fails, please provide:
1. Test number (e.g., "Test 1.1 failed at step 5")
2. Expected behavior
3. Actual behavior
4. Console logs
5. Screenshots if UI issue

---

**Testing completed by:** _______________  
**Date:** _______________  
**All tests passed:** ☐ Yes ☐ No (see notes)

