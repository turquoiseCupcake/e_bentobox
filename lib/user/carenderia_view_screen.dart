import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart'; // For BentoCartProvider
import 'cart_screen.dart'; // Import the new Cart Screen
import 'vendor_map_screen.dart'; // Import the Map Screen

class CarenderiaViewScreen extends StatefulWidget {
  final Map<String, dynamic> vendor;

  const CarenderiaViewScreen({super.key, required this.vendor});

  @override
  State<CarenderiaViewScreen> createState() => _CarenderiaViewScreenState();
}

class _CarenderiaViewScreenState extends State<CarenderiaViewScreen> {
  final Color primaryColor = Colors.orange;
  
  bool _isLoading = true;
  List<dynamic> _menuItems = [];
  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://13.250.200.60:3000';
    _fetchVendorMenu();
  }

  Future<void> _fetchVendorMenu() async {
    setState(() => _isLoading = true);
    try {
      final String vendorId = widget.vendor['id'];
      final response = await http.get(Uri.parse('$_baseUrl/api/menu-items/$vendorId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            // Filter to only show items available for tomorrow
            _menuItems = (data['items'] as List)
                .where((item) => item['is_available_tomorrow'] != false && item['is_available'] != false)
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error fetching vendor menu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<BentoCartProvider>().itemCount;
    
    final coverUrl = widget.vendor['cover_image_url'] != null ? '$_baseUrl${widget.vendor['cover_image_url']}' : null;
    final profileUrl = widget.vendor['profile_image_url'] != null ? '$_baseUrl${widget.vendor['profile_image_url']}' : null;

    // Safely parse map coordinates
    final double? lat = widget.vendor['latitude'] != null ? double.tryParse(widget.vendor['latitude'].toString()) : null;
    final double? lng = widget.vendor['longitude'] != null ? double.tryParse(widget.vendor['longitude'].toString()) : null;
    final bool hasLocation = lat != null && lng != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // --- IMMERSIVE COLLAPSING HEADER ---
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            backgroundColor: primaryColor,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.vendor['store_name'] ?? 'Carenderia',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, textBaseline: TextBaseline.alphabetic, shadows: [
                  Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2))
                ]),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          colorBlendMode: BlendMode.darken,
                          color: Colors.black.withOpacity(0.3), 
                        )
                      : Container(color: primaryColor),
                  // Gradient overlay for smooth transition
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black45],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- VENDOR INFO SECTION ---
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Profile Avatar
                  Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200, width: 2)),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      backgroundImage: profileUrl != null ? CachedNetworkImageProvider(profileUrl) : null,
                      child: profileUrl == null ? Icon(Icons.store, size: 30, color: primaryColor) : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Text Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.vendor['description'] != null && widget.vendor['description'].toString().isNotEmpty) ...[
                          Text(widget.vendor['description'], style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(child: Text(widget.vendor['location_description'] ?? 'Campus Area', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
                          ],
                        ),
                        if (widget.vendor['operating_hours'] != null && widget.vendor['operating_hours'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(child: Text(widget.vendor['operating_hours'], style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                  
                  // --- NEW: MINI MAP PREVIEW ---
                  if (hasLocation) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VendorMapScreen(
                              vendor: widget.vendor, // Pass the whole vendor object!
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: IgnorePointer( // IgnorePointer ensures the map doesn't swallow scroll gestures
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
                  ],
                ],
              ),
            ),
          ),

          // --- NEXT-DAY ORDER BANNER ---
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.deepOrange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "You are reserving food for TOMORROW'S lunch break.",
                      style: TextStyle(color: Colors.deepOrange.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- MENU LIST ---
          if (_isLoading)
            SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: primaryColor)),
            )
          else if (_menuItems.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.no_meals, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('No menu items available for tomorrow.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _menuItems[index];
                    final imageUrl = item['image_url'] != null ? '$_baseUrl${item['image_url']}' : null;
                    final price = double.parse(item['price'].toString());

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Food Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl, width: 80, height: 80, fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(width: 80, height: 80, color: Colors.grey.shade100),
                                    )
                                  : Container(width: 80, height: 80, color: primaryColor.withOpacity(0.1), child: Icon(Icons.fastfood, color: primaryColor.withOpacity(0.5))),
                            ),
                            const SizedBox(width: 16),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(item['category'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Text('₱${price.toStringAsFixed(2)}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                            ),
                            // Add Button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                elevation: 0,
                              ),
                              onPressed: () {
                                context.read<BentoCartProvider>().addItem({
                                  ...item,
                                  'price': price, 
                                });

                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added ${item['name']} to Bento Box!'),
                                    duration: const Duration(seconds: 3),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              },
                              child: const Icon(Icons.add, size: 20),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _menuItems.length,
                ),
              ),
            ),
            
            // Spacing at the bottom so the FAB doesn't cover the last item
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: cartCount > 0 
          ? FloatingActionButton.extended(
              backgroundColor: Colors.deepOrange,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
              },
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text(
                'Cart ($cartCount)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}