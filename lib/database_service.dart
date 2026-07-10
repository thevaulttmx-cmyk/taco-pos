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
      version: 1,
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
            FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
          )
        ''');

        await _seedDefaultProducts(db);
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
