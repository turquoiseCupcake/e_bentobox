import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // Importing to access BentoCartProvider
import 'cart_screen.dart'; // Import the new Cart Screen

class CarenderiaViewScreen extends StatelessWidget {
  final Map<String, dynamic> vendor;

  const CarenderiaViewScreen({super.key, required this.vendor});

  @override
  Widget build(BuildContext context) {
    // Mock menu data (simulating next-day availability)
    final List<Map<String, dynamic>> menuItems = [
      {'name': 'Chicken Adobo', 'price': 60.0, 'category': 'Ulam'},
      {'name': 'Pork Sisig', 'price': 70.0, 'category': 'Ulam'},
      {'name': 'Tortang Talong', 'price': 40.0, 'category': 'Ulam'},
      {'name': 'Chicken Pastil', 'price': 35.0, 'category': 'Ulam'},
      {'name': 'Plain Rice', 'price': 15.0, 'category': 'Rice'},
    ];

    // Watch cart to update the FAB badge
    final cartCount = context.watch<BentoCartProvider>().itemCount;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(vendor['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner emphasizing Next-Day Order
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade100,
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.deepOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "You are reserving food for TOMORROW'S lunch break.",
                    style: TextStyle(color: Colors.deepOrange.shade800, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Available Menu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          // Menu List
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text('₱${item['price'].toStringAsFixed(2)} • ${item['category']}'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        // Add to global Cart Provider
                        context.read<BentoCartProvider>().addItem(item);

                        // Clear any existing SnackBars immediately before showing a new one
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();

                        // Show SnackBar that disappears after 5 seconds
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added ${item['name']} to Bento Box!'),
                            action: SnackBarAction(
                              label: 'UNDO',
                              onPressed: () {
                                // Real app would have a remove logic here
                              },
                            ),
                          ),
                        );
                      },
                      child: const Text('Add'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Floating Cart Button
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepOrange,
        onPressed: () {
          // Navigate to the Cart Screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartScreen()),
          );
        },
        icon: const Icon(Icons.shopping_cart, color: Colors.white),
        label: Text(
          'Cart ($cartCount)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}