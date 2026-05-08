import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // To access BentoCartProvider
import 'user_home_screen.dart'; // To navigate back home on success

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedMethod = 'GCash';
  bool isProcessing = false;

  void _simulatePayment() async {
    setState(() {
      isProcessing = true;
    });

    // Simulate network delay for the mock UI
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Clear the cart after "successful" payment
    context.read<BentoCartProvider>().clearCart();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment Successful! Reservation Confirmed.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    // Return to the User Home Screen and clear the navigation stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const UserHomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read the total price exactly once when the screen builds
    final totalPrice = context.read<BentoCartProvider>().totalPrice;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      body: isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text('Processing Payment...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Amount Header
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

                  // Mock Payment Options
                  _buildPaymentOption('GCash', Icons.account_balance_wallet, Colors.blue),
                  _buildPaymentOption('Maya', Icons.account_balance_wallet_outlined, Colors.green),
                  _buildPaymentOption('Cash on Pickup', Icons.money, Colors.orange),

                  const SizedBox(height: 32),

                  // One Strike Ban Warning (Crucial MVP Feature)
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
      bottomNavigationBar: isProcessing
          ? null
          : Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _simulatePayment,
                    child: Text('Pay ₱${totalPrice.toStringAsFixed(2)}', 
                        style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
    );
  }

  // Helper widget to build the selectable payment cards
  Widget _buildPaymentOption(String title, IconData icon, Color color) {
    final isSelected = selectedMethod == title;
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
            selectedMethod = title;
          });
        },
      ),
    );
  }
}