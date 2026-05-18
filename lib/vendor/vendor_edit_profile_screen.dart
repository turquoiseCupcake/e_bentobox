import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class VendorEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> vendorData;

  const VendorEditProfileScreen({super.key, required this.vendorData});

  @override
  State<VendorEditProfileScreen> createState() => _VendorEditProfileScreenState();
}

class _VendorEditProfileScreenState extends State<VendorEditProfileScreen> {
  final Color primaryColor = const Color(0xFFE91E63);
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _hoursController;
  late TextEditingController _locDescController;

  File? _newProfileImage;
  File? _newCoverImage;
  
  bool _isLoading = false;
  late String _baseUrl;
  late String _currentProfileUrl;
  late String _currentCoverUrl;

  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  // Default to Cagayan De Oro coordinates
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

    if (widget.vendorData['latitude'] != null && widget.vendorData['longitude'] != null) {
      _selectedLocation = LatLng(widget.vendorData['latitude'], widget.vendorData['longitude']);
    } else {
      _determineCurrentLocation();
    }
  }

  Future<void> _determineCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _selectedLocation = LatLng(position.latitude, position.longitude);
    });

    _mapController.move(_selectedLocation!, 15.0);
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
      final response = await http.put(
        Uri.parse('$_baseUrl/api/vendors/${widget.vendorData['id']}'),
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

      if (response.statusCode == 200 && mounted) {
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

                    // --- MAP PICKER ---
                    const Text('Pin Exact Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Tap on the map to place your store pin.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Container(
                      height: 250,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FlutterMap(
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