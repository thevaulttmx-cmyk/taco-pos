// Modelos de datos: Producto, Item de orden, y Orden.

class Product {
  final int? id;
  final String name;
  final double price;
  final String category;

  Product({
    this.id,
    required this.name,
    required this.price,
    this.category = 'General',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      category: map['category'] as String? ?? 'General',
    );
  }
}

class OrderItem {
  final int? id;
  final int? orderId;
  final int productId;
  final String productName;
  final double unitPrice;
  int quantity;

  OrderItem({
    this.id,
    this.orderId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.quantity = 1,
  });

  double get subtotal => unitPrice * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'quantity': quantity,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
    );
  }
}

enum OrderStatus { open, paid }

class Order {
  final int? id;
  final String customerName;
  final List<OrderItem> items;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final double? amountPaid;
  final double? change;

  Order({
    this.id,
    required this.customerName,
    required this.items,
    this.status = OrderStatus.open,
    DateTime? createdAt,
    this.paidAt,
    this.amountPaid,
    this.change,
  }) : createdAt = createdAt ?? DateTime.now();

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_name': customerName,
      'status': status == OrderStatus.open ? 'open' : 'paid',
      'created_at': createdAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'amount_paid': amountPaid,
      'change': change,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map, List<OrderItem> items) {
    return Order(
      id: map['id'] as int?,
      customerName: map['customer_name'] as String,
      items: items,
      status: map['status'] == 'paid' ? OrderStatus.paid : OrderStatus.open,
      createdAt: DateTime.parse(map['created_at'] as String),
      paidAt: map['paid_at'] != null ? DateTime.parse(map['paid_at'] as String) : null,
      amountPaid: map['amount_paid'] != null ? (map['amount_paid'] as num).toDouble() : null,
      change: map['change'] != null ? (map['change'] as num).toDouble() : null,
    );
  }
}
