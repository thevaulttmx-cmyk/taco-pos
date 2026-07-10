import 'models.dart';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterDevice {
  final String name;
  final String macAddress;
  PrinterDevice({required this.name, required this.macAddress});
}

class PrinterService {
  PrinterService._internal();
  static final PrinterService instance = PrinterService._internal();

  static const _prefsKey = 'printer_mac_address';

  Future<List<PrinterDevice>> getPairedDevices() async {
    final List<BluetoothInfo> list = await PrintBluetoothThermal.pairedBluetooths;
    return list
        .map((d) => PrinterDevice(name: d.name, macAddress: d.macAdress))
        .toList();
  }

  Future<bool> get isBluetoothEnabled => PrintBluetoothThermal.bluetoothEnabled;

  Future<String?> getSavedPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  Future<void> savePrinterAddress(String macAddress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, macAddress);
  }

  Future<bool> connectToSavedPrinter() async {
    final address = await getSavedPrinterAddress();
    if (address == null) return false;
    return PrintBluetoothThermal.connect(macPrinterAddress: address);
  }

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<bool> disconnect() => PrintBluetoothThermal.disconnect;

  /// Construye el ticket con formato ESC/POS y lo manda a la impresora
  /// térmica conectada. Devuelve true si se envió correctamente.
  Future<bool> printOrderTicket(Order order, {required int orderNumber}) async {
    final connected = await isConnected;
    if (!connected) {
      final ok = await connectToSavedPrinter();
      if (!ok) return false;
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final timeFmt = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    bytes += generator.text(
      'TAQUERIA',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.text(
      'Orden #$orderNumber',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      timeFmt.format(order.createdAt),
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text('Cliente: ${order.customerName}', styles: const PosStyles(bold: true));
    bytes += generator.hr();

    for (final item in order.items) {
      bytes += generator.row([
        PosColumn(
          text: '${item.quantity}x ${item.productName}',
          width: 8,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: currencyFmt.format(item.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
        text: currencyFmt.format(order.total),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2),
      ),
    ]);

    bytes += generator.feed(2);
    bytes += generator.cut();

    return PrintBluetoothThermal.writeBytes(bytes);
  }
}
