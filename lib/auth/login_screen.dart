import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../user/user_main_screen.dart';
import '../vendor/vendor_main_screen.dart';
import 'register_screen.dart'; // Import the Register Screen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isVendor = false; // Toggle between Student and Vendor

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://13.250.200.60:3000';
      
      // The role is determined by the toggle switch on the UI
      final String role = _isVendor ? 'Vendor' : 'User'; // Note: Changed to 'User' to match backend expectation

      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String userId = data['user']['id'];

        // Save session to phone storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userId);
        await prefs.setString('userRole', role);

        if (!mounted) return;
        
        // --- NAVIGATION LOGIC ---
        if (role == 'Vendor') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const VendorMainScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UserMainScreen()), 
          );
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic theme: Pink for vendors, Orange for users
    final primaryColor = _isVendor ? const Color(0xFFE91E63) : Colors.orange;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/app_icon.png', width: 80, height: 80),
                const SizedBox(height: 16),
                Text('E-Bentobox', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor)),
                const SizedBox(height: 32),

                // Role Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Student', style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: _isVendor,
                      activeColor: const Color(0xFFE91E63),
                      inactiveThumbColor: Colors.orange,
                      inactiveTrackColor: Colors.orange.shade200,
                      onChanged: (val) => setState(() => _isVendor = val),
                    ),
                    const Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val!.isEmpty || !val.contains('@') ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val!.isEmpty ? 'Enter your password' : null,
                ),
                const SizedBox(height: 32),

                _isLoading
                    ? CircularProgressIndicator(color: primaryColor)
                    : Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _login,
                              child: const Text('Log In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Registration Text Button
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterScreen()),
                              );
                            },
                            child: Text(
                              "Don't have an account? Register here",
                              style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}