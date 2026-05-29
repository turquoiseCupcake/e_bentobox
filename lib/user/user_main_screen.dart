import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'user_home_screen.dart';
import 'user_orders_screen.dart';
import 'user_settings_screen.dart';

class UserMainScreen extends StatefulWidget {
  const UserMainScreen({super.key});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  int _currentIndex = 0;
  late IO.Socket socket;
  String? currentUserId;

  final List<Widget> _screens = [
    const UserHomeScreen(),
    const UserOrdersScreen(),
    const UserSettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  Future<void> _initSocket() async {
    // 1. Get the current logged-in user's ID
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString('userId');

    // 2. Connect to the VPS WebSocket
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://13.250.200.60:3000';
    
    socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build());

    socket.connect();

    socket.onConnect((_) {
      print('Connected to live notifications server!');
    });

    // 3. Listen for order status updates
    socket.on('order_status_update', (data) {
      // Check if this update belongs to the logged-in student
      if (data['userId'] == currentUserId) {
        _showNotificationBanner(data['status']);
      }
    });
  }

  void _showNotificationBanner(String status) {
    if (!mounted) return;
    
    Color bannerColor = Colors.orange;
    IconData icon = Icons.info_outline;
    
    if (status == 'Accepted') {
      bannerColor = Colors.green;
      icon = Icons.check_circle;
    } else if (status == 'Ready' || status == 'Ready for Pickup') {
      bannerColor = Colors.deepOrange;
      icon = Icons.room_service;
    } else if (status == 'Rejected') {
      bannerColor = Colors.red;
      icon = Icons.cancel;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Order Update: Your Bento Box is now $status!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: bannerColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
        dismissDirection: DismissDirection.up, // Drops from the top!
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Colors.orange;

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: primaryColor,
            unselectedItemColor: Colors.grey.shade400,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: 'Explore',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                activeIcon: Icon(Icons.calendar_month),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}