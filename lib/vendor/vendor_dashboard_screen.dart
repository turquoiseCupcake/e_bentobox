import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../shared/qr_scanner_screen.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  final Color primaryColor = const Color(0xFFE91E63);

  DateTime _selectedDate = DateTime.now();
  final ScrollController _calendarScrollController = ScrollController();
  List<dynamic> _incomingOrders = [];
  bool _isLoading = true;
  String _baseUrl = '';
  int _backlogCount = 0;
  bool _isViewingBacklog = false;
  String _selectedStatusFilter = 'All';

  List<dynamic> get _filteredOrders {
    if (_selectedStatusFilter == 'All') {
      return _incomingOrders;
    } else if (_selectedStatusFilter == 'Current') {
      return _incomingOrders.where((o) =>
        ['Pending', 'Accepted', 'Ready', 'Ready for Pickup'].contains(o['status'])
      ).toList();
    } else if (_selectedStatusFilter == 'Ready') {
      return _incomingOrders.where((o) =>
        o['status'] == 'Ready' || o['status'] == 'Ready for Pickup'
      ).toList();
    } else if (_selectedStatusFilter == 'Claimed') {
      return _incomingOrders.where((o) => o['status'] == 'Claimed').toList();
    } else if (_selectedStatusFilter == 'No-Show') {
      return _incomingOrders.where((o) => o['status'] == 'No-Show').toList();
    } else {
      return _incomingOrders.where((o) => o['status'] == _selectedStatusFilter).toList();
    }
  }

  int get _allCount => _incomingOrders.length;
  int get _currentCount => _incomingOrders.where((o) => ['Pending', 'Accepted', 'Ready', 'Ready for Pickup'].contains(o['status'])).length;
  int get _pendingCount => _incomingOrders.where((o) => o['status'] == 'Pending').length;
  int get _acceptedCount => _incomingOrders.where((o) => o['status'] == 'Accepted').length;
  int get _readyCount => _incomingOrders.where((o) => o['status'] == 'Ready' || o['status'] == 'Ready for Pickup').length;
  int get _completedCount => _incomingOrders.where((o) => o['status'] == 'Claimed').length;
  int get _noShowCount => _incomingOrders.where((o) => o['status'] == 'No-Show').length;

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
    _fetchOrders();

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

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? vendorId = prefs.getString('userId');

      if (vendorId == null) throw Exception('Not logged in');

      final String url;
      if (_isViewingBacklog) {
        url = '$_baseUrl/api/vendors/$vendorId/orders?filter=backlog';
      } else {
        final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
        url = '$_baseUrl/api/vendors/$vendorId/orders?date=$formattedDate';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _incomingOrders = data['orders'] ?? [];
            _backlogCount = data['backlogCount'] ?? 0;
          });
        }
      }
    } catch (e) {
      print('Error fetching orders: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // UPDATED: Now accepts orderId directly so it operates correctly with filter subsets
  Future<void> _updateStatus(String orderId, String newStatus, [String? qrData]) async {
    final orderIndex = _incomingOrders.indexWhere((o) => o['id'] == orderId);
    if (orderIndex != -1) {
      setState(() {
        _incomingOrders[orderIndex]['status'] = newStatus;
        if (qrData != null) _incomingOrders[orderIndex]['qr_sticker_id'] = qrData;
        if (newStatus == 'No-Show') {
          _incomingOrders[orderIndex]['strike_issued'] = true;
          _incomingOrders[orderIndex]['customer_strikes'] =
              ((_incomingOrders[orderIndex]['customer_strikes'] as num?)?.toInt() ?? 0) + 1;
          _incomingOrders[orderIndex]['customer_is_banned'] = true;
        }
      });
    }

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        // Send the QR data to the backend!
        body: jsonEncode({'status': newStatus, 'qr_sticker_id': qrData}), 
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200 || !data['success']) {
        throw Exception('Backend rejected status update');
      }
    } catch (e) {
      print('Status update failed: $e');
      _fetchOrders(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update status'), backgroundColor: Colors.red));
      }
    }
  }

  // Confirmation dialog before penalizing a student with a strike
  Future<void> _confirmAndReportNoShow(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Report Customer No-Show?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to flag this order for ${order['customer']} as an abandoned No-Show?',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gavel_rounded, size: 16, color: Colors.red.shade800),
                      const SizedBox(width: 6),
                      Text(
                        'One-Strike Campus Policy',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Issues 1 penalty strike to ${order['customer']}.\n'
                    '• Suspends student account from advance meal reservations.\n'
                    '• Permanent anti-abandonment record.',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade900, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Meal: ${order['items']}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              'Total: ₱${(double.tryParse(order['total'].toString()) ?? 0.0).toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Issue Strike & Close Order', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _updateStatus(order['id'], 'No-Show');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Strike recorded. ${order['customer']}\'s account has been suspended.'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _generateAndPrintQrCodes() async {
    final doc = pw.Document();
    const uuid = Uuid();

    final List<String> qrDataList = List.generate(24, (index) => uuid.v4());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('E-Bentobox - QR Stickers', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('MMM dd, yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 14)),
                ]
              )
            ),
            pw.SizedBox(height: 20),
            pw.Wrap(
              spacing: 20,
              runSpacing: 20,
              children: qrDataList.map((data) {
                return pw.Container(
                  width: 110,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 1, style: pw.BorderStyle.dashed),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(data: data, width: 80, height: 80, barcode: pw.Barcode.qrCode(), drawText: false),
                      pw.SizedBox(height: 8),
                      pw.Text(data.substring(0, 8).toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Bento Box ID', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'E-Bentobox_QR_Stickers_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
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
            Text('Hi Vendor', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            Text('Current Orders', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.print_outlined, color: primaryColor),
            tooltip: 'Generate QR Stickers',
            onPressed: _generateAndPrintQrCodes,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: primaryColor.withValues(alpha: 0.1),
              child: Icon(Icons.notifications_none, color: primaryColor),
            ),
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
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
                        _fetchOrders();
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

                // Generates dates starting from 7 days ago to +13 days ahead
                final date = DateTime.now().subtract(const Duration(days: 7)).add(Duration(days: index));
                final isSelected = !_isViewingBacklog && date.day == _selectedDate.day && date.month == _selectedDate.month && date.year == _selectedDate.year;
                final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _isViewingBacklog = false;
                      _selectedDate = date;
                    });
                    _fetchOrders();
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

          // --- OVERDUE / UNRESOLVED BACKLOG BANNER ---
          if (_backlogCount > 0)
            GestureDetector(
              onTap: () {
                setState(() => _isViewingBacklog = !_isViewingBacklog);
                _fetchOrders();
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
                            '$_backlogCount Overdue Orders From Previous Days',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _isViewingBacklog
                                ? 'Viewing past pending/ready orders • Tap to return to calendar'
                                : 'Pending or unfulfilled orders • Tap to view & resolve',
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
                Row(
                  children: [
                    Text(
                      _isViewingBacklog
                          ? 'Unresolved Backlog'
                          : (_selectedDate.day == DateTime.now().day && _selectedDate.month == DateTime.now().month && _selectedDate.year == DateTime.now().year
                              ? 'Today\'s Orders'
                              : 'Orders for ${DateFormat('MMMM d').format(_selectedDate)}'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
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
                          _fetchOrders();
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
                _buildFilterChip(key: 'Ready', label: 'Ready', count: _readyCount),
                const SizedBox(width: 8),
                _buildFilterChip(key: 'Claimed', label: 'Completed', count: _completedCount),
                if (_noShowCount > 0) ...[
                  const SizedBox(width: 8),
                  _buildFilterChip(key: 'No-Show', label: 'No-Shows', count: _noShowCount),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _isLoading 
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : _incomingOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No orders for this date.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
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
                                  'There are no orders matching this filter.',
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
                            onRefresh: _fetchOrders,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (context, index) {
                                final order = _filteredOrders[index];
                                final isPending = order['status'] == 'Pending';
                                final isNoShow = order['status'] == 'No-Show';
                                final isRejected = order['status'] == 'Rejected';
                                final isClaimed = order['status'] == 'Claimed';
                                final isReady = order['status'] == 'Ready' || order['status'] == 'Ready for Pickup';
                                final double totalAmount = double.tryParse(order['total'].toString()) ?? 0.0;
                                
                                // Parse the saved QR code ID
                                final String? qrId = order['qr_sticker_id'];
                                final String displayQr = (qrId != null && qrId.length >= 8) ? qrId.substring(0, 8).toUpperCase() : '';
                                
                                // Customer strike standing
                                final int customerStrikes = (order['customer_strikes'] as num?)?.toInt() ?? 0;
                                final bool customerBanned = order['customer_is_banned'] == true;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: isPending
                                                      ? Colors.orange.shade50
                                                      : (isRejected || isNoShow ? Colors.red.shade50 : Colors.green.shade50),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (isNoShow) ...[
                                                      Icon(Icons.report_problem_rounded, size: 13, color: Colors.red.shade800),
                                                      const SizedBox(width: 4),
                                                    ],
                                                    Text(
                                                      order['status'],
                                                      style: TextStyle(
                                                        color: isPending
                                                            ? Colors.orange.shade800
                                                            : (isRejected || isNoShow ? Colors.red.shade800 : Colors.green.shade800),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (order['days_overdue'] != null && (order['days_overdue'] as num) > 0) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: Colors.red.shade200),
                                                  ),
                                                  child: Text(
                                                    '${order['days_overdue']}d Overdue • ${order['formatted_date'] ?? order['reservation_date']}',
                                                    style: TextStyle(
                                                      color: Colors.red.shade800,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text('₱${totalAmount.toStringAsFixed(2)}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                                              
                                              // 3-Dot Action Menu (QR Reassignment and No-Show Reporting)
                                              if (!isClaimed && !isNoShow && !isRejected)
                                                PopupMenuButton<String>(
                                                  icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  onSelected: (value) async {
                                                    if (value == 'reassign') {
                                                      final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerScreen()));
                                                      if (result != null && context.mounted) {
                                                        _updateStatus(order['id'], order['status'], result);
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('QR Code Reassigned Successfully!'), backgroundColor: Colors.green),
                                                        );
                                                      }
                                                    } else if (value == 'no_show') {
                                                      _confirmAndReportNoShow(order);
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    if (qrId != null)
                                                      const PopupMenuItem(
                                                        value: 'reassign',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.qr_code_scanner, size: 20, color: Colors.orange),
                                                            SizedBox(width: 12),
                                                            Text('Reassign QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                                                          ],
                                                        ),
                                                      ),
                                                    PopupMenuItem(
                                                      value: 'no_show',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.person_off_rounded, size: 20, color: Colors.red.shade700),
                                                          const SizedBox(width: 12),
                                                          Text('Report No-Show (Strike)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      // Customer Name with Live Strike Badge
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              order['customer'] ?? 'Unknown Customer',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (customerStrikes > 0 || customerBanned)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.red.shade200),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red.shade700),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    customerBanned
                                                        ? '$customerStrikes Strike • Suspended'
                                                        : '$customerStrikes Strike${customerStrikes > 1 ? "s" : ""}',
                                                    style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.shield_outlined, size: 12, color: Colors.green.shade700),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Clean Standing',
                                                    style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(order['items'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                      
                                      // Assigned QR Code Display
                                      if (qrId != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.qr_code_2, size: 16, color: Colors.grey.shade500),
                                              const SizedBox(width: 4),
                                              Text('Box ID: $displayQr', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12)),
                                            ],
                                          ),
                                        ),

                                      const SizedBox(height: 16),
                                      
                                      // Action Area based on Order State
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
                                                onPressed: () => _updateStatus(order['id'], 'Rejected'),
                                                child: const Text('Reject'),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: primaryColor,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                                onPressed: () => _updateStatus(order['id'], 'Accepted'),
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
                                              backgroundColor: primaryColor.withValues(alpha: 0.1),
                                              foregroundColor: primaryColor,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            icon: const Icon(Icons.qr_code_scanner),
                                            label: const Text('Scan & Mark Ready', style: TextStyle(fontWeight: FontWeight.bold)),
                                            onPressed: () async {
                                              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerScreen()));
                                              if (result != null && context.mounted) {
                                                _updateStatus(order['id'], 'Ready', result);
                                              }
                                            },
                                          ),
                                        )
                                      else if (isReady)
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green.shade600,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                                icon: const Icon(Icons.check_circle_outline_rounded),
                                                label: const Text('Complete Order', style: TextStyle(fontWeight: FontWeight.bold)),
                                                onPressed: () => _updateStatus(order['id'], 'Claimed'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red.shade700,
                                                  side: BorderSide(color: Colors.red.shade300),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                                icon: const Icon(Icons.person_off_outlined, size: 18),
                                                label: const Text('No-Show', style: TextStyle(fontWeight: FontWeight.bold)),
                                                onPressed: () => _confirmAndReportNoShow(order),
                                              ),
                                            ),
                                          ],
                                        )
                                      else if (isNoShow)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.red.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.gavel_rounded, color: Colors.red.shade700, size: 20),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'Marked as No-Show. 1 penalty strike has been issued and student account is suspended.',
                                                  style: TextStyle(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                    ],
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