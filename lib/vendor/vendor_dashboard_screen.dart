import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Used for date formatting
import '../shared/qr_scanner_screen.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  // Brand color matching the uploaded image
  final Color primaryColor = const Color(0xFFE91E63);

  // Draft state for the calendar
  DateTime _selectedDate = DateTime.now();

  final List<Map<String, dynamic>> _incomingOrders = [
    {
      'id': '8042',
      'customer': 'Juan Dela Cruz',
      'items': '1x Pork Sisig, 1x Plain Rice',
      'total': 85.00,
      'status': 'Pending',
    },
    {
      'id': '8043',
      'customer': 'Maria Santos',
      'items': '2x Chicken Adobo, 2x Plain Rice',
      'total': 150.00,
      'status': 'Accepted',
    },
  ];

  void _updateStatus(int index, String newStatus) {
    setState(() {
      _incomingOrders[index]['status'] = newStatus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Very light background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi Vendor', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            Text('Current Orders', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.1),
              child: Icon(Icons.notifications_none, color: primaryColor),
            ),
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- NEW CALENDAR VIEW DRAFT ---
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 15, // Show next 14 days + 1 "More" button
              itemBuilder: (context, index) {
                // The last item is the 'Expand More' button
                if (index == 14) {
                  return GestureDetector(
                    onTap: () async {
                      // Open a full calendar picker when tapped
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate.isBefore(DateTime.now()) ? DateTime.now() : _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)), // Max 3 months ahead
                        builder: (context, child) {
                          // Theme the date picker to match brand colors
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: primaryColor,
                                onPrimary: Colors.white,
                                onSurface: Colors.black87,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      
                      if (pickedDate != null) {
                        setState(() {
                          _selectedDate = pickedDate;
                          // Later: Fetch orders for this specific date here!
                        });
                      }
                    },
                    child: Container(
                      width: 65,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.date_range, color: Colors.grey.shade600, size: 24),
                          const SizedBox(height: 4),
                          Text(
                            'MORE',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Normal Date Logic
                final date = DateTime.now().add(Duration(days: index));
                final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month && date.year == _selectedDate.year;
                
                // Mock logic: Show a dot if it's today or tomorrow
                final hasOrders = index == 0 || index == 1;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      // Later: Fetch orders for this specific date here!
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 65,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? primaryColor : Colors.grey.shade200,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                          : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date).toUpperCase(), // e.g., MON, TUE
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.grey.shade500,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}', // e.g., 16, 17
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Small dot indicator for pending/active orders
                        if (hasOrders)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : primaryColor,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 6), // Spacer if no orders to keep alignment
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Orders for ${DateFormat('MMMM d').format(_selectedDate)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                Text(
                  '${_incomingOrders.length} Items',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // --- END CALENDAR VIEW DRAFT ---

          // --- ORDERS LIST ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _incomingOrders.length,
              itemBuilder: (context, index) {
                final order = _incomingOrders[index];
                final isPending = order['status'] == 'Pending';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              order['status'],
                              style: TextStyle(
                                color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '₱${order['total'].toStringAsFixed(2)}',
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(order['customer'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(order['items'], style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      const SizedBox(height: 16),
                      
                      if (isPending)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () => _updateStatus(index, 'Rejected'),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                ),
                                onPressed: () => _updateStatus(index, 'Accepted'),
                                child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        )
                      else if (order['status'] == 'Accepted')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor.withOpacity(0.1),
                              foregroundColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan & Mark Ready', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerScreen()));
                              if (result != null && context.mounted) {
                                _updateStatus(index, 'Ready for Pickup');
                              }
                            },
                          ),
                        )
                    ],
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