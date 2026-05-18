import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'vendor_edit_profile_screen.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final Color primaryColor = const Color(0xFFE91E63);

  Map<String, dynamic>? _vendorData;
  bool _isLoading = true;
  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? vendorId = prefs.getString('userId');

      if (vendorId == null) throw Exception('Not logged in');

      final response = await http.get(Uri.parse('$_baseUrl/api/vendors/$vendorId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _vendorData = data['vendor'];
          });
        }
      }
    } catch (e) {
      print('Error fetching profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_vendorData == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(child: Text('Failed to load profile')),
      );
    }

    final profileUrl = _vendorData!['profile_image_url'] != null 
        ? '$_baseUrl${_vendorData!['profile_image_url']}' 
        : null;
        
    final coverUrl = _vendorData!['cover_image_url'] != null 
        ? '$_baseUrl${_vendorData!['cover_image_url']}' 
        : null;

    final double? lat = _vendorData!['latitude'];
    final double? lng = _vendorData!['longitude'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Header with Cover Photo Background
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 40, left: 24, right: 24),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                // Apply the cover photo if it exists, with a dark overlay so text remains readable
                image: coverUrl != null 
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(coverUrl),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                      ) 
                    : null,
              ),
              child: Column(
                children: [
                  // Profile Avatar with a white border to stand out against the cover
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                      ]
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage: profileUrl != null ? CachedNetworkImageProvider(profileUrl) : null,
                      child: profileUrl == null ? Icon(Icons.store, size: 50, color: primaryColor) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _vendorData!['store_name'] ?? 'Your Store Name', 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      // Navigate to edit screen and refresh when back
                      await Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => VendorEditProfileScreen(vendorData: _vendorData!))
                      );
                      _fetchProfile();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25), 
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.5))
                      ),
                      child: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileSection('Store Description', _vendorData!['description'] ?? 'No description added yet. Tap Edit Profile to add one.'),
                  const SizedBox(height: 24),
                  _buildProfileSection('Operating Hours', _vendorData!['operating_hours'] ?? 'Not specified'),
                  const SizedBox(height: 24),
                  _buildProfileSection('Location Context', _vendorData!['location_description'] ?? 'Not specified'),
                  const SizedBox(height: 24),
                  
                  // Map Location View
                  const Text('Map Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: (lat != null && lng != null)
                          ? FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(lat, lng),
                                initialZoom: 16.0,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none, // View only on profile screen
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
                                      point: LatLng(lat, lng),
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.red,
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_off, color: Colors.grey.shade400, size: 40),
                                  const SizedBox(height: 8),
                                  Text('Location not set', style: TextStyle(color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(content, style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5)),
      ],
    );
  }
}