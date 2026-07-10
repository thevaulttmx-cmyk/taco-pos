import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_service.dart';
import 'checkout_screen.dart';
import 'edit_order_screen.dart';

class OpenOrdersScreen extends StatefulWidget {
  const OpenOrdersScreen({super.key});

  @override
  State<OpenOrdersScreen> createState() => _OpenOrdersScreenState();
}

class _OpenOrdersScreenState extends State<OpenOrdersScreen> {
  final _db = DatabaseService.instance;
  final _currencyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _timeFmt = DateFormat('HH:mm');

  List<Order> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _db.getOpenOrders();
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _openCheckout(Order order) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CheckoutScreen(order: order)),
    );
    if (result == true) _load();
  }

  Future<void> _openEdit(Order order) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditOrderScreen(order: order)),
    );
    if (result == true) _load();
  }

  Future<void> _deleteOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar orden'),
        content: Text('¿Cancelar la orden de "${order.customerName}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirm == true && order.id != null) {
      await _db.deleteOrder(order.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: _orders.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No hay órdenes abiertas 🎉')),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final order = _orders[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(order.customerName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Cancelar orden',
                              onPressed: () => _deleteOrder(order),
                            ),
                          ],
                        ),
                        Text(
                          '${order.items.fold<int>(0, (s, i) => s + i.quantity)} productos · ${_timeFmt.format(order.createdAt)}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openEdit(order),
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _openCheckout(order),
                                icon: const Icon(Icons.point_of_sale),
                                label: Text('Cobrar ${_currencyFmt.format(order.total)}'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
