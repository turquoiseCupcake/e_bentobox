// File: main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this import
import 'auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(
    // 1. Wrap the app in a ChangeNotifierProvider for State Management
    ChangeNotifierProvider(
      create: (context) => BentoCartProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Bentobox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// STATE MANAGEMENT: Provider Class
// ==========================================
class BentoCartProvider extends ChangeNotifier {
  // Upgraded to store a map with name AND price
  final List<Map<String, dynamic>> _cartItems = [];
  DateTime? _reservationDate; // To store the selected next-day date

  List<Map<String, dynamic>> get cartItems => _cartItems;
  int get itemCount => _cartItems.length;
  DateTime? get reservationDate => _reservationDate;

  // Automatically calculates the total price of the bento box
  double get totalPrice => _cartItems.fold(0, (sum, item) => sum + item['price']);

  void addItem(Map<String, dynamic> item) {
    _cartItems.add(item);
    notifyListeners(); // Tells the UI to update
  }

  void setReservationDate(DateTime date) {
    _reservationDate = date;
    notifyListeners();
  }

  // ADD THIS NEW FUNCTION TO EMPTY THE CART AFTER PAYMENT
  void clearCart() {
    _cartItems.clear();
    _reservationDate = null;
    notifyListeners();
  }
}

// ==========================================
// UI SCREEN: Dummy Menu (Student Side)
// ==========================================
class DummyMenuScreen extends StatelessWidget {
  const DummyMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the cart to update the app bar dynamically
    final cartCount = context.watch<BentoCartProvider>().itemCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carenderia Menu'),
        backgroundColor: Colors.orange,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'Cart: $cartCount', 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Button to test Provider State Management
            ElevatedButton(
              onPressed: () {
                // Pass a map instead of just a string
                context.read<BentoCartProvider>().addItem({'name': 'Pork Sisig', 'price': 70.0});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added Pork Sisig to Bento!')),
                );
              },
              child: const Text('+ Add Pork Sisig'),
            ),
            
            const SizedBox(height: 40),
            
            // Button to test the QR Code Scanner
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Open QR Scanner'),
              onPressed: () async {
                // Navigate to scanner and wait for the result
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                );
                
                // When we return from the scanner, show what was scanned
                if (result != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Scanner returned: $result'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// UI SCREEN: QR Scanner View
// ==========================================
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
          // Flashlight Toggle Button (Updated for newer mobile_scanner versions)
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController,
              builder: (context, state, child) {
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
            
            // Return the scanned data to the previous screen (DummyMenuScreen)
            Navigator.pop(context, qrData);
            break; 
          }
        },
      ),
    );
  }
  
  @override
  void dispose() {
    // Always dispose the controller when leaving the screen to free up memory/hardware
    cameraController.dispose();
    super.dispose();
  }
}