import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EditMenuItemScreen extends StatefulWidget {
  final Map<String, dynamic> item; // Receive the item data from the menu screen

  const EditMenuItemScreen({super.key, required this.item});

  @override
  State<EditMenuItemScreen> createState() => _EditMenuItemScreenState();
}

class _EditMenuItemScreenState extends State<EditMenuItemScreen> {
  final Color primaryColor = const Color(0xFFE91E63);
  
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  
  late String _selectedCategory;
  late bool _isAvailable;
  late String _currentImageUrl;
  
  final List<String> _categories = ['Ulam', 'Rice', 'Drinks', 'Dessert', 'Combo'];
  File? _newImageFile;
  bool _isLoading = false;
  late String _baseUrl;

  @override
  void initState() {
    super.initState();
    _baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    
    // Pre-fill existing data
    _nameController = TextEditingController(text: widget.item['name']);
    _priceController = TextEditingController(text: widget.item['price'].toString());
    _descriptionController = TextEditingController(text: widget.item['description'] ?? '');
    
    // Ensure category exists in list, otherwise default to first
    _selectedCategory = _categories.contains(widget.item['category']) 
        ? widget.item['category'] 
        : _categories.first;
        
    _isAvailable = widget.item['is_available'] ?? true;
    _currentImageUrl = widget.item['image_url'] ?? '';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);

    if (pickedFile != null) {
      setState(() {
        _newImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String finalImageUrl = _currentImageUrl;

      // If they picked a NEW image, upload it first
      if (_newImageFile != null) {
        var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/upload'));
        request.files.add(await http.MultipartFile.fromPath('image', _newImageFile!.path));
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        var responseData = jsonDecode(response.body);

        if (response.statusCode == 200 && responseData['success']) {
          finalImageUrl = responseData['imageUrl'];
        } else {
          throw Exception('Failed to upload new image');
        }
      }

      // Send the PUT request with updated data
      final response = await http.put(
        Uri.parse('$_baseUrl/api/menu-items/${widget.item['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text,
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'category': _selectedCategory,
          'description': _descriptionController.text,
          'is_available': _isAvailable,
          'image_url': finalImageUrl,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item Updated!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update failed.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem() async {
    // Show confirmation dialog first
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: const Text('This will permanently remove the item from your menu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/api/menu-items/${widget.item['id']}'));
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item Deleted')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed.'), backgroundColor: Colors.red));
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
        title: Text('Edit Menu Item', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteItem,
          )
        ],
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
                    // Image Section
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300),
                            image: _newImageFile != null
                                ? DecorationImage(image: FileImage(_newImageFile!), fit: BoxFit.cover)
                                : (_currentImageUrl.isNotEmpty
                                    ? DecorationImage(image: NetworkImage('$_baseUrl$_currentImageUrl'), fit: BoxFit.cover)
                                    : null),
                          ),
                          child: _newImageFile == null && _currentImageUrl.isEmpty
                              ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(child: Text('Tap photo to change', style: TextStyle(color: Colors.grey, fontSize: 12))),
                    const SizedBox(height: 24),

                    // Availability Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Available Today', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          Switch(
                            value: _isAvailable,
                            activeColor: primaryColor,
                            onChanged: (val) => setState(() => _isAvailable = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Food Name', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                      validator: (val) => val!.isEmpty ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: 'Price (₱)', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                            validator: (val) => val!.isEmpty ? 'Enter price' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: InputDecoration(labelText: 'Category', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                            items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: 'Description (Optional)', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    ),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: _updateItem,
                        child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}