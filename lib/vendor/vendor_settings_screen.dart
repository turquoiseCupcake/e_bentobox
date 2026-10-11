import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth/login_screen.dart';
import 'vendor_edit_profile_screen.dart';

class VendorSettingsScreen extends StatefulWidget {
  const VendorSettingsScreen({super.key});

  @override
  State<VendorSettingsScreen> createState() => _VendorSettingsScreenState();
}

class _VendorSettingsScreenState extends State<VendorSettingsScreen> {
  String _storeName = 'Carenderia Vendor';
  String _vendorEmail = 'vendor@carenderia.com';
  String _operatingHours = 'Mon-Fri 8AM-7PM';
  bool _orderChime = true;
  bool _autoPrintHints = true;
  String? _vendorId;
  Map<String, dynamic> _vendorData = {};

  // Invariant 6: Vendor Role Theming
  static const Color primaryColor = Color(0xFFE91E63); // Deep Pink
  static const Color primaryLight = Color(0xFFFCE4EC);

  @override
  void initState() {
    super.initState();
    _loadVendorPreferences();
  }

  Map<String, dynamic> _getResolvedVendorData() {
    return {
      'id': _vendorData['id'] ?? _vendorId,
      'store_name': _storeName,
      'email': _vendorEmail,
      'operating_hours': _operatingHours,
      'description': _vendorData['description'] ?? '',
      'location_description': _vendorData['location_description'] ?? '',
      'latitude': _vendorData['latitude'],
      'longitude': _vendorData['longitude'],
      'profile_image_url': _vendorData['profile_image_url'] ?? '',
      'cover_image_url': _vendorData['cover_image_url'] ?? '',
      ..._vendorData,
    };
  }

  Future<void> _loadVendorPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vendorId = prefs.getString('userId');
      _storeName = prefs.getString('userName') ?? 'Carenderia Vendor';
      _vendorEmail = prefs.getString('userEmail') ?? 'vendor@carenderia.com';
      _orderChime = prefs.getBool('vendor_order_chime') ?? true;
      _autoPrintHints = prefs.getBool('vendor_print_hints') ?? true;
    });

    // Also fetch fresh operating hours from server if available
    final vendorId = prefs.getString('userId');
    if (vendorId != null) {
      try {
        final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://54.254.206.248:3000';
        final res = await http.get(Uri.parse('$baseUrl/api/vendors/$vendorId'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success'] == true && data['vendor'] != null) {
            final v = data['vendor'];
            _vendorData = Map<String, dynamic>.from(v);
            setState(() {
              if (v['store_name'] != null) _storeName = v['store_name'];
              if (v['email'] != null) _vendorEmail = v['email'];
              if (v['operating_hours'] != null) _operatingHours = v['operating_hours'];
            });
            await prefs.setString('userName', _storeName);
            await prefs.setString('userEmail', _vendorEmail);
          }
        }
      } catch (_) {
        // Silently use cached values if offline
      }
    }
  }

  Future<void> _togglePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'vendor_order_chime') _orderChime = value;
      if (key == 'vendor_print_hints') _autoPrintHints = value;
    });
  }

  // --- CHANGE PASSWORD DIALOG ---
  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: primaryColor),
                SizedBox(width: 8),
                Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: oldPasswordController,
                      obscureText: obscureOld,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        suffixIcon: IconButton(
                          icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password (min 6 chars)',
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v != newPasswordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final dialogNav = Navigator.of(ctx);

                        try {
                          final prefs = await SharedPreferences.getInstance();
                          final userId = prefs.getString('userId');
                          final role = prefs.getString('userRole') ?? 'Vendor';
                          final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://54.254.206.248:3000';

                          final response = await http.put(
                            Uri.parse('$baseUrl/api/change-password'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'userId': userId,
                              'role': role,
                              'oldPassword': oldPasswordController.text,
                              'newPassword': newPasswordController.text,
                            }),
                          );

                          final data = jsonDecode(response.body);
                          if (!mounted) return;
                          if (response.statusCode == 200 && data['success'] == true) {
                            dialogNav.pop();
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Password updated successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(data['message'] ?? 'Failed to update password'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text('Network error updating password.'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          setDialogState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Update'),
              ),
            ],
          );
        });
      },
    );
  }

  // --- LOG OUT CONFIRMATION ---
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your carenderia vendor account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  // --- A4 QR PRINTING RUNBOOK MODAL ---
  void _showQrRunbookDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: primaryColor),
            SizedBox(width: 8),
            Text('A4 QR Sticker Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How the Cryptographic QR Loop Works:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                '1. Go to your Orders Dashboard and tap the Print icon to generate a 24-up A4 sheet of unique QR stickers.',
                style: TextStyle(fontSize: 12.5, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                '2. Print on standard sticker paper or cut and tape them to your takeout bento boxes before packing meals.',
                style: TextStyle(fontSize: 12.5, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                '3. When packing an order, tap "Scan & Mark Ready" and scan the container sticker. This binds the physical box to the digital student order!',
                style: TextStyle(fontSize: 12.5, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                '4. When the student arrives, they scan that sticker to confirm pickup.',
                style: TextStyle(fontSize: 12.5, color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        title: const Text('Vendor Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // --- STORE HEADER CARD ---
          _buildStoreHeaderCard(),
          const SizedBox(height: 24),

          // --- STORE OPERATIONS & PROFILE ---
          _buildSectionTitle('STORE OPERATIONS'),
          const SizedBox(height: 8),
          _buildCardGroup([
            _buildSettingsTile(
              icon: Icons.storefront_rounded,
              title: 'Edit Store Profile & GPS Pin',
              subtitle: 'Update cover photo, bio, and map location',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VendorEditProfileScreen(vendorData: _getResolvedVendorData()),
                  ),
                );
                _loadVendorPreferences();
              },
            ),
            _buildSettingsTile(
              icon: Icons.access_time_rounded,
              title: 'Operating Hours',
              subtitle: _operatingHours,
              trailing: const Text('Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VendorEditProfileScreen(vendorData: _getResolvedVendorData()),
                  ),
                );
                _loadVendorPreferences();
              },
            ),
            _buildSwitchTile(
              icon: Icons.notifications_active_outlined,
              title: 'New Order Audio Chimes',
              subtitle: 'Play chime on incoming next-day orders',
              value: _orderChime,
              onChanged: (val) => _togglePreference('vendor_order_chime', val),
            ),
            _buildSwitchTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'QR Packing Scan Prompts',
              subtitle: 'Show scan hints when packaging meals',
              value: _autoPrintHints,
              onChanged: (val) => _togglePreference('vendor_print_hints', val),
            ),
          ]),
          const SizedBox(height: 24),

          // --- ACCOUNT & SECURITY SECTION ---
          _buildSectionTitle('ACCOUNT SECURITY'),
          const SizedBox(height: 8),
          _buildCardGroup([
            _buildSettingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              subtitle: 'Update carenderia login credentials',
              onTap: _showChangePasswordDialog,
            ),
            _buildSettingsTile(
              icon: Icons.print_outlined,
              title: 'A4 QR Sticker Printing Runbook',
              subtitle: 'Learn how to generate and bind box stickers',
              onTap: _showQrRunbookDialog,
            ),
          ]),
          const SizedBox(height: 24),

          // --- SYSTEM & DIAGNOSTICS ---
          _buildSectionTitle('SYSTEM & CLOUD VPS'),
          const SizedBox(height: 8),
          _buildCardGroup([
            _buildSettingsTile(
              icon: Icons.cloud_done_rounded,
              title: 'AWS Cloud Server Connection',
              subtitle: 'Connected to AWS Lightsail (Port 3000)',
              trailing: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'About E-Bentobox Merchant',
              subtitle: 'Version 1.2.0 • Carenderia Partner Portal',
              trailing: const Text('v1.2.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 32),

          // --- LOG OUT BUTTON ---
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade700,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red.shade200),
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log Out of Carenderia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            onPressed: _confirmLogout,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1),
      ),
    );
  }

  Widget _buildStoreHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: primaryLight,
            child: const Icon(Icons.storefront_rounded, size: 36, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _storeName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _vendorEmail,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Carenderia Vendor • Active',
                    style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: List.generate(children.length, (index) {
            return Column(
              children: [
                children[index],
                if (index < children.length - 1)
                  Divider(height: 1, indent: 56, endIndent: 16, color: Colors.grey.shade200),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primaryColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primaryColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      activeThumbColor: primaryColor,
      value: value,
      onChanged: onChanged,
    );
  }
}