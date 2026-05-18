import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NEW IMPORT

class AddMenuItemScreen extends StatefulWidget {
  const AddMenuItemScreen({super.key});

  @override
  State<AddMenuItemScreen> createState() => _AddMenuItemScreenState();
}

class _AddMenuItemScreenState extends State<AddMenuItemScreen> {
  final Color primaryColor = const Color(0xFFE91E63);
  
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _selectedCategory = 'Ulam';
  final List<String> _categories = ['Ulam', 'Rice', 'Drinks', 'Dessert', 'Combo'];

  File? _imageFile;
  bool _isLoading = false;

  // Function to pick an image from the gallery and compress it
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // imageQuality: 70 compresses the image so it doesn't overload your VPS
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Function to upload the image and save the menu item
  Future<void> _saveMenuItem() async {
    if (!_formKey.currentState!.validate() || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select an image.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final baseUrl = dotenv.env['API_BASE_URL'];
      
      // ---------------------------------------------------------
      // 1. Upload the Image via Multipart Request
      // ---------------------------------------------------------
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload'));
      request.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        final String imageUrl = responseData['imageUrl']; 
        
        // ---------------------------------------------------------
        // 2. Fetch the dynamic Vendor ID from local storage
        // ---------------------------------------------------------
        final prefs = await SharedPreferences.getInstance();
        final String? currentVendorId = prefs.getString('userId');

        if (currentVendorId == null) {
          throw Exception('No logged-in user found. Please log in again.');
        }

        // Send the real, dynamic ID to PostgreSQL!
        final itemResponse = await http.post(
          Uri.parse('$baseUrl/api/menu-items'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'vendor_id': currentVendorId,
            'name': _nameController.text,
            'price': double.tryParse(_priceController.text) ?? 0.0,
            'category': _selectedCategory,
            'image_url': imageUrl,
          }),
        );

        final itemData = jsonDecode(itemResponse.body);

        if (itemResponse.statusCode == 200 && itemData['success']) {
          print('✅ Item fully saved to database: ${itemData['item']['name']}');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Item Added Successfully!'), backgroundColor: Colors.green),
            );
            Navigator.pop(context); // Go back to menu screen
          }
        } else {
          throw Exception('Failed to save menu item details');
        }

      } else {
        throw Exception('Image upload failed');
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload item. Check connection.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('Add Menu Item', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Picker Widget
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                            image: _imageFile != null
                                ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: _imageFile == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, size: 40, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text('Tap to upload food photo', style: TextStyle(color: Colors.grey.shade500)),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Input Fields
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Food Name',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      validator: (val) => val!.isEmpty ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Price (₱)',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            validator: (val) => val!.isEmpty ? 'Enter price' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _saveMenuItem,
                        child: const Text('Save Menu Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}