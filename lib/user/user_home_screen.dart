import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../main.dart'; // For BentoCartProvider, NotificationProvider
import 'carenderia_view_screen.dart';
import 'cart_screen.dart';
import 'vendor_map_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final Color primaryColor = Colors.orange;
  final Color accentColor = Colors.deepOrange;

  List<dynamic> _allFoods = [];
  List<dynamic> _allVendors = [];
  List<dynamic> _filteredFoods = [];
  List<dynamic> _filteredVendors = [];

  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _baseUrl = '';

  // Proximity & Geolocation State
  LatLng? _userLocation;
  String _userLocationLabel = 'Tandag City • NEMSU Campus';
  bool _isLocating = false;

  // Reservation Carousel Controller
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;

  final List<Map<String, dynamic>> _quickFilters = [
    {'name': 'All', 'icon': Icons.restaurant_menu_rounded},
    {'name': 'Near Me (< 1km)', 'icon': Icons.near_me_rounded},
    {'name': 'Top Rated', 'icon': Icons.star_rounded},
    {'name': 'Budget (< ₱65)', 'icon': Icons.savings_rounded},
    {'name': 'Ulam', 'icon': Icons.set_meal_rounded},
    {'name': 'Rice', 'icon': Icons.rice_bowl_rounded},
    {'name': 'Snacks', 'icon': Icons.fastfood_rounded},
    {'name': 'Drinks', 'icon': Icons.local_drink_rounded},
  ];

  final List<Map<String, dynamic>> _heroBanners = [
    {
      'badge': 'ADVANCE RESERVATION',
      'title': 'Reserve Today, Skip the Lines Tomorrow',
      'subtitle': 'Pick up fresh & hot meals at lunch. Zero counter wait time.',
      'gradient': [Color(0xFFFF9800), Color(0xFFF4511E)],
      'icon': Icons.lunch_dining_rounded,
    },
    {
      'badge': 'CAMPUS SUSTAINABILITY',
      'title': 'Zero Food Waste Guarantee',
      'subtitle': 'Carenderias cook exact pre-ordered portions for peak freshness.',
      'gradient': [Color(0xFF00897B), Color(0xFF004D40)],
      'icon': Icons.eco_rounded,
    },
    {
      'badge': 'SMART PICKUP',
      'title': 'Contactless QR Box Claiming',
      'subtitle': 'Authenticate your physical box sticker at the counter instantly.',
      'gradient': [Color(0xFF7E57C2), Color(0xFF3949AB)],
      'icon': Icons.qr_code_scanner_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://54.254.206.248:3000';
    _initUserLocation();
    _fetchExploreData();

    // Connect to WebSockets for live notifications when screen opens
    Future.microtask(() {
      if (mounted) {
        context.read<NotificationProvider>().connect();
      }
    });
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  // --- LOCATION & PROXIMITY INITIALIZER ---
  Future<void> _initUserLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setFallbackLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setFallbackLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setFallbackLocation();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _userLocationLabel = 'Current GPS Location';
          _isLocating = false;
        });
        _applyFilters();
      }
    } catch (e) {
      _setFallbackLocation();
    }
  }

  void _setFallbackLocation() {
    if (mounted) {
      setState(() {
        // Fallback reference: Tandag City / NEMSU Main Campus Center
        _userLocation = const LatLng(9.0330, 126.1990);
        _userLocationLabel = 'NEMSU Main Campus (Default)';
        _isLocating = false;
      });
      _applyFilters();
    }
  }

  double? _getVendorDistance(dynamic vendor) {
    if (_userLocation == null) return null;
    final lat = vendor['latitude'] != null ? double.tryParse(vendor['latitude'].toString()) : null;
    final lng = vendor['longitude'] != null ? double.tryParse(vendor['longitude'].toString()) : null;
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(_userLocation!.latitude, _userLocation!.longitude, lat, lng);
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

  // --- DATA FETCHING & FILTERING ALGORITHM ---
  Future<void> _fetchExploreData() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/menu-items')),
        http.get(Uri.parse('$_baseUrl/api/vendors')),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final foodData = jsonDecode(responses[0].body);
        final vendorData = jsonDecode(responses[1].body);

        if (mounted) {
          setState(() {
            _allFoods = foodData['items'] ?? [];
            _allVendors = vendorData['vendors'] ?? [];
            _applyFilters();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching explore data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();

    // 1. Filter Foods
    List<dynamic> filteredFoods = _allFoods.where((f) {
      final name = f['name']?.toString().toLowerCase() ?? '';
      final category = f['category']?.toString() ?? '';
      final storeName = f['store_name']?.toString().toLowerCase() ?? '';
      final price = double.tryParse(f['price']?.toString() ?? '0') ?? 0.0;

      final matchesQuery = query.isEmpty || name.contains(query) || storeName.contains(query);

      bool matchesFilter = true;
      if (_selectedCategory == 'Budget (< ₱65)') {
        matchesFilter = price <= 65;
      } else if (_selectedCategory == 'Ulam') {
        matchesFilter = category.toLowerCase() == 'ulam';
      } else if (_selectedCategory == 'Rice') {
        matchesFilter = category.toLowerCase().contains('rice');
      } else if (_selectedCategory == 'Snacks') {
        matchesFilter = category.toLowerCase().contains('snack');
      } else if (_selectedCategory == 'Drinks') {
        matchesFilter = category.toLowerCase().contains('drink') || category.toLowerCase().contains('beverage');
      }

      return matchesQuery && matchesFilter;
    }).toList();

    // 2. Filter & Sort Vendors
    List<dynamic> filteredVendors = _allVendors.where((v) {
      final storeName = v['store_name']?.toString().toLowerCase() ?? '';
      final desc = v['description']?.toString().toLowerCase() ?? '';
      final loc = v['location_description']?.toString().toLowerCase() ?? '';

      final matchesQuery = query.isEmpty || storeName.contains(query) || desc.contains(query) || loc.contains(query);

      if (_selectedCategory == 'Near Me (< 1km)') {
        final dist = _getVendorDistance(v);
        return matchesQuery && (dist == null || dist <= 1200);
      }

      return matchesQuery;
    }).toList();

    // Sort vendors based on proximity when distance is available
    if (_selectedCategory == 'Near Me (< 1km)') {
      filteredVendors.sort((a, b) {
        final distA = _getVendorDistance(a) ?? double.infinity;
        final distB = _getVendorDistance(b) ?? double.infinity;
        return distA.compareTo(distB);
      });
    }

    setState(() {
      _filteredFoods = filteredFoods;
      _filteredVendors = filteredVendors;
    });
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<BentoCartProvider>().itemCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: _fetchExploreData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // --- TOP HERO HEADER (Modern Delivery App App-Bar) ---
                  _buildTopHeroHeader(cartCount),

                  // --- HERO RESERVATION PROMOTIONS CAROUSEL ---
                  if (_searchQuery.isEmpty)
                    SliverToBoxAdapter(child: _buildReservationCarousel()),

                  // --- SMART DISCOVERY FILTER CHIPS ---
                  SliverToBoxAdapter(child: _buildFilterChipsStrip()),

                  // --- POPULAR / TRENDING BENTO DISHES ---
                  if (_filteredFoods.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _searchQuery.isEmpty && _selectedCategory == 'All'
                                  ? 'Popular Bento Dishes'
                                  : 'Featured Dishes (${_filteredFoods.length})',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Advance Reserve',
                                style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildPopularFoodsHorizontalList()),
                  ],

                  // --- EMPTY SEARCH FEEDBACK ---
                  if (_filteredFoods.isEmpty && _filteredVendors.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 30),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'No results for "$_searchQuery"',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try checking for typos or searching by dish name, viand, or carenderia.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedCategory = 'All';
                                  });
                                  _applyFilters();
                                },
                                child: const Text('Reset All Filters'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // --- PARTNER CARENDERIAS LIST ---
                  if (_filteredVendors.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _searchQuery.isEmpty ? 'Partner Carenderias' : 'Carenderia Results',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Verified local kitchens offering advance bento pickup',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ),
                            Text(
                              '${_filteredVendors.length} spots',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final vendor = _filteredVendors[index];
                          return _buildCarenderiaCard(vendor);
                        },
                        childCount: _filteredVendors.length,
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 50)),
                ],
              ),
            ),
    );
  }

  // --- HEADER WIDGET ---
  Widget _buildTopHeroHeader(int cartCount) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, accentColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Location & Action Icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Location Selector Pill
                GestureDetector(
                  onTap: _initUserLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isLocating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            _userLocationLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),

                // Top Icons: Notifications + Bento Cart
                Row(
                  children: [
                    // Notification Button
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                          onPressed: _showNotificationsDialog,
                        ),
                        if (context.watch<NotificationProvider>().unreadCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Text(
                                '${context.watch<NotificationProvider>().unreadCount}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Bento Cart Button
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 26),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                        ),
                        if (cartCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Text(
                                '$cartCount',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Row 2: Headline
            const Text(
              'Reserve Hot Bento Boxes',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            const Text(
              'Pre-order fresh carenderia meals for tomorrow • Zero wait time',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),

            const SizedBox(height: 16),

            // Row 3: Modern Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search viand, bento sets, or carenderias...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  icon: Icon(Icons.search_rounded, color: primaryColor),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HERO RESERVATION PROMOTIONS CAROUSEL ---
  Widget _buildReservationCarousel() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          SizedBox(
            height: 128,
            child: PageView.builder(
              controller: _bannerController,
              itemCount: _heroBanners.length,
              onPageChanged: (i) => setState(() => _currentBannerIndex = i),
              itemBuilder: (context, index) {
                final b = _heroBanners[index];
                final List<Color> gradientColors = b['gradient'];

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.first.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                b['badge'],
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              b['title'],
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              b['subtitle'],
                              style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.2),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(b['icon'], color: Colors.white, size: 36),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_heroBanners.length, (idx) {
              final isCurrent = _currentBannerIndex == idx;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 5,
                width: isCurrent ? 18 : 6,
                decoration: BoxDecoration(
                  color: isCurrent ? primaryColor : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- SMART DISCOVERY FILTER CHIPS STRIP ---
  Widget _buildFilterChipsStrip() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: SizedBox(
        height: 42,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _quickFilters.length,
          itemBuilder: (context, index) {
            final f = _quickFilters[index];
            final isSelected = _selectedCategory == f['name'];

            return GestureDetector(
              onTap: () => _onCategorySelected(f['name']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey.shade300,
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f['icon'],
                      size: 16,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      f['name'],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- POPULAR FOODS HORIZONTAL LIST ---
  Widget _buildPopularFoodsHorizontalList() {
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredFoods.length,
        itemBuilder: (context, index) {
          final food = _filteredFoods[index];
          final imageUrl = food['image_url'] != null ? '$_baseUrl${food['image_url']}' : null;
          final double price = double.tryParse(food['price']?.toString() ?? '0') ?? 0.0;
          final String vendorId = food['vendor_id'] ?? '';

          // Look up corresponding vendor for distance display
          final vendorMatch = _allVendors.where((v) => v['id'] == vendorId).toList();
          final dynamic vendor = vendorMatch.isNotEmpty ? vendorMatch.first : null;
          final double? dist = vendor != null ? _getVendorDistance(vendor) : null;

          return GestureDetector(
            onTap: () {
              if (vendor != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CarenderiaViewScreen(vendor: vendor)));
              }
            },
            child: Container(
              width: 165,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food Image with Category Chip
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        child: SizedBox(
                          height: 105,
                          width: double.infinity,
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
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            food['category'] ?? 'Bento',
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Food Details
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.storefront_rounded, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                food['store_name'] ?? 'Carenderia',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₱${price.toStringAsFixed(2)}',
                              style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                            if (dist != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _formatDistance(dist),
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- PARTNER CARENDERIA CARD (DELIVERY STYLE WITH STATS & MINI MAP) ---
  Widget _buildCarenderiaCard(Map<String, dynamic> vendor) {
    final coverUrl = vendor['cover_image_url'] != null ? '$_baseUrl${vendor['cover_image_url']}' : null;
    final profileUrl = vendor['profile_image_url'] != null ? '$_baseUrl${vendor['profile_image_url']}' : null;
    final double? lat = vendor['latitude'] != null ? double.tryParse(vendor['latitude'].toString()) : null;
    final double? lng = vendor['longitude'] != null ? double.tryParse(vendor['longitude'].toString()) : null;
    final bool hasLocation = lat != null && lng != null;

    final double? dist = _getVendorDistance(vendor);
    final String distText = _formatDistance(dist);
    final String walkEta = _formatWalkingEta(dist);
    final bool isAvailable = vendor['is_active'] != false && vendor['is_available'] != false;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CarenderiaViewScreen(vendor: vendor)));
      },
      child: Container(
        margin: const EdgeInsets.only(left: 18, right: 18, bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image Stack
            SizedBox(
              height: 145,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    child: SizedBox(
                      width: double.infinity,
                      height: 120,
                      child: coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: Colors.grey.shade200),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.storefront_rounded, size: 40, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.storefront_rounded, size: 40, color: Colors.grey),
                            ),
                    ),
                  ),

                  // Top Overlay Badges Row (Reservation Availability & Distance)
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAvailable ? Colors.green.shade600 : Colors.grey.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAvailable ? Icons.event_available_rounded : Icons.event_busy_rounded,
                                  color: Colors.white,
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    isAvailable ? 'Reservation Available Tomorrow' : 'Reservations Paused',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.directions_walk_rounded, color: Colors.white, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                '$distText • $walkEta',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating Store Avatar Overlapping Image
                  Positioned(
                    bottom: 0,
                    left: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        backgroundImage: profileUrl != null ? CachedNetworkImageProvider(profileUrl) : null,
                        child: profileUrl == null ? Icon(Icons.store_rounded, color: primaryColor, size: 28) : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Carenderia Info & Map Preview Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Textual Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vendor['store_name'] ?? 'Carenderia',
                                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.verified_rounded, size: 16, color: Colors.blue.shade600),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Rating & Reviews row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade800),
                                  const SizedBox(width: 3),
                                  Text(
                                    '4.9',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Verified Kitchen',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Location Description
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                vendor['location_description'] ?? 'Campus Area',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (vendor['operating_hours'] != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  vendor['operating_hours'],
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Mini-Map Preview (Tappable to launch VendorMapScreen)
                  if (hasLocation) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => VendorMapScreen(vendor: vendor)));
                      },
                      child: Container(
                        height: 78,
                        width: 95,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              IgnorePointer(
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(lat, lng),
                                    initialZoom: 14.5,
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
                                          width: 22,
                                          height: 22,
                                          child: const Icon(Icons.location_on, color: Colors.red, size: 22),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.directions, color: Colors.white, size: 10),
                                      SizedBox(width: 2),
                                      Text('MAP', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- NOTIFICATION DIALOG ---
  void _showNotificationsDialog() {
    context.read<NotificationProvider>().markAsRead();
    showDialog(
      context: context,
      builder: (context) {
        final notifs = context.read<NotificationProvider>().notifications;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Live Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: notifs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No new order alerts.', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: notifs.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.room_service_rounded, color: Colors.orange),
                        title: Text(notifs[index], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }
}