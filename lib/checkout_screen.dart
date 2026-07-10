import 'models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'database_service.dart';

class CheckoutScreen extends StatefulWidget {
  final Order order;
  const CheckoutScreen({super.key, required this.order});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _db = DatabaseService.instance;
  final _currencyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _paidController = TextEditingController();

  double get _amountPaid => double.tryParse(_paidController.text.replaceAll(',', '.')) ?? 0;
  double get _change => _amountPaid - widget.order.total;

  Future<void> _confirmPayment() async {
    if (_amountPaid < widget.order.total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto pagado es menor al total'), backgroundColor: Colors.red),
      );
      return;
    }
    await _db.markOrderAsPaid(widget.order.id!, amountPaid: _amountPaid, change: _change);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      appBar: AppBar(title: Text('Cobrar - ${order.customerName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  for (final item in order.items)
                    ListTile(
                      title: Text('${item.quantity}x ${item.productName}'),
                      trailing: Text(_currencyFmt.format(item.subtotal)),
                    ),
                  const Divider(),
                  ListTile(
                    title: const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    trailing: Text(
                      _currencyFmt.format(order.total),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.deepOrange),
                    ),
                  ),
                ],
              ),
            ),
            TextField(
              controller: _paidController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24),
              decoration: const InputDecoration(
                labelText: '¿Con cuánto paga?',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _change >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cambio', style: TextStyle(fontSize: 18)),
                  Text(
                    _currencyFmt.format(_change.isNegative ? 0 : _change),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _change >= 0 ? Colors.green[800] : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _confirmPayment,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Confirmar cobro', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
