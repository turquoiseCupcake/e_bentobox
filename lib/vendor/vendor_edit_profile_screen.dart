import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VendorEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> vendorData;

  const VendorEditProfileScreen({super.key, required this.vendorData});

  @override
  State<VendorEditProfileScreen> createState() => _VendorEditProfileScreenState();
}

class _VendorEditProfileScreenState extends State<VendorEditProfileScreen> {
  static const Color primaryColor = Color(0xFFE91E63);
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _hoursController;
  late TextEditingController _locDescController;

  File? _newProfileImage;
  File? _newCoverImage;
  
  bool _isLoading = false;
  bool _isDetectingLocation = false;
  late String _baseUrl;
  late String _currentProfileUrl;
  late String _currentCoverUrl;

  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  // Default to Cagayan De Oro / NEMSU coordinates
  final LatLng _defaultLocation = const LatLng(8.4798, 124.6496);

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    _currentProfileUrl = widget.vendorData['profile_image_url'] ?? '';
    _currentCoverUrl = widget.vendorData['cover_image_url'] ?? '';

    _nameController = TextEditingController(text: widget.vendorData['store_name']);
    _descController = TextEditingController(text: widget.vendorData['description']);
    _hoursController = TextEditingController(text: widget.vendorData['operating_hours']);
    _locDescController = TextEditingController(text: widget.vendorData['location_description']);

    final rawLat = widget.vendorData['latitude'];
    final rawLng = widget.vendorData['longitude'];
    if (rawLat != null && rawLng != null) {
      final double? parsedLat = rawLat is num ? rawLat.toDouble() : double.tryParse(rawLat.toString());
      final double? parsedLng = rawLng is num ? rawLng.toDouble() : double.tryParse(rawLng.toString());
      if (parsedLat != null && parsedLng != null) {
        _selectedLocation = LatLng(parsedLat, parsedLng);
      }
    }

    // Auto-detect current location if vendor has no coordinates saved yet
    if (_selectedLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _detectCurrentLocation(userInitiated: false);
      });
    }
  }

  Future<void> _detectCurrentLocation({bool userInitiated = true}) async {
    setState(() => _isDetectingLocation = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (userInitiated && mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Location services are turned off. Please turn on GPS.'),
              backgroundColor: Colors.orange.shade800,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (userInitiated && mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Location permission denied.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (userInitiated && mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Location permissions permanently denied. Enable in app settings.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) return;
      final detectedLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = detectedLatLng;
      });

      _mapController.move(detectedLatLng, 16.5);

      if (userInitiated) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Location pinned to GPS (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})',
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (userInitiated && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to detect GPS location: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  Future<void> _pickImage(bool isCover) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1000);
    
    if (pickedFile != null) {
      setState(() {
        if (isCover) {
          _newCoverImage = File(pickedFile.path);
        } else {
          _newProfileImage = File(pickedFile.path);
        }
      });
    }
  }

  Future<String?> _uploadSingleImage(File imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/upload'));
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    var response = await http.Response.fromStream(await request.send());
    var responseData = jsonDecode(response.body);
    if (response.statusCode == 200 && responseData['success']) {
      return responseData['imageUrl'];
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String finalProfileUrl = _currentProfileUrl;
      String finalCoverUrl = _currentCoverUrl;

      // Upload new profile image if selected
      if (_newProfileImage != null) {
        final uploadedUrl = await _uploadSingleImage(_newProfileImage!);
        if (uploadedUrl != null) finalProfileUrl = uploadedUrl;
      }
      
      // Upload new cover image if selected
      if (_newCoverImage != null) {
        final uploadedUrl = await _uploadSingleImage(_newCoverImage!);
        if (uploadedUrl != null) finalCoverUrl = uploadedUrl;
      }

      // Update Profile Database Record
      final prefs = await SharedPreferences.getInstance();
      final vendorId = widget.vendorData['id'] ?? prefs.getString('userId');
      if (vendorId == null) {
        throw Exception('Vendor ID not found.');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/api/vendors/$vendorId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'store_name': _nameController.text,
          'description': _descController.text,
          'operating_hours': _hoursController.text,
          'location_description': _locDescController.text,
          'profile_image_url': finalProfileUrl,
          'cover_image_url': finalCoverUrl, // Include the new cover photo URL
          'latitude': _selectedLocation?.latitude,
          'longitude': _selectedLocation?.longitude,
        }),
      );

      if (response.statusCode == 200) {
        await prefs.setString('userName', _nameController.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('Edit Profile', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- COVER & PROFILE IMAGE PICKERS ---
                    Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        // Cover Photo Picker
                        GestureDetector(
                          onTap: () => _pickImage(true),
                          child: Container(
                            height: 160,
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 40), // Leave room for avatar to overlap
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(16),
                              image: _newCoverImage != null
                                  ? DecorationImage(image: FileImage(_newCoverImage!), fit: BoxFit.cover)
                                  : (_currentCoverUrl.isNotEmpty ? DecorationImage(image: NetworkImage('$_baseUrl$_currentCoverUrl'), fit: BoxFit.cover) : null),
                            ),
                            child: (_newCoverImage == null && _currentCoverUrl.isEmpty)
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.wallpaper, size: 40, color: Colors.grey.shade500),
                                      const SizedBox(height: 8),
                                      Text('Add Cover Photo', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold))
                                    ],
                                  )
                                : null,
                          ),
                        ),
                        // Profile Photo Picker (Overlapping)
                        Positioned(
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => _pickImage(false),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: _newProfileImage != null 
                                    ? FileImage(_newProfileImage!) as ImageProvider
                                    : (_currentProfileUrl.isNotEmpty ? NetworkImage('$_baseUrl$_currentProfileUrl') : null),
                                child: (_newProfileImage == null && _currentProfileUrl.isEmpty)
                                    ? Icon(Icons.add_a_photo, size: 30, color: Colors.grey.shade500)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Center(child: Text('Tap icons to change photos', style: TextStyle(color: Colors.grey, fontSize: 12))),
                    const SizedBox(height: 32),

                    // --- TEXT FIELDS ---
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Store Name', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: 'Store Description', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hoursController,
                      decoration: InputDecoration(labelText: 'Operating Hours (e.g. Mon-Fri 8AM-5PM)', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locDescController,
                      decoration: InputDecoration(labelText: 'Location Context (e.g. Near Gate 1)', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    ),
                    const SizedBox(height: 32),

                    // --- MAP PICKER SECTION ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pin Exact Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Tap map or auto-detect GPS position', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: _isDetectingLocation ? null : () => _detectCurrentLocation(userInitiated: true),
                          icon: _isDetectingLocation
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.my_location_rounded, size: 16),
                          label: Text(
                            _isDetectingLocation ? 'Locating...' : 'Use My GPS',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _selectedLocation ?? _defaultLocation,
                                initialZoom: 15.0,
                                onTap: (tapPosition, point) {
                                  setState(() => _selectedLocation = point);
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.ebentobox.app',
                                ),
                                if (_selectedLocation != null)
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _selectedLocation!,
                                        width: 50,
                                        height: 50,
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: primaryColor,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.25),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.storefront_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_drop_down,
                                              color: primaryColor,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            // Floating GPS Button (In-Map Target)
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Material(
                                color: Colors.white,
                                elevation: 3,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _isDetectingLocation ? null : () => _detectCurrentLocation(userInitiated: true),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: _isDetectingLocation
                                        ? SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                                          )
                                        : Icon(
                                            Icons.gps_fixed_rounded,
                                            color: primaryColor,
                                            size: 22,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            // Pinned Coordinates Badge
                            if (_selectedLocation != null)
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.72),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.pin_drop_rounded, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- SAVE BUTTON ---
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: _saveProfile,
                        child: const Text('Save Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}