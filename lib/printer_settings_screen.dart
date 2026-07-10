import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _printerService = PrinterService.instance;
  List<PrinterDevice> _devices = [];
  String? _savedAddress;
  bool _loading = true;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Permisos necesarios para Bluetooth en Android 12+
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    _savedAddress = await _printerService.getSavedPrinterAddress();
    final devices = await _printerService.getPairedDevices();
    setState(() {
      _devices = devices;
      _loading = false;
    });
  }

  Future<void> _selectDevice(PrinterDevice device) async {
    setState(() => _connecting = true);
    await _printerService.savePrinterAddress(device.macAddress);
    final connected = await _printerService.connectToSavedPrinter();
    setState(() {
      _savedAddress = device.macAddress;
      _connecting = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(connected
            ? 'Impresora "${device.name}" conectada ✅'
            : 'No se pudo conectar a "${device.name}". Verifica que esté encendida.'),
        backgroundColor: connected ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar impresora')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Primero empareja tu impresora térmica desde el Bluetooth de Android. '
                    'Luego selecciónala aquí para que la app la use al enviar órdenes a cocina.',
                  ),
                ),
                Expanded(
                  child: _devices.isEmpty
                      ? const Center(child: Text('No hay dispositivos Bluetooth emparejados'))
                      : ListView(
                          children: _devices.map((device) {
                            final isSelected = device.macAddress == _savedAddress;
                            return ListTile(
                              leading: Icon(
                                Icons.print,
                                color: isSelected ? Colors.green : null,
                              ),
                              title: Text(device.name),
                              subtitle: Text(device.macAddress),
                              trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                              onTap: _connecting ? null : () => _selectDevice(device),
                            );
                          }).toList(),
                        ),
                ),
                if (_connecting) const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: _init,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar lista'),
                  ),
                ),
              ],
            ),
    );
  }
}
