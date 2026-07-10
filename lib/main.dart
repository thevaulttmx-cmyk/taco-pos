import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'new_order_screen.dart';
import 'open_orders_screen.dart';
import 'daily_cut_screen.dart';
import 'printer_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX', null);
  runApp(const TacoPosApp());
}

class TacoPosApp extends StatelessWidget {
  const TacoPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taco POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // key para forzar refresco de OpenOrdersScreen al cambiar de tab
  Key _openOrdersKey = UniqueKey();
  Key _dailyCutKey = UniqueKey();

  void _onTabTapped(int index) {
    setState(() {
      _index = index;
      // Refresca datos cada vez que se entra a estas pantallas
      if (index == 1) _openOrdersKey = UniqueKey();
      if (index == 2) _dailyCutKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const NewOrderScreen(),
      OpenOrdersScreen(key: _openOrdersKey),
      DailyCutScreen(key: _dailyCutKey),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taco POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Configurar impresora',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Nueva orden'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Órdenes abiertas'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Corte del día'),
        ],
      ),
    );
  }
}
