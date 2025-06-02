import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'printer_service.dart';

class FileProcessor {
  Future<void> processAndPrintImage(File imageFile, PrinterService printerService) async {
    final bytes = await imageFile.readAsBytes();
    
    // Decode and resize image for thermal printer
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Could not decode image');
    }
    
    // Resize to fit thermal printer width (384 pixels for 58mm, 576 pixels for 80mm)
    final paperSize = await printerService.getPaperSize();
    final width = paperSize == 'mm80' ? 576 : 384;
    final resized = img.copyResize(image, width: width);
    
    // Convert to grayscale for better thermal printing
    final grayscale = img.grayscale(resized);
    
    // Encode back to bytes
    final processedBytes = Uint8List.fromList(img.encodePng(grayscale));
    
    await printerService.printImage(processedBytes);
  }
}