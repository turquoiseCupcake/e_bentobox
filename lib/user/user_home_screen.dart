import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart'; // NEW IMPORT
import 'package:latlong2/latlong.dart'; // NEW IMPORT
import '../main.dart'; // For BentoCartProvider
import 'carenderia_view_screen.dart';
import 'cart_screen.dart';
import 'vendor_map_screen.dart'; // IMPORT THE NEW MAP SCREEN!

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final Color primaryColor = Colors.orange;
  
  List<dynamic> _allFoods = [];
  List<dynamic> _allVendors = [];
  
  List<dynamic> _filteredFoods = [];
  List<dynamic> _filteredVendors = [];
  
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = ''; 
  String _baseUrl = '';

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Ulam', 'icon': Icons.set_meal},
    {'name': 'Rice', 'icon': Icons.rice_bowl},
    {'name': 'Snacks', 'icon': Icons.fastfood},
    {'name': 'Drinks', 'icon': Icons.local_drink},
    {'name': 'Dessert', 'icon': Icons.icecream},
  ];

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://13.250.200.60:3000';
    _fetchExploreData();
  }

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
            _filteredFoods = _allFoods;
            _filteredVendors = _allVendors;
            _applyFilters();
          });
        }
      }
    } catch (e) {
      print('Error fetching explore data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredFoods = _allFoods.where((f) {
        final matchesSearch = f['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesCategory = _selectedCategory.isEmpty || f['category'] == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();

      _filteredVendors = _allVendors.where((v) {
        return v['store_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _onCategorySelected(String category) {
    _selectedCategory = (_selectedCategory == category) ? '' : category;
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<BentoCartProvider>().itemCount;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 30),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Good Morning!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('Reserve your lunch for tomorrow', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 28),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
                              ),
                              if (cartCount > 0)
                                Positioned(
                                  right: 4, top: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                )
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search food or carenderia...',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            icon: Icon(Icons.search, color: primaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_searchQuery.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 16),
                    child: SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategory == cat['name'];
                          
                          return GestureDetector(
                            onTap: () => _onCategorySelected(cat['name']),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected ? primaryColor : Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSelected ? primaryColor.withOpacity(0.4) : Colors.black.withOpacity(0.05), 
                                          blurRadius: 10, 
                                          offset: const Offset(0, 4)
                                        )
                                      ],
                                    ),
                                    child: Icon(cat['icon'], color: isSelected ? Colors.white : primaryColor, size: 28),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    cat['name'], 
                                    style: TextStyle(
                                      color: isSelected ? primaryColor : Colors.grey.shade700, 
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 12
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              if (_filteredFoods.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: Text(
                      _searchQuery.isEmpty && _selectedCategory.isEmpty 
                          ? 'Popular Foods' 
                          : (_selectedCategory.isNotEmpty && _searchQuery.isEmpty ? '$_selectedCategory Items' : 'Food Results'), 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
                
              if (_filteredFoods.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: _searchQuery.isEmpty ? 220 : 250,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredFoods.length,
                      itemBuilder: (context, index) {
                        final food = _filteredFoods[index];
                        final imageUrl = food['image_url'] != null ? '$_baseUrl${food['image_url']}' : null;
                        
                        return GestureDetector(
                          onTap: () {
                            final vendorId = food['vendor_id'];
                            final vendorMatch = _allVendors.where((v) => v['id'] == vendorId).toList();
                            
                            if (vendorMatch.isNotEmpty) {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(
                                  builder: (context) => CarenderiaViewScreen(vendor: vendorMatch.first)
                                )
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Carenderia details not available.')),
                              );
                            }
                          },
                          child: Container(
                            width: 160,
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    child: imageUrl != null
                                        ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, width: double.infinity)
                                        : Container(color: primaryColor.withOpacity(0.1), child: Icon(Icons.fastfood, color: primaryColor.withOpacity(0.5), size: 40)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(food['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(food['store_name'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 8),
                                      Text('₱${double.parse(food['price'].toString()).toStringAsFixed(2)}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
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
                
              if (_filteredFoods.isEmpty && _filteredVendors.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No results found.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),

              if (_filteredVendors.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Text(
                      _searchQuery.isEmpty ? 'Partner Carenderias' : 'Carenderia Results', 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
                
              if (_filteredVendors.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final vendor = _filteredVendors[index];
                      final coverUrl = vendor['cover_image_url'] != null ? '$_baseUrl${vendor['cover_image_url']}' : null;
                      final profileUrl = vendor['profile_image_url'] != null ? '$_baseUrl${vendor['profile_image_url']}' : null;
                      final hasLocation = vendor['latitude'] != null && vendor['longitude'] != null;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => CarenderiaViewScreen(vendor: vendor)));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 140,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                      child: coverUrl != null 
                                          ? CachedNetworkImage(imageUrl: coverUrl, width: double.infinity, height: 110, fit: BoxFit.cover)
                                          : Container(width: double.infinity, height: 110, color: Colors.grey.shade300, child: const Icon(Icons.storefront, color: Colors.grey)),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 16,
                                      child: Container(
                                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                                        child: CircleAvatar(
                                          radius: 25,
                                          backgroundColor: Colors.white,
                                          backgroundImage: profileUrl != null ? CachedNetworkImageProvider(profileUrl) : null,
                                          child: profileUrl == null ? Icon(Icons.store, color: primaryColor) : null,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Wrap the text column in Expanded so it doesn't push the map off screen
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(vendor['store_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(vendor['location_description'] ?? 'Campus Area', style: TextStyle(color: Colors.grey.shade600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // The New Mini-Map Preview Box
                                    if (hasLocation)
                                      GestureDetector(
                                        onTap: () {
                                          // Expands to the full screen map
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => VendorMapScreen(vendor: vendor)));
                                        },
                                        child: Container(
                                          height: 70, // Matches your drawing proportions
                                          width: 100,
                                          margin: const EdgeInsets.only(left: 12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey.shade300, width: 1.5),
                                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: IgnorePointer( // Prevents the mini-map from stealing scroll gestures
                                              child: FlutterMap(
                                                options: MapOptions(
                                                  initialCenter: LatLng(vendor['latitude'], vendor['longitude']),
                                                  initialZoom: 14.0,
                                                  interactionOptions: const InteractionOptions(
                                                    flags: InteractiveFlag.none, // Lock the map in place
                                                  ),
                                                ),
                                                children: [
                                                  TileLayer(
                                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                    userAgentPackageName: 'com.ebentobox.app',
                                                  ),
                                                  MarkerLayer(
                                                    markers: [
                                                      Marker(
                                                        point: LatLng(vendor['latitude'], vendor['longitude']),
                                                        width: 24,
                                                        height: 24,
                                                        child: const Icon(Icons.location_on, color: Colors.red, size: 24),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _filteredVendors.length,
                  ),
                ),
                
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
    );
  }
}