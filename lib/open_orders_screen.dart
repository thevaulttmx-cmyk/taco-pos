import 'models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'database_service.dart';
import 'checkout_screen.dart';

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
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(
                      '${order.items.fold<int>(0, (s, i) => s + i.quantity)} productos · ${_timeFmt.format(order.createdAt)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_currencyFmt.format(order.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _deleteOrder(order),
                        ),
                      ],
                    ),
                    onTap: () => _openCheckout(order),
                  ),
                );
              },
            ),
    );
  }
}
