import 'models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'database_service.dart';
import 'printer_service.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _db = DatabaseService.instance;
  final _currencyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  List<Product> _products = [];
  final Map<int, OrderItem> _cart = {}; // productId -> OrderItem
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _db.getProducts();
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  double get _cartTotal => _cart.values.fold(0.0, (sum, item) => sum + item.subtotal);
  int get _cartCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);

  void _addToCart(Product product) {
    setState(() {
      if (_cart.containsKey(product.id)) {
        _cart[product.id!]!.quantity++;
      } else {
        _cart[product.id!] = OrderItem(
          productId: product.id!,
          productName: product.name,
          unitPrice: product.price,
          quantity: 1,
        );
      }
    });
  }

  void _removeFromCart(int productId) {
    setState(() {
      final item = _cart[productId];
      if (item == null) return;
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        _cart.remove(productId);
      }
    });
  }

  Future<void> _addNewProduct() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final categoryController = TextEditingController(text: 'General');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              autofocus: true,
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Precio'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (saved == true) {
      final name = nameController.text.trim();
      final price = double.tryParse(priceController.text.replaceAll(',', '.'));
      if (name.isEmpty || price == null) return;
      await _db.insertProduct(Product(
        name: name,
        price: price,
        category: categoryController.text.trim().isEmpty ? 'General' : categoryController.text.trim(),
      ));
      _loadProducts();
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${product.name}" del menú?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true && product.id != null) {
      await _db.deleteProduct(product.id!);
      _loadProducts();
    }
  }

  Future<void> _sendToKitchen() async {
    if (_cart.isEmpty) return;

    final nameController = TextEditingController();
    final customerName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre del cliente'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej. Juan'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Enviar a cocina'),
          ),
        ],
      ),
    );

    if (customerName == null || customerName.isEmpty) return;

    final order = Order(customerName: customerName, items: _cart.values.toList());
    final orderId = await _db.createOrder(order);

    if (!mounted) return;

    // Intenta imprimir el ticket
    final printed = await PrinterService.instance.printOrderTicket(order, orderNumber: orderId);

    setState(() => _cart.clear());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(printed
            ? 'Orden #$orderId enviada a cocina e impresa ✅'
            : 'Orden #$orderId guardada, pero no se pudo imprimir. Revisa la impresora en ⚙️.'),
        backgroundColor: printed ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final categories = _products.map((p) => p.category).toSet().toList();

    return Scaffold(
      body: _products.isEmpty
          ? const Center(child: Text('No hay productos en el menú. Agrega uno con el botón +.'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                for (final category in categories) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      category,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  ..._products.where((p) => p.category == category).map((product) {
                    final inCart = _cart[product.id];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Card(
                        child: ListTile(
                          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            _currencyFmt.format(product.price),
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                          ),
                          onLongPress: () => _deleteProduct(product),
                          trailing: inCart == null
                              ? IconButton.filled(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => _addToCart(product),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () => _removeFromCart(product.id!),
                                    ),
                                    Text('${inCart.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle),
                                      onPressed: () => _addToCart(product),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewProduct,
        tooltip: 'Agregar producto al menú',
        child: const Icon(Icons.add),
      ),
      bottomSheet: _cart.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$_cartCount productos · ${_currencyFmt.format(_cartTotal)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _sendToKitchen,
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar a cocina'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
