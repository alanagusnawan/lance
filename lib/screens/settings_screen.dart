import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import '../services/printer_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lance/theme/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _defaultPrinterAddress;
  final PrinterService _printerService = PrinterService();
  List<BluetoothPrinter> _bondedDevices = [];
  bool _isLoading = false;
  String? _logoPath;
  final _imagePicker = ImagePicker();
  String? _headerText;
  String? _footerText;
  final _headerController = TextEditingController();
  final _footerController = TextEditingController();
  String _paperSize = 'mm58';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadBondedDevices();
    _loadLogo();
    _loadHeaderFooter();
    _loadPaperSize();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _loadPaperSize() async {
    final size = await _printerService.getPaperSize();
    setState(() {
      _paperSize = size;
    });
  }

  Future<void> _loadHeaderFooter() async {
    final headerText = await _printerService.getHeaderText();
    final footerText = await _printerService.getFooterText();
    setState(() {
      _headerText = headerText;
      _footerText = footerText;
      _headerController.text = headerText ?? '';
      _footerController.text = footerText ?? '';
    });
  }

  Future<void> _saveHeaderText(String text) async {
    await _printerService.setHeaderText(text);
    setState(() {
      _headerText = text;
    });
  }

  Future<void> _saveFooterText(String text) async {
    await _printerService.setFooterText(text);
    setState(() {
      _footerText = text;
    });
  }

  Future<void> _loadLogo() async {
    final logoPath = await _printerService.getLogo();
    setState(() {
      _logoPath = logoPath;
    });
  }

  Future<void> _pickLogo() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        await _printerService.saveLogo(pickedFile.path);
        setState(() {
          _logoPath = pickedFile.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking logo: $e')));
    }
  }

  Future<void> _removeLogo() async {
    await _printerService.removeLogo();
    setState(() {
      _logoPath = null;
    });
  }

  Future<void> _loadSettings() async {
    final defaultPrinter = await _printerService.loadDefaultPrinter();
    setState(() {
      _defaultPrinterAddress = defaultPrinter?.address;
    });
  }

  Future<void> _loadBondedDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _printerService.initialize();
      setState(() {
        _bondedDevices = _printerService.availableDevices;
      });
    } catch (e) {
      print('Error loading bonded devices: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      backgroundColor: colorScheme.primaryContainer.withOpacity(0.1),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.print),
                title: const Text('Default Printer'),
                subtitle: Text(
                  _defaultPrinterAddress != null
                      ? 'Bluetooth: $_defaultPrinterAddress'
                      : 'No printer configured',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.pushNamed(context, '/printer-setup'),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paired Bluetooth Devices',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadBondedDevices,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ..._bondedDevices.map((device) {
              final isDefault = device.address == _defaultPrinterAddress;
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.bluetooth,
                    color: isDefault ? Colors.blue : null,
                  ),
                  title: Text(
                    device.deviceName ?? 'Unknown Device',
                    style: TextStyle(
                      fontWeight:
                          isDefault ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(device.address ?? 'No address'),
                  trailing:
                      isDefault
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : null,
                ),
              );
            }).toList(),
            if (_bondedDevices.isEmpty && !_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No paired devices found',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ukuran Kertas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'mm58',
                          label: Text('58mm'),
                        ),
                        ButtonSegment<String>(
                          value: 'mm80',
                          label: Text('80mm'),
                        ),
                      ],
                      selected: {_paperSize},
                      onSelectionChanged: (Set<String> newSelection) async {
                        await _printerService.setPaperSize(newSelection.first);
                        setState(() {
                          _paperSize = newSelection.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Logo Printer',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (_logoPath != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_logoPath!),
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FilledButton.icon(
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: Text(
                            _logoPath == null ? 'Tambah Logo' : 'Ganti Logo',
                          ),
                        ),
                        if (_logoPath != null)
                          FilledButton.icon(
                            onPressed: _removeLogo,
                            icon: const Icon(Icons.delete),
                            label: const Text('Hapus Logo'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teks Header dan Footer',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _headerController,
                      decoration: const InputDecoration(
                        labelText: 'Header',
                        border: OutlineInputBorder(),
                        hintText: 'Masukkan teks header',
                      ),
                      onChanged: _saveHeaderText,
                      minLines: 3,
                      maxLines: 10,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _footerController,
                      decoration: const InputDecoration(
                        labelText: 'Footer',
                        border: OutlineInputBorder(),
                        hintText: 'Masukkan teks footer',
                      ),
                      onChanged: _saveFooterText,
                      minLines: 3,
                      maxLines: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
