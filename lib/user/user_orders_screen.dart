import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../shared/qr_scanner_screen.dart';
import 'vendor_map_screen.dart'; // Import to use the full map screen

class UserOrdersScreen extends StatefulWidget {
  const UserOrdersScreen({super.key});

  @override
  State<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends State<UserOrdersScreen> {
  final Color primaryColor = Colors.orange;
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1)); // Default to tomorrow
  List<dynamic> _myOrders = [];
  bool _isLoading = true;
  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://13.250.200.60:3000';
    _fetchMyOrders();
  }

  // --- API CALL: FETCH STUDENT ORDERS ---
  Future<void> _fetchMyOrders() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('userId');

      if (userId == null) throw Exception('Not logged in');

      // Format date for PostgreSQL (YYYY-MM-DD)
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/$userId/orders?date=$formattedDate')
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _myOrders = data['orders'];
          });
        }
      }
    } catch (e) {
      print('Error fetching user orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to fetch orders')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- API CALL: CLAIM ORDER ---
  Future<void> _claimOrder(int index) async {
    final orderId = _myOrders[index]['id'];
    
    // Optimistic UI Update
    setState(() {
      _myOrders[index]['status'] = 'Claimed';
    });

    try {
      // We reuse the same status update endpoint the vendor uses!
      final response = await http.put(
        Uri.parse('$_baseUrl/api/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'Claimed'}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200 || !data['success']) {
        throw Exception('Backend rejected status update');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enjoy your meal! 🍱'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('Status update failed: $e');
      // Rollback UI if it failed
      _fetchMyOrders(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to claim order'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Reservations', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 22)),
            Text('Track your upcoming meals', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // --- HORIZONTAL CALENDAR SCROLL ---
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 15, 
              itemBuilder: (context, index) {
                if (index == 14) {
                  return GestureDetector(
                    onTap: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate.isBefore(DateTime.now()) ? DateTime.now() : _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(primary: primaryColor, onPrimary: Colors.white, onSurface: Colors.black87),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null) {
                        setState(() => _selectedDate = pickedDate);
                        _fetchMyOrders();
                      }
                    },
                    child: Container(
                      width: 65,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300, width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.date_range, color: Colors.grey.shade600, size: 24),
                          const SizedBox(height: 4),
                          Text('MORE', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                }

                final date = DateTime.now().add(Duration(days: index));
                final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month && date.year == _selectedDate.year;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = date);
                    _fetchMyOrders(); 
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 65,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200, width: 1.5),
                      boxShadow: isSelected
                          ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                          : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date).toUpperCase(),
                          style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Orders for ${DateFormat('MMMM d').format(_selectedDate)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
          ),

          // --- REAL ORDERS LIST ---
          Expanded(
            child: _isLoading 
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : _myOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No reservations for this date.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: primaryColor,
                        onRefresh: _fetchMyOrders,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _myOrders.length,
                          itemBuilder: (context, index) {
                            final order = _myOrders[index];
                            final status = order['status'];
                            final isReady = status == 'Ready';
                            final isClaimed = status == 'Claimed';
                            
                            // Visual color coding based on status
                            Color statusColor = Colors.orange;
                            if (isReady) statusColor = Colors.green;
                            if (isClaimed) statusColor = Colors.teal;
                            if (status == 'Rejected') statusColor = Colors.red;

                            final double totalAmount = double.tryParse(order['total'].toString()) ?? 0.0;

                            // Safely parse coordinates if they exist
                            final double? lat = order['vendor_latitude'] != null ? double.tryParse(order['vendor_latitude'].toString()) : null;
                            final double? lng = order['vendor_longitude'] != null ? double.tryParse(order['vendor_longitude'].toString()) : null;
                            final bool hasLocation = lat != null && lng != null;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                          '₱${totalAmount.toStringAsFixed(2)}', 
                                          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 18)
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: statusColor.withOpacity(0.8), 
                                              fontWeight: FontWeight.bold, 
                                              fontSize: 12
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    
                                    // Order Details + Mini Map Row
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(order['vendor_name'] ?? 'Carenderia', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(order['items'] ?? '', style: const TextStyle(color: Colors.black54)),
                                              const SizedBox(height: 16),
                                            ],
                                          ),
                                        ),
                                        if (hasLocation) ...[
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () {
                                              // We construct a temporary vendor object to pass to the Map Screen
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => VendorMapScreen(
                                                    vendor: {
                                                      'store_name': order['vendor_name'],
                                                      'latitude': lat,
                                                      'longitude': lng,
                                                      'location_description': order['location_description'] // Might be null, map screen handles it
                                                    }
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              width: 70,
                                              height: 70,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.grey.shade300),
                                                boxShadow: [
                                                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: IgnorePointer( // Prevents map from swallowing scroll gestures
                                                  child: FlutterMap(
                                                    options: MapOptions(
                                                      initialCenter: LatLng(lat, lng),
                                                      initialZoom: 15.0,
                                                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                                                    ),
                                                    children: [
                                                      TileLayer(
                                                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                        userAgentPackageName: 'com.ebentobox.app',
                                                      ),
                                                      MarkerLayer(
                                                        markers: [
                                                          Marker(
                                                            point: LatLng(lat, lng),
                                                            width: 30,
                                                            height: 30,
                                                            child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ]
                                      ],
                                    ),
                                    
                                    // Action logic based on status
                                    if (isReady)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(Icons.qr_code_scanner),
                                          label: const Text('Scan Bento Box to Claim', style: TextStyle(fontWeight: FontWeight.bold)),
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                                            );
                                            // Once they scan the box, we mark the order as successfully claimed!
                                            if (result != null && context.mounted) {
                                              _claimOrder(index);
                                            }
                                          },
                                        ),
                                      )
                                    else if (isClaimed)
                                      const SizedBox(
                                        width: double.infinity,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8.0),
                                          child: Text(
                                            'Order Complete - Enjoy your meal! 🍱',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 14),
                                          ),
                                        ),
                                      )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}