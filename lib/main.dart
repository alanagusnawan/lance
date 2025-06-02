import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'services/printer_service.dart';
import 'services/file_processor.dart';
import 'screens/settings_screen.dart';
import 'screens/printer_setup_screen.dart';
import 'theme/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const MyHomePage(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/printer-setup': (context) => const PrinterSetupScreen(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late StreamSubscription _intentDataStreamSubscription;
  final PrinterService _printerService = PrinterService();
  final FileProcessor _fileProcessor = FileProcessor();
  List<String> _sharedFiles = [];
  bool _isProcessing = false;
  String _statusMessage = 'Siap menerima file';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeApp() async {
    await _printerService.initialize();
    _listenToIncomingSharedFiles();
    _checkForInitialSharedFiles();
  }

  void _listenToIncomingSharedFiles() {
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    }, onError: (err) {
      print("Error receiving shared files: $err");
    });
  }

  void _checkForInitialSharedFiles() {
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    });
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Memproses ${files.length} file...';
      _sharedFiles = files.map((f) => f.path).toList();
    });
    _animationController.repeat(reverse: true);

    try {
      for (SharedMediaFile file in files) {
        await _processAndPrintFile(file.path);
      }
      
      setState(() {
        _statusMessage = 'Berhasil mencetak ${files.length} file';
      });
      
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _statusMessage = 'Siap menerima file';
            _sharedFiles.clear();
          });
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
      _animationController.stop();
      _animationController.reset();
    }
  }

  Future<void> _showPrinterSelectionSheet() async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Text(
                        'Pilih Printer',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<BluetoothPrinter>>(
                    stream: _printerService.devicesStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Mencari printer...')
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final printer = snapshot.data![index];
                          return ListTile(
                            leading: const Icon(Icons.print),
                            title: Text(printer.deviceName ?? 'Printer tidak dikenal'),
                            subtitle: Text(printer.address ?? ''),
                            onTap: () async {
                              try {
                                await _printerService.selectDevice(printer);
                                Navigator.pop(context, true);
                                // Cetak ulang semua file yang ada
                                if (_sharedFiles.isNotEmpty) {
                                  for (String filePath in _sharedFiles) {
                                    await _fileProcessor.processAndPrintImage(
                                      File(filePath),
                                      _printerService,
                                    );
                                  }
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        child: const Text('Batal'),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          await _printerService.startScan();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Ulang'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processAndPrintFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File tidak ditemukan: $filePath');
    }

    final extension = filePath.toLowerCase().split('.').last;
    if (!['jpg', 'jpeg', 'png', 'bmp'].contains(extension)) {
      throw Exception('Tipe file tidak didukung: $extension');
    }

    try {
      if (_printerService.currentPrinter == null) {
        await _showPrinterSelectionSheet();
      } else {
        await _fileProcessor.processAndPrintImage(file, _printerService);
        await _showPrinterSelectionSheet();
      }
    } catch (e) {
      if (_sharedFiles.isNotEmpty) {
        // Tampilkan bottomsheet untuk pemilihan printer jika terjadi error
        await _showPrinterSelectionSheet();
      } else {
        throw Exception('Gagal mencetak: $e');
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndPrintImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _isProcessing = true;
          _statusMessage = 'Memproses file...';
          _sharedFiles = [image.path];
        });
        _animationController.repeat(reverse: true);

        await _processAndPrintFile(image.path);

        setState(() {
          _statusMessage = 'Berhasil mencetak file';
        });

        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _statusMessage = 'Siap menerima file';
              _sharedFiles.clear();
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.1),
        ),
        child: SafeArea(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Icon(
                    _isProcessing ? Icons.print : Icons.share,
                    size: 80,
                    color: _isProcessing ? colorScheme.primary : colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isProcessing)
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                if (_sharedFiles.isNotEmpty) ...[                  
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'File yang akan diproses:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _sharedFiles.length,
                      itemBuilder: (context, index) {
                        final fileName = _sharedFiles[index].split('/').last;
                        return Card(
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_sharedFiles[index]),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              fileName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(_sharedFiles[index]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // FilledButton.icon(
                    //   onPressed: () => Navigator.pushNamed(context, '/printer-setup'),
                    //   icon: const Icon(Icons.print),
                    //   label: const Text('Setup Printer'),
                    //   style: FilledButton.styleFrom(
                    //     padding: const EdgeInsets.symmetric(
                    //       horizontal: 24,
                    //       vertical: 12,
                    //     ),
                    //   ),
                    // ),
                    FilledButton.icon(
                      onPressed: () =>Navigator.pushNamed(context, '/settings'),
                      icon: const Icon(Icons.settings),
                      label: const Text('Setting'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _pickAndPrintImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Pilih & Cetak'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ),
      ),
    );
  }
}

