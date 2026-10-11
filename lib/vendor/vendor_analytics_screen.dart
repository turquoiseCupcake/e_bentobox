import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class VendorAnalyticsScreen extends StatefulWidget {
  const VendorAnalyticsScreen({super.key});

  @override
  State<VendorAnalyticsScreen> createState() => _VendorAnalyticsScreenState();
}

class _VendorAnalyticsScreenState extends State<VendorAnalyticsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _analyticsData;
  int? _selectedBarIndex;

  // Invariant 6: Vendor Role Theming
  static const Color primaryColor = Color(0xFFE91E63); // Deep Pink
  static const Color primaryLight = Color(0xFFFCE4EC);

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final vendorId = prefs.getString('userId');

      if (vendorId == null || vendorId.isEmpty) {
        throw Exception('Vendor session not found. Please log in again.');
      }

      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://54.254.206.248:3000';
      final response = await http.get(Uri.parse('$baseUrl/api/vendors/$vendorId/analytics'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _analyticsData = data;
            _isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load sales data.');
        }
      } else {
        throw Exception('Server returned error status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Sales & Analytics',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Analytics',
            onPressed: _fetchAnalytics,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: 16),
            Text(
              'Compiling your sales data...',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 54, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                'Could not load sales insights',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                onPressed: _fetchAnalytics,
              ),
            ],
          ),
        ),
      );
    }

    final summary = _analyticsData?['summary'] as Map<String, dynamic>? ?? {};
    final dailyTrend = (_analyticsData?['dailyTrend'] as List<dynamic>? ?? []);
    final topDishes = (_analyticsData?['topDishes'] as List<dynamic>? ?? []);
    final recentSales = (_analyticsData?['recentSales'] as List<dynamic>? ?? []);

    final double totalRevenue = (summary['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final int totalOrders = (summary['totalOrders'] as num?)?.toInt() ?? 0;
    final int claimedOrders = (summary['claimedOrders'] as num?)?.toInt() ?? 0;
    final int readyOrders = (summary['readyOrders'] as num?)?.toInt() ?? 0;
    final int acceptedOrders = (summary['acceptedOrders'] as num?)?.toInt() ?? 0;
    final double avgOrderValue = (summary['avgOrderValue'] as num?)?.toDouble() ?? 0.0;

    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER OVERVIEW CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL EARNINGS',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Verified Sales',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currencyFormat.format(totalRevenue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$totalOrders total bento reservations across all menu items',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- 4 KEY PERFORMANCE TILES (2x2 GRID) ---
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Bento Sold',
                    value: '$totalOrders Boxes',
                    icon: Icons.lunch_dining_rounded,
                    color: Colors.purple.shade600,
                    subtitle: '$claimedOrders claimed',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Avg. Order',
                    value: currencyFormat.format(avgOrderValue),
                    icon: Icons.analytics_outlined,
                    color: Colors.teal.shade600,
                    subtitle: 'Per customer meal',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Fulfillment',
                    value: totalOrders > 0
                        ? '${(((claimedOrders + readyOrders + acceptedOrders) / totalOrders) * 100).toInt()}%'
                        : '0%',
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.orange.shade700,
                    subtitle: 'Acceptance rate',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Ready for Pickup',
                    value: '$readyOrders Boxes',
                    icon: Icons.room_service_outlined,
                    color: Colors.indigo.shade600,
                    subtitle: 'Currently staged',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- SALES OVER TIME CHART (PURE FLUTTER ANIMATED BARS) ---
            _buildSectionHeader('Sales Trend by Date', Icons.bar_chart_rounded),
            const SizedBox(height: 12),
            _buildSalesChartCard(dailyTrend, currencyFormat),

            const SizedBox(height: 24),

            // --- TOP SELLING DISHES ---
            _buildSectionHeader('Best-Selling Bento Dishes', Icons.local_fire_department_rounded),
            const SizedBox(height: 12),
            _buildTopDishesCard(topDishes, currencyFormat),

            const SizedBox(height: 24),

            // --- RECENT SALES HISTORY LOG ---
            _buildSectionHeader('Recent Sales Transactions', Icons.receipt_long_rounded),
            const SizedBox(height: 12),
            _buildRecentSalesList(recentSales, currencyFormat),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // --- INTERACTIVE ANIMATED BAR CHART ---
  Widget _buildSalesChartCard(List<dynamic> trend, NumberFormat currencyFormat) {
    if (trend.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.query_stats_rounded, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('No daily sales history recorded yet.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final double maxRevenue = trend.map((e) => (e['revenue'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxRevenue > 0 ? maxRevenue : 100.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
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
              Expanded(
                child: Text(
                  'Daily Revenue (Peak: ${currencyFormat.format(maxRevenue)})',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${trend.length} Days Tracked',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Display Area
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(trend.length, (index) {
                final item = trend[index];
                final double rev = (item['revenue'] as num).toDouble();
                final String dayLabel = item['dayLabel'] ?? '';
                final String dateLabel = item['dateLabel'] ?? '';
                final int count = (item['orderCount'] as num).toInt();

                final double barHeightRatio = (rev / effectiveMax).clamp(0.08, 1.0);
                final bool isSelected = _selectedBarIndex == index;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedBarIndex = isSelected ? null : index;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Tooltip on selection
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${currencyFormat.format(rev)} ($count boxes)',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            const SizedBox(height: 14),

                          const SizedBox(height: 4),

                          // Animated bar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            height: 130 * barHeightRatio,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? [const Color(0xFFC2185B), const Color(0xFF880E4F)]
                                    : [const Color(0xFFE91E63), const Color(0xFFF06292)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Date Label
                          Text(
                            dateLabel.isNotEmpty ? dateLabel.split(' ').last : dayLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? primaryColor : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'Tap on any bar column to view revenue details',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- BEST SELLING DISHES LIST ---
  Widget _buildTopDishesCard(List<dynamic> dishes, NumberFormat currencyFormat) {
    if (dishes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No dish performance data available yet.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: List.generate(dishes.length, (index) {
          final dish = dishes[index];
          final String name = dish['name'] ?? 'Unnamed Dish';
          final String category = dish['category'] ?? 'General';
          final int qty = (dish['totalQty'] as num).toInt();
          final double earned = (dish['totalEarned'] as num).toDouble();

          final isFirst = index == 0;

          return Container(
            margin: EdgeInsets.only(bottom: index == dishes.length - 1 ? 0 : 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFirst ? primaryLight.withValues(alpha: 0.5) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFirst ? primaryColor.withValues(alpha: 0.3) : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                // Rank Badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isFirst ? primaryColor : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        color: isFirst ? Colors.white : Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Dish Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Qty & Earned
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$qty sold',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isFirst ? primaryColor : Colors.grey.shade900,
                      ),
                    ),
                    Text(
                      currencyFormat.format(earned),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // --- RECENT SALES HISTORY LIST ---
  Widget _buildRecentSalesList(List<dynamic> sales, NumberFormat currencyFormat) {
    if (sales.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No recent completed sales transactions.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: List.generate(sales.length, (index) {
          final order = sales[index];
          final String customer = order['customer_name'] ?? 'Customer Diner';
          final String date = order['formatted_date'] ?? '';
          final String items = order['items_summary'] ?? 'Bento items';
          final double total = double.tryParse(order['total_amount'].toString()) ?? 0.0;
          final String status = order['status'] ?? 'Pending';

          Color statusColor = Colors.grey;
          if (status == 'Claimed') statusColor = Colors.teal;
          if (status == 'Ready') statusColor = primaryColor;
          if (status == 'Accepted') statusColor = Colors.orange;

          return Container(
            margin: EdgeInsets.only(bottom: index == sales.length - 1 ? 0 : 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bento icon avatar
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.receipt_rounded, size: 20, color: statusColor),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              customer,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            currencyFormat.format(total),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            date,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
