import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth/login_screen.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  String _userName = 'Juan Student';
  String _userEmail = 'student@nemsu.edu.ph';
  bool _notifyOrders = true;
  bool _notifySound = true;
  int _strikeCount = 0;
  bool _isBanned = false;

  // Invariant 6: Student Warm Orange Theme
  static const Color primaryColor = Colors.orange;
  static final Color primaryLight = Colors.orange.shade50;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'Juan Student';
      _userEmail = prefs.getString('userEmail') ?? 'student@nemsu.edu.ph';
      _notifyOrders = prefs.getBool('pref_notify_orders') ?? true;
      _notifySound = prefs.getBool('pref_notify_sound') ?? true;
    });

    final String? userId = prefs.getString('userId');
    if (userId != null) {
      _fetchAccountStanding(userId);
    }
  }

  Future<void> _fetchAccountStanding(String userId) async {
    try {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://54.254.206.248:3000';
      final res = await http.get(Uri.parse('$baseUrl/api/users/$userId/standing'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['user'] != null) {
          if (mounted) {
            setState(() {
              _strikeCount = (data['user']['strike_count'] as num?)?.toInt() ?? 0;
              _isBanned = data['user']['is_banned'] == true;
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching student account standing: $e');
    }
  }

  Future<void> _togglePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'pref_notify_orders') _notifyOrders = value;
      if (key == 'pref_notify_sound') _notifySound = value;
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
                          final role = prefs.getString('userRole') ?? 'User';
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
        content: const Text('Are you sure you want to log out of your student account?'),
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

  // --- POLICY & GUIDELINES MODALS ---
  void _showPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: primaryColor),
            SizedBox(width: 8),
            Text('Campus Dining Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_isBanned || _strikeCount > 0) ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_isBanned || _strikeCount > 0) ? Colors.red.shade200 : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (_isBanned || _strikeCount > 0) ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                      color: (_isBanned || _strikeCount > 0) ? Colors.red.shade700 : Colors.green.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_isBanned || _strikeCount > 0) ? 'Account Status: Suspended' : 'Account Status: Clean Standing',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: (_isBanned || _strikeCount > 0) ? Colors.red.shade900 : Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (_isBanned || _strikeCount > 0)
                                ? '$_strikeCount Strike(s) recorded. Advance ordering privileges are locked due to an uncollected meal. Please visit administration to resolve.'
                                : '0 Strikes recorded. You have full privileges to reserve advance bento boxes.',
                            style: TextStyle(
                              fontSize: 11,
                              color: (_isBanned || _strikeCount > 0) ? Colors.red.shade800 : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '1. Advance Next-Day Orders:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'All reservations must be made at least one day in advance. Same-day ordering is disabled to ensure cooks buy exact ingredients without waste.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              const Text(
                '2. The One-Strike Anti-Abandonment Rule:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Carenderias prepare meals specifically for pre-orders. Failing to claim and pay for your advance bento box results in an account strike. Delinquent accounts are barred from placing future reservations.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              const Text(
                '3. Contactless QR Claiming:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Scan the physical QR sticker on your box at the carenderia counter to authenticate and complete your pickup.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showFaqDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Help & FAQs', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Q: What time is pickup?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('A: Standard lunch window is 11:30 AM – 1:30 PM at the respective carenderia counter.', style: TextStyle(fontSize: 12, color: Colors.black87)),
              SizedBox(height: 10),
              Text('Q: How do I pay?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('A: You can pay via GCash, Maya, or cash upon counter claiming.', style: TextStyle(fontSize: 12, color: Colors.black87)),
              SizedBox(height: 10),
              Text('Q: What if the carenderia is out of stock?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('A: Because you order in advance, portions are guaranteed and reserved before morning cooking.', style: TextStyle(fontSize: 12, color: Colors.black87)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // --- PROFILE HEADER CARD ---
          _buildProfileHeaderCard(),
          const SizedBox(height: 24),

          // --- ACCOUNT & SECURITY SECTION ---
          _buildSectionTitle('ACCOUNT & SECURITY'),
          const SizedBox(height: 8),
          _buildCardGroup([
            _buildSettingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              subtitle: 'Update your account login password',
              onTap: _showChangePasswordDialog,
            ),
            _buildSettingsTile(
              icon: (_isBanned || _strikeCount > 0) ? Icons.error_outline_rounded : Icons.verified_user_outlined,
              title: 'Account Standing & Strikes',
              subtitle: (_isBanned || _strikeCount > 0)
                  ? '$_strikeCount Strike${_strikeCount > 1 ? "s" : ""} • Suspended'
                  : '0 Strikes • Account in Good Standing',
              trailing: Icon(
                (_isBanned || _strikeCount > 0) ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                color: (_isBanned || _strikeCount > 0) ? Colors.red : Colors.green,
                size: 20,
              ),
              onTap: _showPolicyDialog,
            ),
          ]),
          const SizedBox(height: 24),

          // --- PREFERENCES SECTION ---
          _buildSectionTitle('PREFERENCES & NOTIFICATIONS'),
          const SizedBox(height: 8),
          _buildCardGroup([
            _buildSwitchTile(
              icon: Icons.notifications_active_outlined,
              title: 'Order Status Alerts',
              subtitle: 'Get notified when bento is ready for pickup',
              value: _notifyOrders,
              onChanged: (val) => _togglePreference('pref_notify_orders', val),
            ),
            _buildSwitchTile(
              icon: Icons.volume_up_outlined,
              title: 'Sound & Vibrate',
              subtitle: 'Audio chime on live status push updates',
              value: _notifySound,
              onChanged: (val) => _togglePreference('pref_notify_sound', val),
            ),
            _buildSettingsTile(
              icon: Icons.schedule_rounded,
              title: 'Campus Lunch Window',
              subtitle: 'Standard pickup: 11:30 AM – 1:30 PM',
              trailing: const Text('NEMSU', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 12)),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 24),

          // --- INFORMATION & HELP SECTION ---
          _buildSectionTitle('SUPPORT & INFORMATION'),
          const SizedBox(height: 8),
          _buildCardGroup([
            _buildSettingsTile(
              icon: Icons.help_outline_rounded,
              title: 'Help Center & FAQs',
              subtitle: 'Pickup guidelines, payments, and answers',
              onTap: _showFaqDialog,
            ),
            _buildSettingsTile(
              icon: Icons.policy_outlined,
              title: 'Dining Policy & Rules',
              subtitle: 'Advance reservation & one-strike protocol',
              onTap: _showPolicyDialog,
            ),
            _buildSettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'About E-Bentobox',
              subtitle: 'Version 1.2.0 • Campus Dining Platform',
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
            label: const Text('Log Out of Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildProfileHeaderCard() {
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
            child: const Icon(Icons.person_rounded, size: 36, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _userEmail,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Student / Diner',
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