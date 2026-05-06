import 'package:flutter/material.dart';
import 'carenderia_view_screen.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for carenderias around the campus
    final List<Map<String, dynamic>> carenderias = [
      {'name': "Ate Joy's Eatery", 'distance': '120m', 'rating': 4.5, 'tag': 'Popular'},
      {'name': "Manang's Sisig", 'distance': '300m', 'rating': 4.8, 'tag': 'Spicy'},
      {'name': "Kuya Jun's BBQ", 'distance': '450m', 'rating': 4.2, 'tag': 'Grill'},
      {'name': "Campus Canteen", 'distance': '50m', 'rating': 4.0, 'tag': 'Convenient'},
      {'name': "Tita Flor's Lomi & Silog", 'distance': '600m', 'rating': 4.6, 'tag': 'Comfort Food'},
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Nearby Carenderias', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () {
              // TODO: Navigate to bento cart screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening Bento Cart...')),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where do you want to reserve for tomorrow?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: carenderias.length,
                itemBuilder: (context, index) {
                  final vendor = carenderias[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // Navigate to Carenderia Menu View
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CarenderiaViewScreen(vendor: vendor),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // Vendor Icon
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.orange.shade100,
                              child: const Icon(Icons.storefront, color: Colors.orange, size: 28),
                            ),
                            const SizedBox(width: 16),
                            // Vendor Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vendor['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(vendor['distance'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.star, size: 14, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(vendor['rating'].toString(), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Forward Arrow
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}