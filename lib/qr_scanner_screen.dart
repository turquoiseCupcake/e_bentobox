import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  // Controller to handle the camera (flashlight, switching front/back)
  MobileScannerController cameraController = MobileScannerController();
  bool isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Bento QR'),
        actions: [
          // Flashlight Toggle Button
          IconButton(
            icon: ValueListenableBuilder(
              // Listen to the entire controller instead of just torchState
              valueListenable: cameraController, 
              builder: (context, state, child) {
                // Check the torchState inside the controller's state
                if (state.torchState == TorchState.on) {
                  return const Icon(Icons.flash_on, color: Colors.orange);
                }
                return const Icon(Icons.flash_off, color: Colors.grey);
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          if (!isScanning) return; // Prevent multiple scans at once

          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            setState(() {
              isScanning = false; // Stop scanning after first catch
            });
            
            final String qrData = barcode.rawValue ?? 'No data found';
            debugPrint('Barcode found! $qrData');
            
            // For the MVP, we just show a snackbar and go back to the previous screen
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Scanned: $qrData')),
            );
            
            // Return the scanned data to the previous screen
            Navigator.pop(context, qrData);
            break; 
          }
        },
      ),
    );
  }
  
  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}