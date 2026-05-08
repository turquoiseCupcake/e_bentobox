import 'package:flutter/material.dart';
import '../shared/qr_scanner_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  // Mock active order state
  bool isClaimed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Reservations', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Active Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          
          // Mock Active Order Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order #8042', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isClaimed ? Colors.green.shade100 : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isClaimed ? 'Claimed' : 'Ready for Pickup',
                          style: TextStyle(
                            color: isClaimed ? Colors.green.shade800 : Colors.deepOrange.shade800, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 12
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Ate Joy\'s Eatery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('1x Pork Sisig, 1x Plain Rice', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 16),
                  
                  // Conditional Button based on claim status
                  if (!isClaimed)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan Bento QR to Claim'),
                        onPressed: () async {
                          // Launch the modular QR Scanner
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                          );

                          // If they scanned something, update the UI
                          if (result != null && context.mounted) {
                            setState(() {
                              isClaimed = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Success! Claimed Bento box (Scanned: $result)'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                      ),
                    )
                  else
                    const SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Enjoy your meal! 🍱',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                        ),
                      ),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}