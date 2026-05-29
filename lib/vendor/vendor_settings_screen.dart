import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';

class VendorSettingsScreen extends StatelessWidget {
  const VendorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFFE91E63);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('Settings', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsTile(Icons.notifications_outlined, 'Push Notifications', true),
          _buildSettingsTile(Icons.dark_mode_outlined, 'Dark Mode', false),
          _buildSettingsTile(Icons.security, 'Change Password', false),
          _buildSettingsTile(Icons.help_outline, 'Help & Support', false),
          const SizedBox(height: 40),
          
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              // Clear the saved session data
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (!context.mounted) return;

              // Navigate back to Login and clear the navigation stack
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, bool hasSwitch) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey.shade700),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: hasSwitch 
            ? Switch(value: true, onChanged: (val) {}, activeColor: const Color(0xFFE91E63))
            : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {},
      ),
    );
  }
}