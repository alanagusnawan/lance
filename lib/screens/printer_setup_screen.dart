import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import '../services/printer_service.dart';

class PrinterSetupScreen extends StatefulWidget {
  final Function(BluetoothPrinter)? onPrinterSelected;
  
  const PrinterSetupScreen({super.key, this.onPrinterSelected});

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  final PrinterService _printerService = PrinterService();
  List<BluetoothPrinter> _bluetoothDevices = [];
  List<BluetoothPrinter> _bondedDevices = [];
  bool _isScanning = false;
  
  @override
  void initState() {
    super.initState();
    _printerService.initialize();
    _scanForPrinters();
  }
  
  Future<void> _scanForPrinters() async {
    setState(() {
      _isScanning = true;
      _bluetoothDevices.clear();
      _bondedDevices.clear();
    });
    
    try {
      await _printerService.startScan(type: PrinterType.bluetooth);
      _printerService.devicesStream.listen((devices) {
        setState(() {
          _bluetoothDevices = devices;
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Setup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _scanForPrinters,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isScanning)
              const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Available Bluetooth Printers',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ..._bluetoothDevices.map((device) => Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(device.deviceName ?? 'Unknown Device'),
                      subtitle: Text(device.address ?? 'No address'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _testAndSelectPrinter(device),
                    ),
                  )),
                  if (_bluetoothDevices.isEmpty && !_isScanning)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No printers found. Make sure your printer is turned on and try refreshing.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testAndSelectPrinter(BluetoothPrinter device) async {
    try {
      await _printerService.selectDevice(device);
      bool testResult = await _printerService.testPrinter();
      
      if (testResult) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printer berhasil dipilih'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Jika ada callback onPrinterSelected, panggil dengan printer yang dipilih
        widget.onPrinterSelected?.call(device);
        
        if (widget.onPrinterSelected == null) {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal terhubung ke printer. Silakan coba lagi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
}
}