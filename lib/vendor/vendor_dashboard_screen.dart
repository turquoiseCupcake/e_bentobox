import 'package:flutter/material.dart';
import '../shared/qr_scanner_screen.dart'; // Import the shared scanner

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  // Mock incoming orders scheduled for tomorrow
  final List<Map<String, dynamic>> _incomingOrders = [
    {
      'id': '8042',
      'customer': 'Juan Dela Cruz',
      'items': '1x Pork Sisig, 1x Plain Rice',
      'total': 85.00,
      'status': 'Pending', // Pending, Accepted, Rejected
    },
    {
      'id': '8043',
      'customer': 'Maria Santos',
      'items': '2x Chicken Adobo, 2x Plain Rice',
      'total': 150.00,
      'status': 'Pending',
    },
    {
      'id': '8044',
      'customer': 'Alex Reyes',
      'items': '1x Tortang Talong',
      'total': 40.00,
      'status': 'Pending',
    },
  ];

  void _acceptOrder(int index) {
    setState(() {
      _incomingOrders[index]['status'] = 'Accepted';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #${_incomingOrders[index]['id']} Accepted!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _rejectOrder(int index) {
    String? selectedReason = 'Ingredient not available';
    final reasons = ['Ingredient not available', 'Fully booked', 'Store closed'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Order'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Please select a reason for rejecting this order:'),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedReason,
                    items: reasons
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedReason = val);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _incomingOrders[index]['status'] = 'Rejected';
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order #${_incomingOrders[index]['id']} Rejected.'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: const Text('Confirm Reject'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Vendor Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner emphasizing Next-Day Orders
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.deepOrange.shade50,
            child: Row(
              children: [
                const Icon(Icons.wb_sunny, color: Colors.deepOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Incoming Orders for TOMORROW",
                    style: TextStyle(color: Colors.deepOrange.shade800, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _incomingOrders.length,
              itemBuilder: (context, index) {
                final order = _incomingOrders[index];
                final isPending = order['status'] == 'Pending';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${order['id']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '₱${order['total'].toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 16),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Text(order['customer'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(order['items'], style: const TextStyle(color: Colors.black87)),
                        const SizedBox(height: 16),
                        
                        // Status or Action Buttons
                        if (isPending)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _rejectOrder(index),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _acceptOrder(index),
                                  child: const Text('Accept'),
                                ),
                              ),
                            ],
                          )
                        else if (order['status'] == 'Accepted')
                          Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  order['status'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Scan Sticker & Mark Ready'),
                                  onPressed: () async {
                                    // Launch the shared QR Scanner
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                                    );
                                    
                                    // If a QR code was scanned, update the order status
                                    if (result != null && context.mounted) {
                                      setState(() {
                                        _incomingOrders[index]['status'] = 'Ready for Pickup';
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Linked to QR: $result. Ready for Pickup!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: order['status'] == 'Ready for Pickup' ? Colors.orange.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order['status'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: order['status'] == 'Ready for Pickup' ? Colors.deepOrange.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}