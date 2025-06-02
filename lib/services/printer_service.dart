import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'dart:typed_data';
import 'package:image/image.dart';

class PrinterService {
  // Printer Type [bluetooth, usb, network]
  var defaultPrinterType = PrinterType.bluetooth;
  var _isBle = false;
  var _reconnect = false;
  var _isConnected = false;
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  StreamSubscription<BTStatus>? _subscriptionBtStatus;
  StreamSubscription<USBStatus>? _subscriptionUsbStatus;
  BTStatus _currentStatus = BTStatus.none;
  USBStatus _currentUsbStatus = USBStatus.none;
  List<int>? pendingTask;
  String _ipAddress = '';
  String _port = '9100';
  BluetoothPrinter? selectedPrinter;
  
  // Stream controllers for external listeners
  final StreamController<List<BluetoothPrinter>> _devicesController = StreamController<List<BluetoothPrinter>>.broadcast();
  final StreamController<bool> _scanningController = StreamController<bool>.broadcast();
  final StreamController<BTStatus> _bluetoothStateController = StreamController<BTStatus>.broadcast();
  
  // Getters for streams
  Stream<List<BluetoothPrinter>> get devicesStream => _devicesController.stream;
  Stream<bool> get scanningStream => _scanningController.stream;
  Stream<BTStatus> get bluetoothStateStream => _bluetoothStateController.stream;
  
  Future<void> initialize() async {
    if (Platform.isWindows) defaultPrinterType = PrinterType.usb;
    
    // Load default printer
    final defaultPrinter = await loadDefaultPrinter();
    if (defaultPrinter != null) {
      selectedPrinter = defaultPrinter;
      _ipAddress = defaultPrinter.address ?? '';
      _port = defaultPrinter.port ?? '9100';
      defaultPrinterType = defaultPrinter.typePrinter;
    }
    
    _initializeBluetoothListeners();
    _scan();
  }

  // Add getter for current printer
  BluetoothPrinter? get currentPrinter => selectedPrinter;
  
  void _initializeBluetoothListeners() {
    // Subscription to listen change status of bluetooth connection
    _subscriptionBtStatus = PrinterManager.instance.stateBluetooth.listen((status) {
      log(' ----------------- status bt $status ------------------ ');
      _currentStatus = status;
      _bluetoothStateController.add(status);
      
      if (status == BTStatus.connected) {
        _isConnected = true;
      }
      if (status == BTStatus.none) {
        _isConnected = false;
      }
      if (status == BTStatus.connected && pendingTask != null) {
        if (Platform.isAndroid) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            PrinterManager.instance.send(type: PrinterType.bluetooth, bytes: pendingTask!);
            pendingTask = null;
          });
        } else if (Platform.isIOS) {
          PrinterManager.instance.send(type: PrinterType.bluetooth, bytes: pendingTask!);
          pendingTask = null;
        }
      }
    });
    
    // PrinterManager.instance.stateUSB is only supports on Android
    _subscriptionUsbStatus = PrinterManager.instance.stateUSB.listen((status) {
      log(' ----------------- status usb $status ------------------ ');
      _currentUsbStatus = status;
      if (Platform.isAndroid) {
        if (status == USBStatus.connected && pendingTask != null) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            PrinterManager.instance.send(type: PrinterType.usb, bytes: pendingTask!);
            pendingTask = null;
          });
        }
      }
    });
  }
  
  // Method to scan devices according PrinterType
  void _scan() {
    devices.clear();
    _scanningController.add(true);
    
    _subscription = printerManager.discovery(type: defaultPrinterType, isBle: _isBle).listen((device) {
      final printer = BluetoothPrinter(
        deviceName: device.name,
        address: device.address,
        isBle: _isBle,
        vendorId: device.vendorId,
        productId: device.productId,
        typePrinter: defaultPrinterType,
      );
      
      devices.add(printer);
      _devicesController.add(List.from(devices));
    });
    
    // Stop scanning after timeout
    Future.delayed(const Duration(seconds: 10), () {
      _scanningController.add(false);
    });
  }
  
  Future<void> startScan({PrinterType? type}) async {
    if (type != null) {
      defaultPrinterType = type;
    }
    _scan();
  }
  
  Future<void> stopScan() async {
    _subscription?.cancel();
    _scanningController.add(false);
  }
  
  void setPort(String value) {
    if (value.isEmpty) value = '9100';
    _port = value;
    var device = BluetoothPrinter(
      deviceName: value,
      address: _ipAddress,
      port: _port,
      typePrinter: PrinterType.network,
      state: false,
    );
    selectDevice(device);
  }
  
  void setIpAddress(String value) {
    _ipAddress = value;
    var device = BluetoothPrinter(
      deviceName: value,
      address: _ipAddress,
      port: _port,
      typePrinter: PrinterType.network,
      state: false,
    );
    selectDevice(device);
  }
  
  Future<void> selectDevice(BluetoothPrinter device) async {
    if (selectedPrinter != null) {
      if ((device.address != selectedPrinter!.address) || 
          (device.typePrinter == PrinterType.usb && selectedPrinter!.vendorId != device.vendorId)) {
        await PrinterManager.instance.disconnect(type: selectedPrinter!.typePrinter);
      }
    }
    
    selectedPrinter = device;
    
    // Hubungkan ke printer
    try {
      switch (device.typePrinter) {
        case PrinterType.bluetooth:
          await PrinterManager.instance.connect(
            type: PrinterType.bluetooth,
            model: BluetoothPrinterInput(
              name: device.deviceName,
              address: device.address!,
              isBle: device.isBle ?? false,
              autoConnect: false,
            ),
          );
          break;
        case PrinterType.usb:
          await PrinterManager.instance.connect(
            type: PrinterType.usb,
            model: UsbPrinterInput(
              name: device.deviceName,
              vendorId: device.vendorId,
              productId: device.productId,
            ),
          );
          break;
        case PrinterType.network:
          await PrinterManager.instance.connect(
            type: PrinterType.network,
            model: TcpPrinterInput(ipAddress: device.address!),
          );
          break;
        default:
          break;
      }
      
      _isConnected = true;
    } catch (e) {
      print('Error connecting to printer: $e');
      _isConnected = false;
      throw Exception('Gagal terhubung ke printer');
    }
    
    // Save as default printer
    await setDefaultPrinter(
      device.typePrinter.toString().split('.').last,
      device.address ?? '',
      port: int.tryParse(device.port ?? '9100') ?? 9100,
    );
  }
  
  Future<void> setDefaultPrinter(String type, String address, {int port = 9100}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_printer_type', type);
    await prefs.setString('default_printer_address', address);
    await prefs.setInt('default_printer_port', port);
    // Tambahkan informasi vendor dan product ID
    if (selectedPrinter?.vendorId != null) {
      await prefs.setString('default_printer_vendor_id', selectedPrinter!.vendorId!);
    }
    if (selectedPrinter?.productId != null) {
      await prefs.setString('default_printer_product_id', selectedPrinter!.productId!);
    }
    await prefs.setString('default_printer_name', selectedPrinter?.deviceName ?? address);
  }

  Future<BluetoothPrinter?> loadDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedType = prefs.getString('default_printer_type');
    final savedAddress = prefs.getString('default_printer_address');
    final savedPort = prefs.getInt('default_printer_port') ?? 9100;
    final savedVendorId = prefs.getString('default_printer_vendor_id');
    final savedProductId = prefs.getString('default_printer_product_id');
    final savedName = prefs.getString('default_printer_name');
    
    if (savedType != null && savedAddress != null) {
      final printerType = PrinterType.values.firstWhere(
        (type) => type.toString().split('.').last == savedType,
        orElse: () => PrinterType.bluetooth
      );
      
      return BluetoothPrinter(
        deviceName: savedName ?? savedAddress,
        address: savedAddress,
        port: savedPort.toString(),
        vendorId: savedVendorId,
        productId: savedProductId,
        typePrinter: printerType,
      );
    }
    return null;
  }
  
  Future<void> saveLogo(String logoPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_logo_path', logoPath);
  }

  Future<String?> getLogo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('printer_logo_path');
  }

  Future<void> removeLogo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('printer_logo_path');
  }

  Future<void> setHeaderText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_header_text', text);
  }

  Future<String?> getHeaderText() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('printer_header_text');
  }

  Future<void> setFooterText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_footer_text', text);
  }

  Future<String?> getFooterText() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('printer_footer_text');
  }

  String _paperSize = 'mm58'; // Default paper size

  Future<void> setPaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_paper_size', size);
    _paperSize = size;
  }

  Future<String> getPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('printer_paper_size') ?? 'mm58';
  }

  Future<bool> printImage(Uint8List imageBytes) async {
    if (selectedPrinter == null) {
      throw Exception('No printer selected');
    }
    
    List<int> bytes = [];
    final profile = await CapabilityProfile.load();
    final paperSize = await getPaperSize();
    final generator = Generator(
      paperSize == 'mm80' ? PaperSize.mm80 : PaperSize.mm58,
      profile
    );
    
    // Check and print logo first if exists
    final logoPath = await getLogo();
    if (logoPath != null) {
      try {
        final logoFile = File(logoPath);
        if (await logoFile.exists()) {
          final logoBytes = await logoFile.readAsBytes();
          final logoImage = decodeImage(logoBytes);
          if (logoImage != null) {
            final resizedLogo = copyResize(logoImage, width: 384);
            final grayscaleLogo = grayscale(resizedLogo);
            bytes += generator.imageRaster(grayscaleLogo);
            bytes += generator.feed(1);
          }
        }
      } catch (e) {
        print('Error printing logo: $e');
      }
    }

    // Print header text if exists
    final headerText = await getHeaderText();
    if (headerText != null && headerText.isNotEmpty) {
      bytes += generator.text(headerText, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
    }
    
    // Print main image
    final image = decodeImage(imageBytes);
    if (image != null) {
      // Menggunakan raw image untuk kualitas lebih baik
      bytes += generator.image(image);
      bytes += generator.feed(1);
    }
    // final resized = copyResize(image, width: 384);
    // final grayscaleImage = grayscale(resized);
    // bytes += generator.imageRaster(grayscaleImage);
    // bytes += generator.feed(1);

    // Print footer text if exists
    final footerText = await getFooterText();
    if (footerText != null && footerText.isNotEmpty) {
      bytes += generator.text(footerText, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
    }
    
    // bytes += generator.feed(1);
    bytes += generator.cut();
    
    return _printEscPos(bytes, generator);
  }
  
  Future<bool> _printEscPos(List<int> bytes, Generator generator) async {
    if (selectedPrinter == null) return false;
    
    var bluetoothPrinter = selectedPrinter!;
    
    try {
      switch (bluetoothPrinter.typePrinter) {
        case PrinterType.usb:
          bytes += generator.feed(2);
          bytes += generator.cut();
          await printerManager.connect(
            type: bluetoothPrinter.typePrinter,
            model: UsbPrinterInput(
              name: bluetoothPrinter.deviceName,
              productId: bluetoothPrinter.productId,
              vendorId: bluetoothPrinter.vendorId,
            ),
          );
          pendingTask = null;
          break;
        case PrinterType.bluetooth:
          bytes += generator.cut();
          await printerManager.connect(
            type: bluetoothPrinter.typePrinter,
            model: BluetoothPrinterInput(
              name: bluetoothPrinter.deviceName,
              address: bluetoothPrinter.address!,
              isBle: bluetoothPrinter.isBle ?? false,
              autoConnect: _reconnect,
            ),
          ).timeout(const Duration(seconds: 5), onTimeout: (){
            _reconnect = false;
            throw Exception('Gagal terhubung ke printer');
          });
          pendingTask = null;
          if (Platform.isAndroid) pendingTask = bytes;
          break;
        case PrinterType.network:
          bytes += generator.feed(2);
          bytes += generator.cut();
          await printerManager.connect(
            type: bluetoothPrinter.typePrinter,
            model: TcpPrinterInput(ipAddress: bluetoothPrinter.address!),
          );
          break;
        default:
      }
    } catch (e) {
      throw Exception('Gagal terhubung ke printer: ${e.toString()}');
    }
    
    if (bluetoothPrinter.typePrinter == PrinterType.bluetooth && Platform.isAndroid) {
      if (_currentStatus == BTStatus.connected) {
        printerManager.send(type: bluetoothPrinter.typePrinter, bytes: bytes);
        pendingTask = null;
      }
    } else {
      printerManager.send(type: bluetoothPrinter.typePrinter, bytes: bytes);
    }
    
    return true;
  }
  
  Future<bool> connectDevice() async {
    _isConnected = false;
    if (selectedPrinter == null) return false;
    
    switch (selectedPrinter!.typePrinter) {
      case PrinterType.usb:
        await printerManager.connect(
          type: selectedPrinter!.typePrinter,
          model: UsbPrinterInput(
            name: selectedPrinter!.deviceName,
            productId: selectedPrinter!.productId,
            vendorId: selectedPrinter!.vendorId,
          ),
        );
        _isConnected = true;
        break;
      case PrinterType.bluetooth:
        await printerManager.connect(
          type: selectedPrinter!.typePrinter,
          model: BluetoothPrinterInput(
            name: selectedPrinter!.deviceName,
            address: selectedPrinter!.address!,
            isBle: selectedPrinter!.isBle ?? false,
            autoConnect: _reconnect,
          ),
        );
        break;
      case PrinterType.network:
        await printerManager.connect(
          type: selectedPrinter!.typePrinter,
          model: TcpPrinterInput(ipAddress: selectedPrinter!.address!),
        );
        _isConnected = true;
        break;
      default:
    }
    
    return _isConnected;
  }
  
  Future<bool> testPrinter() async {
    if (selectedPrinter == null) return false;
    
    List<int> bytes = [];
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    
    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.text('Test Print', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Lance Printer Test');
    bytes += generator.text('Printer: ${selectedPrinter!.deviceName}');
    bytes += generator.text('Type: ${selectedPrinter!.typePrinter.toString().split('.').last}');
    bytes += generator.feed(2);
    
    return _printEscPos(bytes, generator);
  }
  
  Future<void> disconnect() async {
    if (selectedPrinter != null) {
      await printerManager.disconnect(type: selectedPrinter!.typePrinter);
      _isConnected = false;
    }
  }
  
  
  // Getters
  bool get isConnected => _isConnected;
  BTStatus get bluetoothStatus => _currentStatus;
  List<BluetoothPrinter> get availableDevices => devices;
  
  void dispose() {
    _subscription?.cancel();
    _subscriptionBtStatus?.cancel();
    _subscriptionUsbStatus?.cancel();
    _devicesController.close();
    _scanningController.close();
    _bluetoothStateController.close();
  }
}

// BluetoothPrinter class to match the example
class BluetoothPrinter {
  int? id;
  String? deviceName;
  String? address;
  String? port;
  String? vendorId;
  String? productId;
  bool? isBle;
  PrinterType typePrinter;
  bool? state;
  
  BluetoothPrinter({
    this.deviceName,
    this.address,
    this.port,
    this.state,
    this.vendorId,
    this.productId,
    this.typePrinter = PrinterType.bluetooth,
    this.isBle = false,
  });
}