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
  
  String _selectedMethod = 'GCash';
  bool _isProcessing = false;
  bool _isSuccess = false;
  bool _isError = false;
  String _errorMessage = '';

  // Removed initState() so it doesn't process instantly anymore!

  Future<void> _processOrder() async {
    setState(() {
      _isProcessing = true;
      _isError = false;
    });

    try {
      // 1. Simulate a realistic gateway delay
      await Future.delayed(const Duration(seconds: 3));

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
      Map<String, Map<String, dynamic>> ordersByVendor = {};

      for (var item in cartItems) {
        final String vId = item['vendor_id'];
        final String mId = item['id'];
        final double price = double.parse(item['price'].toString());

        if (!ordersByVendor.containsKey(vId)) {
          ordersByVendor[vId] = {'total_amount': 0.0, 'items': <String, Map<String, dynamic>>{}};
        }

        ordersByVendor[vId]!['total_amount'] += price;

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

      // 4. Success!
      if (mounted) {
        cartProvider.clearCart();
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
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
    final totalPrice = context.read<BentoCartProvider>().totalPrice;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Secure Checkout', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        automaticallyImplyLeading: !_isProcessing && !_isSuccess, // Block back button during/after process
      ),
      body: _buildBody(totalPrice),
    );
  }

  Widget _buildBody(double totalPrice) {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 24),
            Text('Connecting to $_selectedMethod...', style: TextStyle(fontSize: 18, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Please do not close the app.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_isSuccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
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
      );
    }

    if (_isError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
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
                onPressed: () => setState(() => _isError = false), // Go back to payment selection
                child: const Text('Try Again', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    // --- MAIN PAYMENT PORTAL UI ---
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Text('Total Amount Due', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        '₱${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                const Text('Select Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                _buildPaymentOption('GCash', Icons.account_balance_wallet, Colors.blue),
                _buildPaymentOption('Maya', Icons.account_balance_wallet_outlined, Colors.green),
                _buildPaymentOption('Credit / Debit Card', Icons.credit_card, Colors.indigo),
                _buildPaymentOption('On-the-Spot (Cash on Pickup)', Icons.money, Colors.orange),

                const SizedBox(height: 24),

                // Dynamic Mock Fields based on selection
                if (_selectedMethod == 'GCash' || _selectedMethod == 'Maya')
                  _buildMockTextField('Mobile Number', 'e.g. 0912 345 6789', Icons.phone_android),
                if (_selectedMethod == 'Credit / Debit Card') ...[
                  _buildMockTextField('Card Number', '0000 0000 0000 0000', Icons.credit_card),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildMockTextField('Expiry', 'MM/YY', Icons.calendar_today)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMockTextField('CVV', '123', Icons.security)),
                    ],
                  )
                ],

                const SizedBox(height: 32),

                // One Strike Ban Warning
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'One Strike Ban Policy',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Failure to pick up and pay for your reserved bento box will result in an immediate account ban to protect our partner vendors.',
                              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _processOrder,
                child: Text('Confirm & Pay ₱${totalPrice.toStringAsFixed(2)}', 
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(String title, IconData icon, Color color) {
    final isSelected = _selectedMethod == title;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? Colors.orange : Colors.transparent, width: 2),
      ),
      elevation: isSelected ? 2 : 0,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.orange) : null,
        onTap: () {
          setState(() {
            _selectedMethod = title;
          });
        },
      ),
    );
  }

  Widget _buildMockTextField(String label, String hint, IconData icon) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}