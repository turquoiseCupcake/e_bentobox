import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // You may need to run `flutter pub add intl` for date formatting
import '../main.dart';
import 'payment_screen.dart'; // Import the new Payment Screen

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Read the cart state
    final cartProvider = context.watch<BentoCartProvider>();
    final cartItems = cartProvider.cartItems;
    final totalPrice = cartProvider.totalPrice;
    final selectedDate = cartProvider.reservationDate;

    // Logic for tomorrow's date
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Your Bento Box', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
      ),
      body: cartItems.isEmpty
          ? const Center(
              child: Text(
                'Your Bento Box is empty!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                // Date Selection Card
                Card(
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month, color: Colors.orange),
                    title: Text(
                      selectedDate == null 
                          ? 'Select Pickup Date' 
                          : 'Pickup: ${DateFormat('EEE, MMM d, yyyy').format(selectedDate)}', // Requires intl package
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Reservations are next-day only.'),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      // Date Picker strictly clamped to Tomorrow onwards
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: tomorrow,
                        firstDate: tomorrow,
                        lastDate: tomorrow.add(const Duration(days: 14)), // Max 2 weeks ahead
                      );
                      if (pickedDate != null) {
                        context.read<BentoCartProvider>().setReservationDate(pickedDate);
                      }
                    },
                  ),
                ),

                // Cart Items List
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      
                      // Check if item is still available
                      final bool isAvailable = item['is_available'] ?? true;
                      final bool isAvailableTomorrow = item['is_available_tomorrow'] ?? true;
                      final bool canOrder = isAvailable && isAvailableTomorrow;

                      return Dismissible(
                        key: UniqueKey(), // Allows swipe-to-delete
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          context.read<BentoCartProvider>().removeItem(index);
                        },
                        child: ListTile(
                          title: Text(
                            item['name'], 
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: canOrder ? TextDecoration.none : TextDecoration.lineThrough,
                              color: canOrder ? Colors.black87 : Colors.grey,
                            )
                          ),
                          subtitle: canOrder 
                              ? null 
                              : const Text('This item is no longer available', style: TextStyle(color: Colors.red, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₱${item['price'].toStringAsFixed(2)}', style: TextStyle(fontSize: 16, color: canOrder ? Colors.black87 : Colors.grey)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Remove item',
                                onPressed: () {
                                  context.read<BentoCartProvider>().removeItem(index);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Total and Checkout
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('₱${totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cartProvider.hasUnavailableItems ? Colors.red : Colors.orange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: (selectedDate == null || cartProvider.hasUnavailableItems) 
                                ? null // Disable button if no date selected OR if an item is unavailable
                                : () {
                                    // Navigate to the real Mock Payment Screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const PaymentScreen()),
                                    );
                                  },
                            child: Text(
                              cartProvider.hasUnavailableItems 
                                  ? 'Remove unavailable items' 
                                  : 'Proceed to Checkout', 
                              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}