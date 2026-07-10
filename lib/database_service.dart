import 'models.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'taco_pos.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            category TEXT NOT NULL DEFAULT 'General'
          )
        ''');

        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_name TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'open',
            created_at TEXT NOT NULL,
            paid_at TEXT,
            amount_paid REAL,
            change REAL
          )
        ''');

        await db.execute('''
          CREATE TABLE order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            product_name TEXT NOT NULL,
            unit_price REAL NOT NULL,
            quantity INTEGER NOT NULL,
            notes TEXT,
            FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE extras (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            price REAL NOT NULL
          )
        ''');

        await _seedDefaultProducts(db);
        await _seedDefaultExtras(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE order_items ADD COLUMN notes TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS extras (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              price REAL NOT NULL
            )
          ''');
          final existing = await db.query('extras');
          if (existing.isEmpty) {
            await _seedDefaultExtras(db);
          }
        }
      },
    );
  }

  // Menú inicial de ejemplo. Se puede editar/agregar/eliminar productos
  // directamente desde la app (pantalla de Menú -> botón "+" y mantener
  // presionado un producto para eliminarlo).
  Future<void> _seedDefaultProducts(Database db) async {
    final defaults = [
      Product(name: 'Taco de pastor', price: 15, category: 'Tacos'),
      Product(name: 'Taco de asada', price: 18, category: 'Tacos'),
      Product(name: 'Taco de bistec', price: 18, category: 'Tacos'),
      Product(name: 'Taco de suadero', price: 16, category: 'Tacos'),
      Product(name: 'Quesadilla', price: 25, category: 'Tacos'),
      Product(name: 'Refresco', price: 20, category: 'Bebidas'),
      Product(name: 'Agua fresca', price: 18, category: 'Bebidas'),
    ];
    for (final p in defaults) {
      await db.insert('products', p.toMap()..remove('id'));
    }
  }

  // Extras de ejemplo (con costo adicional). Igual que los productos, se
  // pueden agregar, editar el precio, o eliminar desde la app.
  Future<void> _seedDefaultExtras(Database db) async {
    final defaults = [
      Extra(name: 'Con queso', price: 5),
      Extra(name: 'Con queso y harina', price: 8),
    ];
    for (final e in defaults) {
      await db.insert('extras', e.toMap()..remove('id'));
    }
  }

  // ---------------- EXTRAS (opciones con costo extra) ----------------

  Future<List<Extra>> getExtras() async {
    final db = await database;
    final rows = await db.query('extras', orderBy: 'name');
    return rows.map((r) => Extra.fromMap(r)).toList();
  }

  Future<int> insertExtra(Extra extra) async {
    final db = await database;
    return db.insert('extras', extra.toMap()..remove('id'));
  }

  Future<void> deleteExtra(int id) async {
    final db = await database;
    await db.delete('extras', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- PRODUCTS ----------------

  Future<List<Product>> getProducts() async {
    final db = await database;
    final rows = await db.query('products', orderBy: 'category, name');
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return db.insert('products', product.toMap()..remove('id'));
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  // ---------------- ORDERS ----------------

  Future<int> createOrder(Order order) async {
    final db = await database;
    return db.transaction((txn) async {
      final orderId = await txn.insert('orders', order.toMap()..remove('id'));
      for (final item in order.items) {
        await txn.insert('order_items', {
          'order_id': orderId,
          'product_id': item.productId,
          'product_name': item.productName,
          'unit_price': item.unitPrice,
          'quantity': item.quantity,
          'notes': item.notes,
        });
      }
      return orderId;
    });
  }

  Future<List<Order>> getOpenOrders() async {
    return _getOrdersByStatus('open');
  }

  Future<List<Order>> getPaidOrdersForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999).toIso8601String();

    final orderRows = await db.query(
      'orders',
      where: 'status = ? AND paid_at >= ? AND paid_at <= ?',
      whereArgs: ['paid', startOfDay, endOfDay],
      orderBy: 'paid_at DESC',
    );

    final orders = <Order>[];
    for (final row in orderRows) {
      final items = await _getItemsForOrder(row['id'] as int);
      orders.add(Order.fromMap(row, items));
    }
    return orders;
  }

  Future<List<Order>> _getOrdersByStatus(String status) async {
    final db = await database;
    final orderRows = await db.query(
      'orders',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at ASC',
    );

    final orders = <Order>[];
    for (final row in orderRows) {
      final items = await _getItemsForOrder(row['id'] as int);
      orders.add(Order.fromMap(row, items));
    }
    return orders;
  }

  Future<List<OrderItem>> _getItemsForOrder(int orderId) async {
    final db = await database;
    final rows = await db.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
    return rows.map((r) => OrderItem.fromMap(r)).toList();
  }

  Future<Order?> getOrderById(int orderId) async {
    final db = await database;
    final rows = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (rows.isEmpty) return null;
    final items = await _getItemsForOrder(orderId);
    return Order.fromMap(rows.first, items);
  }

  /// Agrega productos nuevos a una orden que ya está abierta (el cliente
  /// pidió más). Devuelve los OrderItem recién insertados (con su id), útil
  /// para imprimir un ticket solo con lo agregado.
  Future<List<OrderItem>> addItemsToOrder(int orderId, List<OrderItem> newItems) async {
    final db = await database;
    final inserted = <OrderItem>[];
    await db.transaction((txn) async {
      for (final item in newItems) {
        final id = await txn.insert('order_items', {
          'order_id': orderId,
          'product_id': item.productId,
          'product_name': item.productName,
          'unit_price': item.unitPrice,
          'quantity': item.quantity,
          'notes': item.notes,
        });
        inserted.add(OrderItem(
          id: id,
          orderId: orderId,
          productId: item.productId,
          productName: item.productName,
          unitPrice: item.unitPrice,
          quantity: item.quantity,
          notes: item.notes,
        ));
      }
    });
    return inserted;
  }

  Future<void> deleteOrderItem(int orderItemId) async {
    final db = await database;
    await db.delete('order_items', where: 'id = ?', whereArgs: [orderItemId]);
  }

  Future<void> markOrderAsPaid(int orderId, {required double amountPaid, required double change}) async {
    final db = await database;
    await db.update(
      'orders',
      {
        'status': 'paid',
        'paid_at': DateTime.now().toIso8601String(),
        'amount_paid': amountPaid,
        'change': change,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> deleteOrder(int orderId) async {
    final db = await database;
    await db.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
    await db.delete('orders', where: 'id = ?', whereArgs: [orderId]);
  }
}
