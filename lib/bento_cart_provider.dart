import 'package:flutter/material.dart';

// ChangeNotifier tells Flutter to listen for updates
class BentoCartProvider extends ChangeNotifier {
  // Our temporary dummy data (List of food item names)
  final List<String> _cartItems = [];

  // A way for our UI to read the items
  List<String> get cartItems => _cartItems;

  // A way for our UI to get the total item count
  int get itemCount => _cartItems.length;

  // Function to add an item to the bento box
  void addItem(String itemName) {
    _cartItems.add(itemName);
    
    // This is the magic line! It yells "HEY, UI! I CHANGED! REDRAW!"
    notifyListeners(); 
  }

  // Function to clear the cart after a successful mock checkout
  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }
}