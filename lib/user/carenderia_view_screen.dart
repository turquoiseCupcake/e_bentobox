import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../main.dart'; // For BentoCartProvider
import 'cart_screen.dart'; // For Cart Screen
import 'vendor_map_screen.dart'; // For Map Screen

class CarenderiaViewScreen extends StatefulWidget {
  final Map<String, dynamic> vendor;

  const CarenderiaViewScreen({super.key, required this.vendor});

  @override
  State<CarenderiaViewScreen> createState() => _CarenderiaViewScreenState();
}

class _CarenderiaViewScreenState extends State<CarenderiaViewScreen> {
  final Color primaryColor = Colors.orange;
  final Color accentColor = Colors.deepOrange;

  bool _isLoading = true;
  List<dynamic> _menuItems = [];
  List<dynamic> _filteredMenuItems = [];
  String _selectedCategory = 'All';
  String _baseUrl = '';

  // Proximity Calculation
  double? _distanceMeters;

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://54.254.206.248:3000';
    _determineProximity();
    _fetchVendorMenu();
  }

  Future<void> _determineProximity() async {
    try {
      final double? vendorLat = widget.vendor['latitude'] != null ? double.tryParse(widget.vendor['latitude'].toString()) : null;
      final double? vendorLng = widget.vendor['longitude'] != null ? double.tryParse(widget.vendor['longitude'].toString()) : null;

      if (vendorLat == null || vendorLng == null) return;

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      Position? position;
      if (serviceEnabled && permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
        position = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition();
      }

      // If GPS not active, use default NEMSU reference location
      final double uLat = position != null ? position.latitude : 9.0330;
      final double uLng = position != null ? position.longitude : 126.1990;

      final dist = Geolocator.distanceBetween(uLat, uLng, vendorLat, vendorLng);

      if (mounted) {
        setState(() {
          _distanceMeters = dist;
        });
      }
    } catch (_) {}
  }

  String _formatDistance(double? meters) {
    if (meters == null) return 'Campus Area';
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  String _formatWalkingEta(double? meters) {
    if (meters == null) return '~5 min walk';
    final mins = (meters / 75).ceil();
    if (mins <= 1) return '~1 min walk';
    if (mins > 60) return '>1 hr walk';
    return '~$mins min walk';
  }

  String _formatDrivingEta(double? meters) {
    if (meters == null) return '~2 min drive';
    final mins = (meters / 416).ceil();
    if (mins <= 1) return '~1 min drive';
    return '~$mins min drive';
  }

  Future<void> _fetchVendorMenu() async {
    setState(() => _isLoading = true);
    try {
      final String vendorId = widget.vendor['id'];
      final response = await http.get(Uri.parse('$_baseUrl/api/menu-items/$vendorId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final items = (data['items'] as List)
              .where((item) => item['is_available_tomorrow'] != false && item['is_available'] != false)
              .toList();

          if (mounted) {
            setState(() {
              _menuItems = items;
              _filterMenuByCategory();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching vendor menu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterMenuByCategory() {
    if (_selectedCategory == 'All') {
      _filteredMenuItems = List.from(_menuItems);
    } else {
      _filteredMenuItems = _menuItems.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        final selected = _selectedCategory.toLowerCase();
        return cat.contains(selected);
      }).toList();
    }
  }

  List<String> get _categories {
    final Set<String> cats = {'All'};
    for (var item in _menuItems) {
      if (item['category'] != null && item['category'].toString().isNotEmpty) {
        cats.add(item['category'].toString());
      }
    }
    return cats.toList();
  }

  int _getItemCountInCart(String itemId) {
    final cart = context.read<BentoCartProvider>().cartItems;
    return cart.where((item) => item['id'] == itemId).length;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<BentoCartProvider>();
    final cartCount = cart.itemCount;
    final totalPrice = cart.totalPrice;

    final coverUrl = widget.vendor['cover_image_url'] != null ? '$_baseUrl${widget.vendor['cover_image_url']}' : null;
    final profileUrl = widget.vendor['profile_image_url'] != null ? '$_baseUrl${widget.vendor['profile_image_url']}' : null;

    final double? lat = widget.vendor['latitude'] != null ? double.tryParse(widget.vendor['latitude'].toString()) : null;
    final double? lng = widget.vendor['longitude'] != null ? double.tryParse(widget.vendor['longitude'].toString()) : null;
    final bool hasLocation = lat != null && lng != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // --- IMMERSIVE APP BAR WITH COVER & AVATAR ---
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            backgroundColor: primaryColor,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              // Cart Button in App Bar
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 26),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                  ),
                  if (cartCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text(
                          '$cartCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.vendor['store_name'] ?? 'Carenderia',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(color: primaryColor),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black26, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- VENDOR STATS, PROXIMITY & LOCATION CARD ---
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Identity Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade200, width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white,
                          backgroundImage: profileUrl != null ? CachedNetworkImageProvider(profileUrl) : null,
                          child: profileUrl == null ? Icon(Icons.store_rounded, size: 32, color: primaryColor) : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.vendor['store_name'] ?? 'Carenderia',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.verified_rounded, size: 18, color: Colors.blue.shade600),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (widget.vendor['description'] != null && widget.vendor['description'].toString().isNotEmpty)
                              Text(
                                widget.vendor['description'],
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.3),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (widget.vendor['is_active'] != false && widget.vendor['is_available'] != false)
                                    ? Colors.green.shade50
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    (widget.vendor['is_active'] != false && widget.vendor['is_available'] != false)
                                        ? Icons.event_available_rounded
                                        : Icons.event_busy_rounded,
                                    size: 13,
                                    color: (widget.vendor['is_active'] != false && widget.vendor['is_available'] != false)
                                        ? Colors.green.shade800
                                        : Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (widget.vendor['is_active'] != false && widget.vendor['is_available'] != false)
                                        ? 'Reservation Available Tomorrow'
                                        : 'Reservations Paused',
                                    style: TextStyle(
                                      color: (widget.vendor['is_active'] != false && widget.vendor['is_available'] != false)
                                          ? Colors.green.shade800
                                          : Colors.grey.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Proximity & Walking ETA Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.directions_walk_rounded, color: primaryColor, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _distanceMeters != null
                                          ? '${_formatDistance(_distanceMeters)} away • ${_formatWalkingEta(_distanceMeters)}'
                                          : 'Campus Vicinity (~5 min walk)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.directions_car_rounded, color: Colors.grey.shade600, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    _distanceMeters != null ? _formatDrivingEta(_distanceMeters) : '~2 min drive',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '• ${widget.vendor['location_description'] ?? 'Campus Area'}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (hasLocation) ...[
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.map_rounded, size: 16),
                            label: const Text('Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => VendorMapScreen(vendor: widget.vendor)));
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Carenderia Key Stats Row (Rating, Menu Count, Hours, Hygiene)
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.star_rounded,
                          iconColor: Colors.amber.shade700,
                          value: '4.9',
                          label: '95+ Reviews',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.lunch_dining_rounded,
                          iconColor: primaryColor,
                          value: '${_menuItems.length} Dishes',
                          label: 'Ready Tomorrow',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.schedule_rounded,
                          iconColor: Colors.teal.shade700,
                          value: widget.vendor['operating_hours'] != null ? 'Daily' : 'Lunch',
                          label: widget.vendor['operating_hours'] ?? '11:30 - 1:30',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- ADVANCE NEXT-DAY RESERVATION NOTICE ---
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: Colors.orange.shade800, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next-Day Advance Lunch Reservation',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Meals are prepared fresh tomorrow morning. Pick up with zero wait time during lunch (11:30 AM - 1:30 PM).',
                          style: TextStyle(fontSize: 11.5, color: Colors.orange.shade900, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- CATEGORY TABS ---
          if (_categories.length > 1)
            SliverToBoxAdapter(
              child: Container(
                height: 44,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                          _filterMenuByCategory();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.grey.shade300,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
                              : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1))],
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // --- MENU LIST ---
          if (_isLoading)
            SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: primaryColor)),
            )
          else if (_filteredMenuItems.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.no_meals_rounded, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No bento dishes available for this category.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Check other categories or explore tomorrow\'s offerings.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _filteredMenuItems[index];
                    final imageUrl = item['image_url'] != null ? '$_baseUrl${item['image_url']}' : null;
                    final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                    final String itemId = item['id'];
                    final int countInCart = _getItemCountInCart(itemId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Food Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 88,
                                height: 88,
                                child: imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(color: Colors.grey.shade100),
                                        errorWidget: (context, url, error) => Container(
                                          color: primaryColor.withValues(alpha: 0.1),
                                          child: Icon(Icons.fastfood, color: primaryColor.withValues(alpha: 0.5)),
                                        ),
                                      )
                                    : Container(
                                        color: primaryColor.withValues(alpha: 0.1),
                                        child: Icon(Icons.fastfood, color: primaryColor.withValues(alpha: 0.5), size: 36),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Item Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  if (item['category'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item['category'],
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 10.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '₱${price.toStringAsFixed(2)}',
                                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),

                            // Interactive Cart Button / Stepper
                            if (countInCart == 0)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () {
                                  context.read<BentoCartProvider>().addItem({
                                    ...item,
                                    'price': price,
                                  });
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text('Added ${item['name']} to Bento Box!')),
                                        ],
                                      ),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      backgroundColor: Colors.green.shade700,
                                    ),
                                  );
                                },
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18, color: Colors.orange),
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        final provider = context.read<BentoCartProvider>();
                                        final idx = provider.cartItems.indexWhere((c) => c['id'] == itemId);
                                        if (idx != -1) {
                                          provider.removeItem(idx);
                                        }
                                      },
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Text(
                                        '$countInCart',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange.shade900),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18, color: Colors.orange),
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        context.read<BentoCartProvider>().addItem({
                                          ...item,
                                          'price': price,
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _filteredMenuItems.length,
                ),
              ),
            ),

          // Bottom Spacing for Floating Bar
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // --- STICKY FLOATING BOTTOM CART BAR ---
      bottomNavigationBar: cartCount > 0
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$cartCount Bento ${cartCount > 1 ? "Items" : "Item"} in Box',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₱${totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        shadowColor: primaryColor.withValues(alpha: 0.4),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Review Box', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                      },
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}