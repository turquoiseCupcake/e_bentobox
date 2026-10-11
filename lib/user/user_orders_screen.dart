import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../shared/qr_scanner_screen.dart';
import 'vendor_map_screen.dart'; 

class UserOrdersScreen extends StatefulWidget {
  const UserOrdersScreen({super.key});

  @override
  State<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends State<UserOrdersScreen> {
  final Color primaryColor = Colors.orange;
  
  DateTime _selectedDate = DateTime.now(); // Defaults to CURRENT DAY (Today)
  final ScrollController _calendarScrollController = ScrollController();
  List<dynamic> _myOrders = [];
  bool _isLoading = true;
  String _baseUrl = '';
  int _backlogCount = 0;
  bool _isViewingBacklog = false;
  String _selectedStatusFilter = 'All';

  List<dynamic> get _filteredOrders {
    if (_selectedStatusFilter == 'All') {
      return _myOrders;
    } else if (_selectedStatusFilter == 'Current') {
      return _myOrders.where((o) =>
        ['Pending', 'Accepted', 'Ready', 'Ready for Pickup'].contains(o['status'])
      ).toList();
    } else if (_selectedStatusFilter == 'Ready') {
      return _myOrders.where((o) =>
        o['status'] == 'Ready' || o['status'] == 'Ready for Pickup'
      ).toList();
    } else if (_selectedStatusFilter == 'Claimed') {
      return _myOrders.where((o) => o['status'] == 'Claimed').toList();
    } else {
      return _myOrders.where((o) => o['status'] == _selectedStatusFilter).toList();
    }
  }

  int get _allCount => _myOrders.length;
  int get _currentCount => _myOrders.where((o) => ['Pending', 'Accepted', 'Ready', 'Ready for Pickup'].contains(o['status'])).length;
  int get _pendingCount => _myOrders.where((o) => o['status'] == 'Pending').length;
  int get _acceptedCount => _myOrders.where((o) => o['status'] == 'Accepted').length;
  int get _readyCount => _myOrders.where((o) => o['status'] == 'Ready' || o['status'] == 'Ready for Pickup').length;
  int get _completedCount => _myOrders.where((o) => o['status'] == 'Claimed').length;

  Widget _buildFilterChip({required String key, required String label, required int count}) {
    final isSelected = _selectedStatusFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatusFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: primaryColor.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://54.254.206.248:3000';
    _selectedDate = DateTime.now(); // Defaults to CURRENT DAY (Today)
    _fetchMyOrders();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate(animate: false);
    });
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate({bool animate = true}) {
    if (!_calendarScrollController.hasClients) return;
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    final targetDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final diff = targetDay.difference(startDay).inDays;

    if (diff >= 0 && diff <= 20) {
      const itemWidth = 77.0; // 65 card width + 12 margin
      final screenWidth = MediaQuery.of(context).size.width;
      final targetOffset = (16.0 + diff * itemWidth + 32.5) - (screenWidth / 2);
      final maxScroll = _calendarScrollController.position.maxScrollExtent;
      final clampedOffset = targetOffset.clamp(0.0, maxScroll);

      if (animate) {
        _calendarScrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      } else {
        _calendarScrollController.jumpTo(clampedOffset);
      }
    }
  }

  Future<void> _fetchMyOrders() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('userId');

      if (userId == null) throw Exception('Not logged in');

      final String url;
      if (_isViewingBacklog) {
        url = '$_baseUrl/api/users/$userId/orders?filter=backlog';
      } else {
        final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
        url = '$_baseUrl/api/users/$userId/orders?date=$formattedDate';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _myOrders = data['orders'] ?? [];
            _backlogCount = data['backlogCount'] ?? 0;
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

  Future<void> _claimOrder(String orderId) async {
    final index = _myOrders.indexWhere((o) => o['id'] == orderId);
    if (index != -1) {
      setState(() {
        _myOrders[index]['status'] = 'Claimed';
      });
    }

    try {
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
          // --- HORIZONTAL CALENDAR SCROLL (-7 to +13 days) ---
          SizedBox(
            height: 90,
            child: ListView.builder(
              controller: _calendarScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 22, 
              itemBuilder: (context, index) {
                if (index == 21) {
                  return GestureDetector(
                    onTap: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 90)),
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
                        setState(() {
                          _isViewingBacklog = false;
                          _selectedDate = pickedDate;
                        });
                        _fetchMyOrders();
                        _scrollToSelectedDate();
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

                final date = DateTime.now().subtract(const Duration(days: 7)).add(Duration(days: index));
                final isSelected = !_isViewingBacklog && date.day == _selectedDate.day && date.month == _selectedDate.month && date.year == _selectedDate.year;
                final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _isViewingBacklog = false;
                      _selectedDate = date;
                    });
                    _fetchMyOrders(); 
                    _scrollToSelectedDate();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 65,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected 
                            ? primaryColor 
                            : (isToday ? primaryColor.withValues(alpha: 0.6) : Colors.grey.shade200),
                        width: isToday && !isSelected ? 1.8 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
                          : (isToday
                              ? [BoxShadow(color: primaryColor.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))]
                              : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))]),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isToday ? 'TODAY' : DateFormat('EEE').format(date).toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : (isToday ? primaryColor : Colors.grey.shade500),
                            fontWeight: FontWeight.bold,
                            fontSize: isToday ? 10 : 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : (isToday ? primaryColor : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // --- OVERDUE / UNCLAIMED BACKLOG BANNER ---
          if (_backlogCount > 0)
            GestureDetector(
              onTap: () {
                setState(() => _isViewingBacklog = !_isViewingBacklog);
                _fetchMyOrders();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _isViewingBacklog ? Colors.orange.shade100 : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isViewingBacklog ? Colors.orange.shade800 : Colors.orange.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade900, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_backlogCount Unclaimed Orders From Previous Days',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _isViewingBacklog
                                ? 'Viewing past reservations • Tap to return to calendar'
                                : 'Pending or ready meals • Tap to view & claim',
                            style: TextStyle(color: Colors.orange.shade800, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isViewingBacklog ? Colors.orange.shade900 : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        _isViewingBacklog ? 'Show Calendar' : 'View Backlog',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isViewingBacklog ? Colors.white : Colors.orange.shade900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _isViewingBacklog
                              ? 'Unclaimed Backlog'
                              : (_selectedDate.day == DateTime.now().day && _selectedDate.month == DateTime.now().month && _selectedDate.year == DateTime.now().year
                                  ? 'Today\'s Reservations'
                                  : 'Orders for ${DateFormat('MMMM d').format(_selectedDate)}'),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (_isViewingBacklog) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'All Past Dates',
                          style: TextStyle(color: Colors.orange.shade900, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else if (_selectedDate.day != DateTime.now().day || _selectedDate.month != DateTime.now().month || _selectedDate.year != DateTime.now().year) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = DateTime.now();
                          });
                          _fetchMyOrders();
                          _scrollToSelectedDate();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.today, size: 12, color: primaryColor),
                              const SizedBox(width: 4),
                              Text('Jump to Today', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!_isLoading)
                  Text('${_filteredOrders.length} Items', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          // --- HORIZONTAL STATUS FILTER ROW ---
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(key: 'All', label: 'All', count: _allCount),
                const SizedBox(width: 8),
                _buildFilterChip(key: 'Current', label: 'Current Orders', count: _currentCount),
                const SizedBox(width: 8),
                _buildFilterChip(key: 'Pending', label: 'Pending', count: _pendingCount),
                const SizedBox(width: 8),
                _buildFilterChip(key: 'Accepted', label: 'Preparing', count: _acceptedCount),
                const SizedBox(width: 8),
                _buildFilterChip(key: 'Ready', label: 'Ready for Pickup', count: _readyCount),
                const SizedBox(width: 8),
                _buildFilterChip(key: 'Claimed', label: 'Completed', count: _completedCount),
              ],
            ),
          ),
          const SizedBox(height: 8),

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
                    : _filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.filter_list_off, size: 54, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  'No ${_selectedStatusFilter == "Current" ? "Current" : _selectedStatusFilter} orders',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'There are no reservations matching this filter.',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryColor,
                                    side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => setState(() => _selectedStatusFilter = 'All'),
                                  child: const Text('View All Orders'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: primaryColor,
                            onRefresh: _fetchMyOrders,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (context, index) {
                                final order = _filteredOrders[index];
                            final status = order['status'];
                            final isReady = status == 'Ready' || status == 'Ready for Pickup';
                            final isClaimed = status == 'Claimed';
                            
                            Color statusColor = Colors.orange;
                            if (isReady) statusColor = Colors.green;
                            if (isClaimed) statusColor = Colors.teal;
                            if (status == 'Rejected') statusColor = Colors.red;

                            final double totalAmount = double.tryParse(order['total'].toString()) ?? 0.0;
                            final double? lat = order['vendor_latitude'] != null ? double.tryParse(order['vendor_latitude'].toString()) : null;
                            final double? lng = order['vendor_longitude'] != null ? double.tryParse(order['vendor_longitude'].toString()) : null;
                            final bool hasLocation = lat != null && lng != null;

                            // Parse the saved QR code ID
                            final String? qrId = order['qr_sticker_id'];
                            final String displayQr = (qrId != null && qrId.length >= 8) ? qrId.substring(0, 8).toUpperCase() : '';

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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '₱${totalAmount.toStringAsFixed(2)}', 
                                                style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 18)
                                              ),
                                              if (order['days_overdue'] != null && (order['days_overdue'] as num) > 0) ...[
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.red.shade200),
                                                  ),
                                                  child: Text(
                                                    '${order['days_overdue']}d Overdue • ${order['formatted_date'] ?? order['reservation_date']}',
                                                    style: TextStyle(
                                                      color: Colors.red.shade800,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: statusColor.withValues(alpha: 0.8), 
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
                                              Text(order['vendor_name'] ?? 'Carenderia', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 4),
                                              Text(order['items'] ?? '', style: const TextStyle(color: Colors.black54)),
                                              
                                              // NEW: Display Expected QR Code
                                              if (qrId != null && !isClaimed)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 8.0),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.qr_code_2, size: 16, color: Colors.grey.shade500),
                                                      const SizedBox(width: 4),
                                                      Flexible(child: Text('Expected Box ID: $displayQr', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                                    ],
                                                  ),
                                                ),
                                              const SizedBox(height: 16),
                                            ],
                                          ),
                                        ),
                                        if (hasLocation) ...[
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => VendorMapScreen(
                                                    vendor: {
                                                      'store_name': order['vendor_name'],
                                                      'latitude': lat,
                                                      'longitude': lng,
                                                      'location_description': order['location_description'],
                                                    },
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
                                                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: IgnorePointer( 
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
                                            
                                            // --- SECURITY UPDATE: CHECK IF QR MATCHES ---
                                            if (result != null && context.mounted) {
                                              if (result == qrId) {
                                                _claimOrder(order['id']); // It's a match! Claim it.
                                              } else {
                                                // Invalid code!
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Error: Incorrect Bento Box!'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
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