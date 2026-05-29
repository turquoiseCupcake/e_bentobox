import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../main.dart'; 
import 'user_main_screen.dart'; 

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final Color primaryColor = Colors.orange;
  
  bool _isProcessing = true;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _processOrder();
  }

  Future<void> _processOrder() async {
    try {
      // 1. Simulate a short GCash/Maya payment processing delay for UX
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      final cartProvider = context.read<BentoCartProvider>();
      final cartItems = cartProvider.cartItems;
      final reservationDate = cartProvider.reservationDate;

      if (cartItems.isEmpty || reservationDate == null) {
        throw Exception("Your cart is empty or missing a date.");
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) throw Exception("Please log in again.");

      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://13.250.200.60:3000';
      final formattedDate = DateFormat('yyyy-MM-dd').format(reservationDate);

      // 2. Group Cart Items by Vendor
      // If a student orders from 2 different carenderias, we must create 2 separate orders!
      Map<String, Map<String, dynamic>> ordersByVendor = {};

      for (var item in cartItems) {
        final String vId = item['vendor_id'];
        final String mId = item['id'];
        final double price = double.parse(item['price'].toString());

        if (!ordersByVendor.containsKey(vId)) {
          ordersByVendor[vId] = {'total_amount': 0.0, 'items': <String, Map<String, dynamic>>{}};
        }

        ordersByVendor[vId]!['total_amount'] += price;

        // Group quantities of the same item
        if (!ordersByVendor[vId]!['items'].containsKey(mId)) {
          ordersByVendor[vId]!['items'][mId] = {
            'menu_item_id': mId,
            'quantity': 0,
            'price': price,
          };
        }
        ordersByVendor[vId]!['items'][mId]['quantity'] += 1;
      }

      // 3. Send each vendor's order to the Postgres Database
      for (String vendorId in ordersByVendor.keys) {
        final vendorOrder = ordersByVendor[vendorId]!;
        final itemsList = vendorOrder['items'].values.toList();

        final response = await http.post(
          Uri.parse('$baseUrl/api/orders'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'vendor_id': vendorId,
            'total_amount': vendorOrder['total_amount'],
            'reservation_date': formattedDate,
            'items': itemsList,
          }),
        );

        if (response.statusCode != 200) {
           throw Exception("Failed to process order. Is the server running?");
        }
      }

      // 4. Success! Clear the cart and update the UI
      if (mounted) {
        cartProvider.clearCart();
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        automaticallyImplyLeading: _isError, // Only allow back button if it failed
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isProcessing
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.orange),
                    const SizedBox(height: 24),
                    Text('Processing your payment...', style: TextStyle(fontSize: 18, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Please do not close the app.', style: TextStyle(color: Colors.grey)),
                  ],
                )
              : _isError 
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 80),
                        const SizedBox(height: 24),
                        const Text('Transaction Failed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back', style: TextStyle(color: Colors.white)),
                        )
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                          child: const Icon(Icons.check_circle, color: Colors.green, size: 80),
                        ),
                        const SizedBox(height: 32),
                        const Text('Payment Successful!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        const Text(
                          'Your Bento Box has been reserved successfully. You can track its status in the Orders tab.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
                        ),
                        const SizedBox(height: 48),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const UserMainScreen()),
                                (Route<dynamic> route) => false,
                              );
                            },
                            child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}