import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_service.dart';
import 'printer_service.dart';
import 'item_notes_dialog.dart';

class EditOrderScreen extends StatefulWidget {
  final Order order;
  const EditOrderScreen({super.key, required this.order});

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  final _db = DatabaseService.instance;
  final _currencyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  List<Product> _products = [];
  final List<OrderItem> _newItems = [];
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

  double get _newTotal => _newItems.fold(0.0, (sum, item) => sum + item.subtotal);

  OrderItem? _plainLineFor(int productId) {
    for (final item in _newItems) {
      if (item.productId == productId && (item.notes == null || item.notes!.isEmpty)) {
        return item;
      }
    }
    return null;
  }

  void _addPlain(Product product) {
    setState(() {
      final existing = _plainLineFor(product.id!);
      if (existing != null) {
        existing.quantity++;
      } else {
        _newItems.add(OrderItem(
          productId: product.id!,
          productName: product.name,
          unitPrice: product.price,
          quantity: 1,
        ));
      }
    });
  }

  void _removePlain(Product product) {
    setState(() {
      final existing = _plainLineFor(product.id!);
      if (existing == null) return;
      if (existing.quantity > 1) {
        existing.quantity--;
      } else {
        _newItems.remove(existing);
      }
    });
  }

  Future<void> _customizeAndAdd(Product product) async {
    final result = await showItemNotesDialog(context, productName: product.name);
    if (result == null) return;
    setState(() {
      _newItems.add(OrderItem(
        productId: product.id!,
        productName: product.name,
        unitPrice: product.price + result.extraPrice,
        quantity: 1,
        notes: result.notes.isEmpty ? null : result.notes,
      ));
    });
  }

  Future<void> _saveAndPrint() async {
    if (_newItems.isEmpty) return;

    final inserted = await _db.addItemsToOrder(widget.order.id!, _newItems);

    if (!mounted) return;

    final printed = await PrinterService.instance.printAddendumTicket(
      widget.order.customerName,
      inserted,
      orderNumber: widget.order.id!,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(printed
            ? 'Agregado enviado a cocina e impreso ✅'
            : 'Se guardó, pero no se pudo imprimir el ticket de agregado. Revisa la impresora en ⚙️.'),
        backgroundColor: printed ? Colors.green : Colors.orange,
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final categories = _products.map((p) => p.category).toSet().toList();

    return Scaffold(
      appBar: AppBar(title: Text('Agregar a orden de ${widget.order.customerName}')),
      body: Column(
        children: [
          // Lo que ya se había pedido (solo lectura, informativo)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ya pedido (${_currencyFmt.format(widget.order.total)})',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...widget.order.items.map((i) => Text(
                      '${i.quantity}x ${i.productName}${i.notes != null && i.notes!.isNotEmpty ? " (${i.notes})" : ""}',
                      style: const TextStyle(fontSize: 13),
                    )),
              ],
            ),
          ),
          Expanded(
            child: ListView(
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
                    final plainLine = _plainLineFor(product.id!);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Card(
                        child: ListTile(
                          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(_currencyFmt.format(product.price)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.tune),
                                tooltip: 'Personalizar',
                                onPressed: () => _customizeAndAdd(product),
                              ),
                              if (plainLine == null)
                                IconButton.filled(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => _addPlain(product),
                                )
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () => _removePlain(product),
                                    ),
                                    Text('${plainLine.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle),
                                      onPressed: () => _addPlain(product),
                                    ),
                                  ],
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
          ),
        ],
      ),
      bottomSheet: _newItems.isEmpty
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
                        'Agregando: ${_currencyFmt.format(_newTotal)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _saveAndPrint,
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar agregado'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
