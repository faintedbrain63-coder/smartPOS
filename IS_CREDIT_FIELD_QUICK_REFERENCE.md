# is_credit Field — Quick Reference Guide

## 🎯 **What Was Added**

A new `is_credit` boolean field to explicitly separate sales from credits at the database level.

---

## 📊 **Field Values**

| Value | Meaning | Appears In |
|-------|---------|------------|
| `is_credit = 0` (false) | Regular Sale | Sales Page only |
| `is_credit = 1` (true) | Credit Transaction | Credits Page only |

---

## 🗂️ **Database Schema**

```sql
CREATE TABLE sales (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  total_amount REAL NOT NULL,
  -- ... other fields ...
  is_credit INTEGER NOT NULL DEFAULT 0, -- NEW FIELD
  transaction_status TEXT DEFAULT 'completed',
  due_date TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Performance indexes
CREATE INDEX idx_sales_is_credit ON sales (is_credit);
CREATE INDEX idx_sales_is_credit_status ON sales (is_credit, transaction_status);
```

---

## 🔄 **How to Query**

### **Get All Regular Sales**
```dart
// Repository method
await db.query('sales', where: 'is_credit = ?', whereArgs: [0]);

// Flutter usage
final sales = await saleProvider.loadSales();
// Automatically filters by is_credit = 0
```

### **Get All Credits (Paid + Unpaid)**
```dart
// Repository method
await db.rawQuery('SELECT * FROM sales WHERE is_credit = 1');

// Flutter usage
final credits = await repo.getAllCreditsWithDetails(includeCompleted: true);
// Automatically filters by is_credit = 1
```

### **Get Unpaid Credits Only**
```dart
await db.rawQuery('''
  SELECT * FROM sales 
  WHERE is_credit = 1 AND transaction_status = 'credit'
''');
```

### **Get Paid Credits Only**
```dart
await db.rawQuery('''
  SELECT * FROM sales 
  WHERE is_credit = 1 AND transaction_status = 'completed'
''');
```

---

## 🆕 **Creating New Transactions**

### **Regular Sale**
```dart
final sale = Sale(
  totalAmount: 100.0,
  saleDate: DateTime.now(),
  paymentAmount: 100.0,
  paymentMethod: 'cash',
  transactionStatus: 'completed',
  isCredit: false, // ← Regular sale
);
```

### **Credit Sale**
```dart
final credit = Sale(
  totalAmount: 100.0,
  saleDate: DateTime.now(),
  paymentAmount: 20.0,
  paymentMethod: 'credit',
  transactionStatus: 'credit',
  dueDate: DateTime.now().add(Duration(days: 30)),
  customerName: 'John Doe',
  isCredit: true, // ← Credit transaction
);
```

---

## 🔄 **Migration (Existing Databases)**

When upgrading from v5 to v6:
1. All existing records default to `is_credit = 0`
2. Records with `transaction_status = 'credit'` OR `due_date IS NOT NULL` → Set to `is_credit = 1`
3. All data preserved, no records lost ✅

---

## ✅ **What's Fixed**

| Issue | Before | After |
|-------|--------|-------|
| Credits in Sales Page | ❌ Appeared | ✅ Never appear |
| Sales in Credits Page | ❌ Appeared | ✅ Never appear |
| Paid credits in Unpaid tab | ❌ Appeared | ✅ Only in Paid tab |
| Sales analytics | ❌ Included credits | ✅ Only regular sales |
| Credit analytics | ❌ Included sales | ✅ Only credits |

---

## 🧪 **Quick Test**

1. **Create a regular sale** (cash payment) → Should appear in Sales Page only
2. **Create a credit** (partial payment, due date) → Should appear in Credits Page (Unpaid) only
3. **Mark credit as paid** → Should move to Credits Page (Paid), never in Sales Page
4. **Check Dashboard analytics** → Sales total should NOT include credits

---

## 📁 **Files Modified**

| File | Change |
|------|--------|
| `lib/domain/entities/sale.dart` | Added `isCredit` field |
| `lib/data/models/sale_model.dart` | Parse/serialize `is_credit` |
| `lib/data/datasources/database_helper.dart` | Schema + migration |
| `lib/data/repositories/sale_repository_impl.dart` | Updated all queries |
| `lib/presentation/providers/checkout_provider.dart` | Set `isCredit` on creation |

---

## 🔍 **Common Queries**

### **Sales Page**
```sql
SELECT * FROM sales WHERE is_credit = 0 ORDER BY sale_date DESC;
```

### **Credits Page (Unpaid)**
```sql
SELECT * FROM sales 
WHERE is_credit = 1 AND transaction_status = 'credit' 
ORDER BY due_date ASC;
```

### **Credits Page (Paid)**
```sql
SELECT * FROM sales 
WHERE is_credit = 1 AND transaction_status = 'completed' 
ORDER BY sale_date DESC;
```

### **Today's Sales Total (Exclude Credits)**
```sql
SELECT SUM(total_amount) FROM sales 
WHERE is_credit = 0 AND DATE(sale_date) = DATE('now');
```

### **Today's Credits Total**
```sql
SELECT SUM(total_amount) FROM sales 
WHERE is_credit = 1 AND DATE(sale_date) = DATE('now');
```

---

## ⚠️ **Important Notes**

1. **Always set `isCredit` when creating Sale objects** — Defaults to `false` if not specified
2. **Use repository methods** — They handle filtering automatically
3. **Migration is automatic** — No manual intervention needed
4. **Indexes are optimized** — Queries remain fast

---

## 🎉 **Result**

✅ **Sales and Credits are now completely separated!**
✅ **Analytics are accurate!**
✅ **Filtering works perfectly!**
✅ **No breaking changes!**

---

## 📖 **Full Documentation**

See `IS_CREDIT_FIELD_IMPLEMENTATION.md` for comprehensive technical details.

