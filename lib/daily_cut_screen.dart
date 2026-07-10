import 'models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'database_service.dart';

class DailyCutScreen extends StatefulWidget {
  const DailyCutScreen({super.key});

  @override
  State<DailyCutScreen> createState() => _DailyCutScreenState();
}

class _DailyCutScreenState extends State<DailyCutScreen> {
  final _db = DatabaseService.instance;
  final _currencyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _timeFmt = DateFormat('HH:mm');
  final _dateFmt = DateFormat('EEEE d MMMM', 'es_MX');

  DateTime _selectedDate = DateTime.now();
  List<Order> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _db.getPaidOrdersForDate(_selectedDate);
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  Map<String, int> get _productBreakdown {
    final Map<String, int> breakdown = {};
    for (final order in _orders) {
      for (final item in order.items) {
        breakdown[item.productName] = (breakdown[item.productName] ?? 0) + item.quantity;
      }
    }
    return breakdown;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final total = _orders.fold<double>(0, (sum, o) => sum + o.total);
    final breakdown = _productBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_dateFmt.format(_selectedDate), style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Cambiar fecha'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('TOTAL VENDIDO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(
                    _currencyFmt.format(total),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('${_orders.length} órdenes cobradas'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (breakdown.isNotEmpty) ...[
            Text('Productos más vendidos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: breakdown
                    .map((e) => ListTile(
                          title: Text(e.key),
                          trailing: Text('${e.value} pzas', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text('Detalle de órdenes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Sin ventas registradas para este día')),
            )
          else
            ..._orders.map((order) => Card(
                  child: ListTile(
                    title: Text(order.customerName),
                    subtitle: Text('Cobrado a las ${order.paidAt != null ? _timeFmt.format(order.paidAt!) : '-'}'),
                    trailing: Text(_currencyFmt.format(order.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )),
        ],
      ),
    );
  }
}
