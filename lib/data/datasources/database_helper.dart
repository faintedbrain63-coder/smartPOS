import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'smartpos.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        image_path TEXT,
        category_id INTEGER NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0.0,
        selling_price REAL NOT NULL DEFAULT 0.0,
        barcode TEXT UNIQUE,
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        description TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Create sales table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_amount REAL NOT NULL DEFAULT 0.0,
        customer_name TEXT,
        sale_date TEXT NOT NULL,
        payment_amount REAL DEFAULT 0.0,
        change_amount REAL DEFAULT 0.0,
        payment_method TEXT DEFAULT 'cash',
        transaction_status TEXT DEFAULT 'completed',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create sale_items table
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0.0,
        subtotal REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // Create order audit table
    await db.execute('''
      CREATE TABLE order_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        action TEXT NOT NULL CHECK (action IN ('created', 'updated', 'deleted', 'voided')),
        timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
        user_info TEXT,
        details TEXT,
        FOREIGN KEY (sale_id) REFERENCES sales (id)
      )
    ''');

    // Create owner_contacts table
    await db.execute('''
      CREATE TABLE owner_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_number TEXT NOT NULL UNIQUE,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create sms_logs table
    await db.execute('''
      CREATE TABLE sms_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id INTEGER,
        message_content TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        sent_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (contact_id) REFERENCES owner_contacts (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_products_category_id ON products (category_id)');
    await db.execute('CREATE INDEX idx_products_barcode ON products (barcode)');
    await db.execute('CREATE INDEX idx_products_name ON products (name)');
    await db.execute('CREATE INDEX idx_sale_items_sale_id ON sale_items (sale_id)');
    await db.execute('CREATE INDEX idx_sale_items_product_id ON sale_items (product_id)');
    await db.execute('CREATE INDEX idx_sales_date ON sales (sale_date)');
    await db.execute('CREATE INDEX idx_sales_transaction_status ON sales (transaction_status)');
    await db.execute('CREATE INDEX idx_sales_payment_method ON sales (payment_method)');
    await db.execute('CREATE INDEX idx_sales_date_status ON sales (sale_date, transaction_status)');
    await db.execute('CREATE INDEX idx_order_audit_sale_id ON order_audit (sale_id)');
    await db.execute('CREATE INDEX idx_order_audit_timestamp ON order_audit (timestamp DESC)');
    await db.execute('CREATE INDEX idx_order_audit_action ON order_audit (action)');
    await db.execute('CREATE INDEX idx_owner_contacts_contact_number ON owner_contacts (contact_number)');
    await db.execute('CREATE INDEX idx_owner_contacts_created_at ON owner_contacts (created_at DESC)');
    await db.execute('CREATE INDEX idx_sms_logs_contact_id ON sms_logs (contact_id)');
    await db.execute('CREATE INDEX idx_sms_logs_status ON sms_logs (status)');
    await db.execute('CREATE INDEX idx_sms_logs_sent_at ON sms_logs (sent_at DESC)');

    // Create triggers for updated_at timestamps
    await db.execute('''
      CREATE TRIGGER update_categories_timestamp 
      AFTER UPDATE ON categories
      BEGIN
        UPDATE categories SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
      END
    ''');

    await db.execute('''
      CREATE TRIGGER update_products_timestamp 
      AFTER UPDATE ON products
      BEGIN
        UPDATE products SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
      END
    ''');

    await db.execute('''
      CREATE TRIGGER update_owner_contacts_timestamp 
      AFTER UPDATE ON owner_contacts
      BEGIN
        UPDATE owner_contacts SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
      END
    ''');

    // Insert sample data
    await _insertSampleData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < newVersion) {
      // Add customer_name column to sales table if upgrading from version 1
      if (oldVersion == 1 && newVersion >= 2) {
        await db.execute('ALTER TABLE sales ADD COLUMN customer_name TEXT');
      }
      
      // Add enhanced checkout fields if upgrading from version 2
      if (oldVersion <= 2 && newVersion >= 3) {
        await db.execute('ALTER TABLE sales ADD COLUMN payment_amount REAL DEFAULT 0.0');
        await db.execute('ALTER TABLE sales ADD COLUMN change_amount REAL DEFAULT 0.0');
        await db.execute('ALTER TABLE sales ADD COLUMN payment_method TEXT DEFAULT \'cash\'');
        await db.execute('ALTER TABLE sales ADD COLUMN transaction_status TEXT DEFAULT \'completed\'');
        
        // Create order audit table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS order_audit (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL,
            action TEXT NOT NULL CHECK (action IN ('created', 'updated', 'deleted', 'voided')),
            timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
            user_info TEXT,
            details TEXT,
            FOREIGN KEY (sale_id) REFERENCES sales (id)
          )
        ''');
        
        // Create new indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_transaction_status ON sales (transaction_status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_payment_method ON sales (payment_method)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_date_status ON sales (sale_date, transaction_status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_order_audit_sale_id ON order_audit (sale_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_order_audit_timestamp ON order_audit (timestamp DESC)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_order_audit_action ON order_audit (action)');
        
        // Update existing sales records with default values
        await db.execute('''
          UPDATE sales 
          SET payment_amount = total_amount, 
              change_amount = 0.0, 
              payment_method = 'cash', 
              transaction_status = 'completed'
          WHERE payment_amount IS NULL OR payment_amount = 0.0
        ''');
        
        // Create audit entries for existing sales
        await db.execute('''
          INSERT INTO order_audit (sale_id, action, user_info, details)
          SELECT id, 'created', 'system_migration', 'Migrated from legacy system'
          FROM sales
        ''');
      }
      
      // Add SMS Sales Reports tables if upgrading from version 3
      if (oldVersion <= 3 && newVersion >= 4) {
        // Create owner_contacts table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS owner_contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            contact_number TEXT NOT NULL UNIQUE,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Create sms_logs table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sms_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            contact_id INTEGER,
            message_content TEXT NOT NULL,
            status TEXT DEFAULT 'pending',
            sent_at TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (contact_id) REFERENCES owner_contacts (id) ON DELETE CASCADE
          )
        ''');

        // Create indexes for SMS tables
        await db.execute('CREATE INDEX IF NOT EXISTS idx_owner_contacts_contact_number ON owner_contacts (contact_number)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_owner_contacts_created_at ON owner_contacts (created_at DESC)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_logs_contact_id ON sms_logs (contact_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_logs_status ON sms_logs (status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sms_logs_sent_at ON sms_logs (sent_at DESC)');

        // Create trigger for owner_contacts updated_at timestamp
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS update_owner_contacts_timestamp 
          AFTER UPDATE ON owner_contacts
          BEGIN
            UPDATE owner_contacts SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
          END
        ''');
      }
    }
  }

  Future<void> _insertSampleData(Database db) async {
    // Insert sample categories
    await db.insert('categories', {
      'name': 'Electronics',
      'description': 'Electronic devices and accessories',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await db.insert('categories', {
      'name': 'Clothing',
      'description': 'Apparel and fashion items',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await db.insert('categories', {
      'name': 'Food & Beverages',
      'description': 'Food items and drinks',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await db.insert('categories', {
      'name': 'Books',
      'description': 'Books and educational materials',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Insert sample products
    final now = DateTime.now().toIso8601String();
    
    await db.insert('products', {
      'name': 'iPhone 15 Pro',
      'category_id': 1,
      'cost_price': 800.0,
      'selling_price': 999.0,
      'barcode': '1234567890123',
      'stock_quantity': 25,
      'description': 'Latest iPhone with advanced features',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('products', {
      'name': 'Samsung Galaxy S24',
      'category_id': 1,
      'cost_price': 700.0,
      'selling_price': 899.0,
      'barcode': '1234567890124',
      'stock_quantity': 30,
      'description': 'Premium Android smartphone',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('products', {
      'name': 'Wireless Headphones',
      'category_id': 1,
      'cost_price': 80.0,
      'selling_price': 129.0,
      'barcode': '1234567890125',
      'stock_quantity': 50,
      'description': 'High-quality wireless headphones',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('products', {
      'name': 'Cotton T-Shirt',
      'category_id': 2,
      'cost_price': 8.0,
      'selling_price': 19.99,
      'barcode': '1234567890126',
      'stock_quantity': 100,
      'description': '100% cotton comfortable t-shirt',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('products', {
      'name': 'Jeans',
      'category_id': 2,
      'cost_price': 25.0,
      'selling_price': 49.99,
      'barcode': '1234567890127',
      'stock_quantity': 75,
      'description': 'Classic blue jeans',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('products', {
      'name': 'Coffee Beans',
      'category_id': 3,
      'cost_price': 6.0,
      'selling_price': 12.99,
      'barcode': '1234567890128',
      'stock_quantity': 200,
      'description': 'Premium arabica coffee beans',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('products', {
      'name': 'Energy Drink',
      'category_id': 3,
      'cost_price': 1.5,
      'selling_price': 2.99,
      'barcode': '1234567890129',
      'stock_quantity': 150,
      'description': 'Refreshing energy drink',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('products', {
      'name': 'Programming Book',
      'category_id': 4,
      'cost_price': 20.0,
      'selling_price': 39.99,
      'barcode': '1234567890130',
      'stock_quantity': 40,
      'description': 'Learn programming fundamentals',
      'created_at': now,
      'updated_at': now,
    });

    // Insert sample sales data for analytics
    final saleDate1 = DateTime.now().subtract(const Duration(days: 1));
    final saleDate2 = DateTime.now().subtract(const Duration(days: 2));
    final saleDate3 = DateTime.now().subtract(const Duration(days: 3));

    // Sale 1
    final saleId1 = await db.insert('sales', {
      'total_amount': 1128.0,
      'sale_date': saleDate1.toIso8601String(),
      'created_at': saleDate1.toIso8601String(),
    });

    await db.insert('sale_items', {
      'sale_id': saleId1,
      'product_id': 1, // iPhone
      'quantity': 1,
      'unit_price': 999.0,
      'subtotal': 999.0,
    });

    await db.insert('sale_items', {
      'sale_id': saleId1,
      'product_id': 3, // Headphones
      'quantity': 1,
      'unit_price': 129.0,
      'subtotal': 129.0,
    });

    // Sale 2
    final saleId2 = await db.insert('sales', {
      'total_amount': 69.98,
      'sale_date': saleDate2.toIso8601String(),
      'created_at': saleDate2.toIso8601String(),
    });

    await db.insert('sale_items', {
      'sale_id': saleId2,
      'product_id': 4, // T-Shirt
      'quantity': 2,
      'unit_price': 19.99,
      'subtotal': 39.98,
    });

    await db.insert('sale_items', {
      'sale_id': saleId2,
      'product_id': 7, // Energy Drink
      'quantity': 10,
      'unit_price': 2.99,
      'subtotal': 29.90,
    });

    // Sale 3
    final saleId3 = await db.insert('sales', {
      'total_amount': 949.0,
      'sale_date': saleDate3.toIso8601String(),
      'created_at': saleDate3.toIso8601String(),
    });

    await db.insert('sale_items', {
      'sale_id': saleId3,
      'product_id': 2, // Samsung Galaxy
      'quantity': 1,
      'unit_price': 899.0,
      'subtotal': 899.0,
    });

    await db.insert('sale_items', {
      'sale_id': saleId3,
      'product_id': 5, // Jeans
      'quantity': 1,
      'unit_price': 49.99,
      'subtotal': 49.99,
    });
  }

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'smartpos.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}