import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class VendorMapScreen extends StatefulWidget {
  final Map<String, dynamic> vendor;

  const VendorMapScreen({super.key, required this.vendor});

  @override
  State<VendorMapScreen> createState() => _VendorMapScreenState();
}

class _VendorMapScreenState extends State<VendorMapScreen> {
  final MapController _mapController = MapController();
  
  late LatLng _vendorLocation;
  LatLng? _userLocation;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    // Safely grab the vendor's coordinates passed from the home screen
    _vendorLocation = LatLng(
      widget.vendor['latitude'], 
      widget.vendor['longitude']
    );
    _determineUserLocation();
  }

  Future<void> _determineUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    // When permissions are OK, get the location
    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
      
      // Optionally animate the map to show both points, but for now we center on vendor
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.orange;

    return Scaffold(
      appBar: AppBar(
        title: Text('Navigate to ${widget.vendor['store_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _vendorLocation,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ebentobox.app',
              ),
              MarkerLayer(
                markers: [
                  // Vendor Marker (Red Pin)
                  Marker(
                    point: _vendorLocation,
                    width: 50,
                    height: 50,
                    child: const Column(
                      children: [
                        Icon(Icons.store, color: Colors.white, size: 10), // Tiny icon inside pin
                        Icon(Icons.location_on, color: Colors.red, size: 40),
                      ],
                    ),
                  ),
                  
                  // User Marker (Blue Dot) - Only shows if location is found
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          if (_isLoadingLocation)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2)),
                    const SizedBox(width: 12),
                    const Text('Finding your location...', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.orange.shade50,
                    child: Icon(Icons.storefront, color: primaryColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.vendor['store_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(widget.vendor['location_description'] ?? 'Campus Area', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (_userLocation != null)
                    IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.blue),
                      tooltip: 'Center on me',
                      onPressed: () {
                        _mapController.move(_userLocation!, 17.0);
                      },
                    )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}