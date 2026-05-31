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
  List<dynamic> _incomingOrders = [];
  bool _isLoading = true;
  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://13.250.200.60:3000';
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? vendorId = prefs.getString('userId');

      if (vendorId == null) throw Exception('Not logged in');

      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final response = await http.get(
        Uri.parse('$_baseUrl/api/vendors/$vendorId/orders?date=$formattedDate')
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _incomingOrders = data['orders'];
          });
        }
      }
    } catch (e) {
      print('Error fetching orders: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // UPDATED: Now accepts an optional qrData parameter
  Future<void> _updateStatus(int index, String newStatus, [String? qrData]) async {
    final orderId = _incomingOrders[index]['id'];
    
    setState(() {
      _incomingOrders[index]['status'] = newStatus;
      if (qrData != null) _incomingOrders[index]['qr_sticker_id'] = qrData;
    });

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
              backgroundColor: primaryColor.withOpacity(0.1),
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
                        _fetchOrders();
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
                    _fetchOrders();
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
                        Text(DateFormat('EEE').format(date).toUpperCase(), style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text('${date.day}', style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
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
                Text('Orders for ${DateFormat('MMMM d').format(_selectedDate)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                if (!_isLoading)
                  Text('${_incomingOrders.length} Items', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

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
                    : RefreshIndicator(
                        color: primaryColor,
                        onRefresh: _fetchOrders,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _incomingOrders.length,
                          itemBuilder: (context, index) {
                            final order = _incomingOrders[index];
                            final isPending = order['status'] == 'Pending';
                            final double totalAmount = double.tryParse(order['total'].toString()) ?? 0.0;
                            
                            // Parse the saved QR code ID
                            final String? qrId = order['qr_sticker_id'];
                            final String displayQr = (qrId != null && qrId.length >= 8) ? qrId.substring(0, 8).toUpperCase() : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                                          color: isPending ? Colors.orange.shade50 : (order['status'] == 'Rejected' ? Colors.red.shade50 : Colors.green.shade50),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          order['status'],
                                          style: TextStyle(
                                            color: isPending ? Colors.orange.shade800 : (order['status'] == 'Rejected' ? Colors.red.shade800 : Colors.green.shade800),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text('₱${totalAmount.toStringAsFixed(2)}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                                          
                                          // NEW: 3-Dot Menu to reassign QR code (Only shows if a QR is already assigned)
                                          if (qrId != null && order['status'] != 'Claimed')
                                            PopupMenuButton<String>(
                                              icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              onSelected: (value) async {
                                                if (value == 'reassign') {
                                                  final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerScreen()));
                                                  if (result != null && context.mounted) {
                                                    // Pass the existing status, but give it the NEW qr code string!
                                                    _updateStatus(index, order['status'], result);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('QR Code Reassigned Successfully!'), backgroundColor: Colors.green),
                                                    );
                                                  }
                                                }
                                              },
                                              itemBuilder: (context) => [
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
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(order['customer'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(order['items'], style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                  
                                  // NEW: Display the Assigned QR Code!
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
                                  
                                  if (isPending)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.grey.shade700, side: BorderSide(color: Colors.grey.shade300),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            onPressed: () => _updateStatus(index, 'Rejected'),
                                            child: const Text('Reject'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor, foregroundColor: Colors.white, elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12),
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
                                          backgroundColor: primaryColor.withOpacity(0.1), foregroundColor: primaryColor, elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.qr_code_scanner),
                                        label: const Text('Scan & Mark Ready', style: TextStyle(fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerScreen()));
                                          if (result != null && context.mounted) {
                                            // Pass the scanned QR string to the backend!
                                            _updateStatus(index, 'Ready', result);
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
          ),
        ],
      ),
    );
  }
}