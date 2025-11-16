# Credits Page Enhancement - Quick Testing Guide

## 🎯 Quick Overview
Test all new features: Tabs, Customer Name Filter, Total Amounts, and Credit Dates

---

## ✅ Test 1: Tabbed Layout (Unpaid vs Paid)

### Setup:
1. Create at least 3 credits (from checkout with "Credit" payment type)
2. Mark 1-2 credits as fully paid (Record Payment for full outstanding amount)

### Test Steps:
1. Open Credits Page
2. **Default Tab**: Verify you land on "Unpaid / Due" tab
3. **Check Unpaid Tab**: Should show only credits with outstanding > 0
4. **Switch to Paid Tab**: Tap on "Paid" tab
5. **Check Paid Tab**: Should show only credits with outstanding = 0 or status = "completed"

### Expected Results:
- ✅ Tabs switch instantly (no loading spinner)
- ✅ Unpaid tab shows only unpaid credits
- ✅ Paid tab shows only paid credits
- ✅ No credits appear in both tabs simultaneously

### Visual Checks:
- Unpaid tab has **orange** total amount card
- Paid tab has **green** total amount card
- Status chips: 🟠 "Due" or 🔴 "Overdue" for unpaid, 🟢 "Paid" for paid

---

## ✅ Test 2: Filter by Customer Name

### Setup:
1. Create credits for customers with diverse names:
   - "John Doe"
   - "Jane Smith"
   - "Johnny Walker"
   - "Michael Johnson"

### Test Steps (on Unpaid Tab):
1. Type "**John**" in the search bar
2. Check which credits appear → Should show "John Doe" and "Johnny Walker" only
3. Type "**Jane**" → Should show "Jane Smith" only
4. Type "**son**" → Should show "Michael Johnson" only (partial match)
5. Clear search (tap X button) → All unpaid credits should reappear

### Test Steps (on Paid Tab):
1. Mark "John Doe" credit as paid
2. Switch to Paid tab
3. Type "**John**" in search bar
4. Should show "John Doe" credit (now paid) only

### Expected Results:
- ✅ Search is **case-insensitive** ("john" = "John")
- ✅ Search supports **partial matching** ("son" matches "Johnson")
- ✅ Search works **independently per tab** (filters unpaid on Unpaid tab, filters paid on Paid tab)
- ✅ UI updates **instantly** as you type (no delay)
- ✅ Clear button (X) appears when text is entered

---

## ✅ Test 3: Show Total Amounts per Tab

### Test Steps:
1. **Unpaid Tab**:
   - Note the total displayed (e.g., "₱1,500.00")
   - Note the count (e.g., "3 credits")
   - Manually add up outstanding amounts → Should match displayed total

2. **Apply Customer Name Filter**:
   - Type "John" → Total should recalculate for visible credits only
   - Clear search → Total should revert to full amount

3. **Apply Date Range Filter**:
   - Set date range to filter out some credits
   - Total should recalculate for visible credits only

4. **Paid Tab**:
   - Switch to Paid tab
   - Note the total displayed (e.g., "₱800.00")
   - This should be sum of **total amounts** (not outstanding) for paid credits

5. **Mark as Paid**:
   - Go to Unpaid tab, mark one credit as paid
   - Note the total **decreases** on Unpaid tab
   - Switch to Paid tab → Total **increases** by the paid amount

### Expected Results:
- ✅ **Unpaid tab total** = Sum of outstanding amounts
- ✅ **Paid tab total** = Sum of total amounts (fully paid)
- ✅ Totals **recalculate dynamically** when:
  - Switching tabs
  - Applying customer name filter
  - Applying date range filter
  - After marking as paid / recording payment / deleting

---

## ✅ Test 4: Display Credit Dates

### Setup:
1. Create a credit today (e.g., Nov 16, 2025)
2. Set a due date (e.g., Nov 30, 2025)

### Test Steps (Unpaid Credit):
1. Open Credits Page → Unpaid tab
2. Find your newly created credit
3. Check for **Date Credited**: Should show "Nov 16, 2025" (or today's date)
4. Check for **Due Date**: Should show "Due: Nov 30, 2025" (in orange)
5. Verify **Date Paid is NOT shown** (since credit is unpaid)

### Test Steps (Mark as Paid):
1. Tap on the credit card → Opens details bottom sheet
2. Tap "Mark as Paid" → Confirm
3. Switch to **Paid tab**
4. Find the same credit
5. Check for **Date Credited**: Should still show "Nov 16, 2025"
6. Check for **Date Paid**: Should now show today's date (e.g., "Nov 16, 2025") with green check icon
7. Verify **Due Date is NOT shown** (since credit is paid)

### Expected Results:
- ✅ **Date Credited** is displayed for all credits (unpaid and paid)
- ✅ **Date Paid** is displayed only for paid credits
- ✅ Date format is clean: **MMM dd, yyyy** (e.g., "Nov 16, 2025")
- ✅ **Icons**:
  - 📅 Calendar icon for Date Credited
  - ✅ Green check icon for Date Paid
  - 🕒 Clock icon for Due Date
- ✅ **Colors**:
  - Date Credited: Primary color
  - Date Paid: Green
  - Due Date: Orange (due), Red (overdue)

---

## ✅ Test 5: Date Range Filter (Existing Feature)

### Setup:
1. Create credits on different dates:
   - Nov 1, 2025
   - Nov 10, 2025
   - Nov 20, 2025

### Test Steps:
1. Set **Start Date**: Nov 5, 2025
2. Set **End Date**: Nov 15, 2025
3. Check credits list → Only Nov 10 credit should appear
4. Clear dates (tap Clear button) → All credits should reappear
5. Set only **Start Date**: Nov 5 → Should show Nov 10 and Nov 20
6. Set only **End Date**: Nov 15 → Should show Nov 1 and Nov 10

### Expected Results:
- ✅ Date range filter works correctly
- ✅ Works in combination with tabs (filters within current tab only)
- ✅ Works in combination with customer name filter
- ✅ Total recalculates for filtered dates

---

## ✅ Test 6: Delete Credit (Existing Feature)

### Test Steps:
1. Note the total on Unpaid tab (e.g., ₱1,500)
2. Tap on a credit card → Opens details
3. Tap "Delete" button (red) → Confirmation dialog appears
4. Verify dialog text: "PERMANENTLY REMOVE", "Restore items to inventory", etc.
5. Tap "DELETE PERMANENTLY"
6. Credit should **disappear immediately** from the list
7. Total should **decrease** accordingly
8. Inventory should be **restored** (check Products page)

### Expected Results:
- ✅ Credit is **completely removed** from database
- ✅ Credit **disappears from UI immediately** (no manual refresh needed)
- ✅ Total **recalculates instantly**
- ✅ Inventory **restored** for credited items
- ✅ Notification **cancelled** for that credit
- ✅ Green success snackbar appears

---

## ✅ Test 7: Edit Credit (Existing Feature)

### Setup:
1. Create credit with:
   - Customer: "Test Customer"
   - Item: Product #1, Quantity: 2, Price: ₱100 → Total: ₱200
   - Due Date: Nov 30, 2025

### Test Steps:
1. Tap credit card → Details
2. Tap "Edit" button (orange)
3. Edit quantity from 2 to 5
4. Tap "Save"
5. Credit should update in list → Total now ₱500
6. Check inventory → Should decrease by 3 units (5 - 2)
7. Edit again: Change quantity from 5 to 1
8. Save → Total now ₱100
9. Check inventory → Should increase by 4 units (5 - 1)

### Expected Results:
- ✅ Quantity changes update total correctly
- ✅ Inventory adjusts based on quantity delta
- ✅ UI updates immediately after save
- ✅ Credit remains in correct tab (Unpaid if still outstanding)
- ✅ Notification reschedules if due date changed

---

## ✅ Test 8: Mark as Paid (Existing Feature)

### Test Steps:
1. On Unpaid tab, note total (e.g., ₱1,500)
2. Tap credit card → Details
3. Tap "Mark as Paid" button (green)
4. Verify confirmation dialog clearly states:
   - "mark the credit as fully paid"
   - "NOT the same as deleting"
   - "will not restore inventory"
5. Tap "Mark as Paid"
6. Credit should **disappear from Unpaid tab**
7. Switch to **Paid tab** → Credit should appear there
8. Check Date Paid → Should show today's date
9. Status chip should be green "Paid"

### Expected Results:
- ✅ Credit moves from Unpaid to Paid tab
- ✅ Status changes to "completed"
- ✅ Date Paid is recorded
- ✅ Outstanding becomes 0
- ✅ Notification cancelled
- ✅ Inventory **NOT restored** (this is mark as paid, not delete)

---

## ✅ Test 9: Record Payment (Existing Feature)

### Setup:
1. Create credit with total ₱300, initial payment ₱100 → Outstanding ₱200

### Test Steps:
1. Tap credit card → Details
2. Tap "Record Payment" button (blue)
3. Amount field pre-filled with ₱200 (outstanding)
4. Change to ₱100 (partial payment)
5. Tap "Save"
6. Credit should still appear in Unpaid tab
7. Outstanding should now be ₱100 (200 - 100)
8. Record another payment of ₱100
9. Outstanding should now be ₱0
10. Credit should **move to Paid tab**

### Expected Results:
- ✅ Partial payments work correctly
- ✅ Outstanding updates after each payment
- ✅ Credit moves to Paid tab when fully paid
- ✅ Date Paid shows date of final payment

---

## ✅ Test 10: Combined Filters

### Setup:
1. Create diverse credits:
   - **John Doe**, Nov 5, Unpaid, ₱200
   - **John Doe**, Nov 15, Paid, ₱300
   - **Jane Smith**, Nov 10, Unpaid, ₱150
   - **Michael**, Nov 20, Unpaid, ₱400

### Test Steps:
1. Go to **Unpaid tab**
2. Type "**John**" in search
3. Set date range: **Nov 1 - Nov 10**
4. Expected result: Only "John Doe, Nov 5, Unpaid, ₱200" appears
5. Total shows: ₱200 (1 credit)
6. Clear name filter → Should show "Jane Smith, Nov 10" as well (within date range)
7. Total shows: ₱350 (2 credits)
8. Switch to **Paid tab** (keeping date filter)
9. Type "**John**"
10. Expected result: "John Doe, Nov 15, Paid, ₱300" appears
11. Total shows: ₱300 (1 credit)

### Expected Results:
- ✅ All three filters work together seamlessly:
  - Tab selection (Unpaid vs Paid)
  - Customer name search
  - Date range filter
- ✅ Total recalculates correctly for visible credits
- ✅ No performance issues or lag

---

## ✅ Test 11: Overdue Credits

### Setup:
1. Create credit with due date in the past (e.g., Nov 1, 2025)
2. Keep it unpaid

### Test Steps:
1. Go to Unpaid tab
2. Find the credit with past due date
3. Check visual indicators:
   - Should have **red border** around card
   - Status chip should be **red** with "Overdue" label
   - Due date should be displayed in **red** color

### Expected Results:
- ✅ Overdue credits have red border
- ✅ Status chip says "Overdue" in red
- ✅ Due date text is red
- ✅ Still functions normally (can pay, edit, delete)

---

## ✅ Test 12: Empty States

### Test Steps:
1. Delete all unpaid credits (or create only paid credits)
2. Go to **Unpaid tab** → Should show:
   - Icon: ✅ (check circle outline)
   - Text: "No unpaid credits"
3. Delete all paid credits (or mark all as unpaid)
4. Go to **Paid tab** → Should show:
   - Icon: 💳 (credit card off)
   - Text: "No paid credits"

### Expected Results:
- ✅ Empty states display friendly messages
- ✅ Icons and text are centered and visible
- ✅ No errors or crashes

---

## ✅ Test 13: UI Responsiveness

### Test Steps:
1. Create 20+ credits
2. Test on different screen sizes (if possible):
   - Small phone screen
   - Large tablet screen
3. Test scrolling:
   - Should scroll smoothly
   - No lag or jank
4. Test search:
   - Should filter instantly as you type
   - No delay for large lists
5. Test tab switching:
   - Should switch instantly even with large lists

### Expected Results:
- ✅ UI is responsive and smooth
- ✅ No performance issues with large datasets
- ✅ All text is readable on all screen sizes
- ✅ Buttons and touch targets are easy to tap

---

## 🎨 Visual Design Checklist

- [ ] **Tabs**: Clear labels ("Unpaid / Due" and "Paid") with icons
- [ ] **Search Bar**: Prominent at top, with search icon and clear button
- [ ] **Date Filters**: Compact, side-by-side buttons with clear labels
- [ ] **Total Card**: Large, colored (orange/green), with count and amount
- [ ] **Credit Cards**: Clean design with customer name, dates, amounts, status chip
- [ ] **Status Chips**: Color-coded (orange/red/green) with icons
- [ ] **Overdue Indicator**: Red border around entire card
- [ ] **Action Buttons**: Color-coded (blue/green/orange/red) with clear labels
- [ ] **Date Icons**: Calendar, check, clock icons for different date types
- [ ] **Empty States**: Friendly icons and messages

---

## 🐛 Error Scenarios to Test

### Scenario 1: Delete Credit with No Inventory
1. Create credit with item
2. Manually delete the product from database (or set stock to 0)
3. Try to delete credit → Should handle gracefully (not crash)

### Scenario 2: Edit Credit with Invalid Quantity
1. Open edit dialog
2. Enter quantity = 0 or negative
3. Tap Save → Should show error message (not save)

### Scenario 3: Record Payment with Invalid Amount
1. Open Record Payment dialog
2. Enter amount = 0 or negative
3. Tap Save → Should not record (handle gracefully)

### Scenario 4: Network Issues (if applicable)
1. Turn off internet (if app uses online API)
2. Try to load credits → Should show cached data or friendly error

---

## ✅ Console Logs to Check

When performing actions, check Flutter console for logs:

### Delete Credit:
```
🗑️ DELETE CREDIT: Starting deletion for sale_id=123
🗑️ DELETE CREDIT: Found 2 items to restore
✅ DELETE CREDIT: Restored 3 units to Product #45 (was 10, now 13)
✅ DELETE CREDIT: Transaction committed successfully
```

### Edit Credit:
```
✏️ EDIT CREDIT: sale_id=123, old_qty=2, new_qty=5
✏️ EDIT CREDIT: Delta = +3 (subtract from inventory)
✅ EDIT CREDIT: Updated inventory for Product #45
✅ EDIT CREDIT: Transaction committed successfully
```

### Mark as Paid:
```
💰 Mark as Paid: sale_id=123
💰 Recording payment: amount=200.0
✅ Mark as Paid: Status changed to completed
```

---

## 📋 Final Checklist

- [ ] **Tab 1 (Unpaid)**: Shows only unpaid credits
- [ ] **Tab 2 (Paid)**: Shows only paid credits
- [ ] **Customer Name Filter**: Works with partial matching, case-insensitive
- [ ] **Date Range Filter**: Works correctly with both dates or single date
- [ ] **Total Amounts**: Recalculates dynamically with all filters
- [ ] **Date Credited**: Displayed for all credits in MMM dd, yyyy format
- [ ] **Date Paid**: Displayed only for paid credits with green check icon
- [ ] **Delete Credit**: Removes credit, restores inventory, updates UI instantly
- [ ] **Edit Credit**: Updates credit, adjusts inventory delta, updates UI instantly
- [ ] **Mark as Paid**: Moves to Paid tab, records Date Paid, cancels notification
- [ ] **Record Payment**: Updates outstanding, partial payments work, moves to Paid when complete
- [ ] **Overdue Credits**: Red border, red status chip, red due date text
- [ ] **Empty States**: Friendly messages when no credits in tab
- [ ] **UI Responsiveness**: Smooth scrolling, instant filtering, no lag
- [ ] **Combined Filters**: All three filters (tab + name + date) work together seamlessly

---

## 🎉 Success Criteria

All features are working correctly if:

1. ✅ You can switch between Unpaid and Paid tabs instantly
2. ✅ Searching for customer names filters the correct credits
3. ✅ Totals update dynamically with all filter changes
4. ✅ Date Credited is shown for all credits
5. ✅ Date Paid is shown only for paid credits
6. ✅ All existing features (delete, edit, mark as paid, record payment) still work
7. ✅ UI updates immediately after any action (no manual refresh)
8. ✅ No errors or crashes during any test

**If all checkboxes above are ticked, the Credits Page enhancement is successfully implemented!** 🚀

