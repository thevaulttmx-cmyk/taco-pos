import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

// Paleta cálida tipo taquería tradicional: rojo salsa como color
// principal, mostaza/naranja como acento, fondo crema.
class AppColors {
  static const salsaRed = Color(0xFFB3261E);
  static const mustard = Color(0xFFE8A33D);
  static const cream = Color(0xFFFFF8F0);
  static const charcoal = Color(0xFF2B2321);
}

class TacoPosApp extends StatelessWidget {
  const TacoPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.salsaRed,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.salsaRed,
      secondary: AppColors.mustard,
      surface: Colors.white,
    );

    final textTheme = GoogleFonts.interTextTheme().copyWith(
      titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.poppins(fontWeight: FontWeight.w700),
    );

    return MaterialApp(
      title: 'Taki-Taki',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.cream,
        useMaterial3: true,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: AppColors.salsaRed,
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.black.withOpacity(0.06)),
          ),
          margin: EdgeInsets.zero,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.salsaRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.salsaRed,
            side: const BorderSide(color: AppColors.salsaRed),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.mustard.withOpacity(0.35),
          labelTextStyle: WidgetStateProperty.all(
            GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.charcoal),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.mustard,
          foregroundColor: AppColors.charcoal,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.salsaRed, width: 2),
          ),
        ),
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
        title: Row(
          children: [
            const Text('🌮', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            const Text('Taki-Taki'),
          ],
        ),
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
