import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'add_menu_item_screen.dart';
import 'edit_menu_item_screen.dart';

class VendorMenuScreen extends StatefulWidget {
  const VendorMenuScreen({super.key});

  @override
  State<VendorMenuScreen> createState() => _VendorMenuScreenState();
}

class _VendorMenuScreenState extends State<VendorMenuScreen> {
  final Color primaryColor = const Color(0xFFE91E63);

  List<dynamic> _allMenuItems = [];
  List<dynamic> _displayedMenuItems = [];
  bool _isLoading = true;
  String _baseUrl = '';

  // Search and Filter State
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Ulam', 'Rice', 'Drinks', 'Dessert', 'Combo'];

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    _fetchMenuItems();
  }

  Future<void> _fetchMenuItems() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? vendorId = prefs.getString('userId');

      if (vendorId == null) throw Exception('Vendor not logged in');

      final response = await http.get(Uri.parse('$_baseUrl/api/menu-items/$vendorId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _allMenuItems = data['items'];
            _applyFilters(); // Apply sort/search immediately after fetching
          });
        }
      }
    } catch (e) {
      print('Error fetching menu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to load menu items: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    // 1. Filter by Search Query & Category
    List<dynamic> filtered = _allMenuItems.where((item) {
      final matchesSearch = item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || item['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    // 2. Sort: Available items at the top, Unavailable at the bottom
    filtered.sort((a, b) {
      bool aAvailable = a['is_available'] ?? true;
      bool bAvailable = b['is_available'] ?? true;
      
      if (aAvailable && !bAvailable) return -1;
      if (!aAvailable && bAvailable) return 1;
      return 0; // Keep relative order if both have the same availability
    });

    setState(() {
      _displayedMenuItems = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('Menu Items', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- SEARCH BAR ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) {
                        _searchQuery = value;
                        _applyFilters();
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search your menu...',
                        icon: Icon(Icons.search, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- HORIZONTAL CATEGORY FILTERS ---
            SizedBox(
              height: 35,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: primaryColor,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(color: isSelected ? primaryColor : Colors.grey.shade300),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                          _applyFilters();
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // --- GRID VIEW OF FOOD ITEMS ---
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : RefreshIndicator(
                      color: primaryColor,
                      onRefresh: _fetchMenuItems,
                      child: _displayedMenuItems.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                                Center(
                                  child: Text(
                                    'No menu items found.\nTap + to add one!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                  ),
                                ),
                              ],
                            )
                          : GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.75,
                              ),
                              itemCount: _displayedMenuItems.length,
                              itemBuilder: (context, index) {
                                final item = _displayedMenuItems[index];
                                final imageUrl = '$_baseUrl${item['image_url']}'; 
                                final bool isAvailable = item['is_available'] ?? true;

                                return GestureDetector(
                                  onTap: () async {
                                    // Navigate to edit screen and wait for it to close
                                    await Navigator.push(
                                      context, 
                                      MaterialPageRoute(builder: (context) => EditMenuItemScreen(item: item))
                                    );
                                    // Refresh the list automatically when returning
                                    _fetchMenuItems();
                                  },
                                  child: Opacity(
                                    // Dim the whole card if unavailable
                                    opacity: isAvailable ? 1.0 : 0.6, 
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Cached Image with Grayscale Filter for Unavailable
                                          Expanded(
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                ClipRRect(
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                                  child: item['image_url'] != null
                                                      ? ColorFiltered(
                                                          colorFilter: isAvailable 
                                                              ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                                                              : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                                                          child: CachedNetworkImage(
                                                              imageUrl: imageUrl,
                                                              fit: BoxFit.cover,
                                                              placeholder: (context, url) => Container(
                                                                color: Colors.grey.shade100,
                                                                child: Center(
                                                                  child: CircularProgressIndicator(
                                                                    color: primaryColor.withOpacity(0.3),
                                                                    strokeWidth: 2,
                                                                  ),
                                                                ),
                                                              ),
                                                              errorWidget: (context, url, error) => Container(
                                                                color: Colors.grey.shade200,
                                                                child: const Icon(Icons.broken_image, color: Colors.grey),
                                                              ),
                                                            ),
                                                        )
                                                      : Container(
                                                          color: primaryColor.withOpacity(0.05),
                                                          child: Icon(Icons.fastfood, size: 50, color: primaryColor.withOpacity(0.5)),
                                                        ),
                                                ),
                                                // Unavailable Badge Overlay
                                                if (!isAvailable)
                                                  Positioned(
                                                    top: 8,
                                                    right: 8,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red.shade600,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Text(
                                                        'Unavailable',
                                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['name'] ?? 'Unknown Item',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold, 
                                                    fontSize: 14,
                                                    decoration: isAvailable ? TextDecoration.none : TextDecoration.lineThrough,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '₱${double.parse(item['price'].toString()).toStringAsFixed(2)}',
                                                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddMenuItemScreen()));
          _fetchMenuItems();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}