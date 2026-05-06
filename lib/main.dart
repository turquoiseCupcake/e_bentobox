import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import 'bento_cart_provider.dart'; // Import your new provider

void main() {
  runApp(
    // 1. Wrap your app in a ChangeNotifierProvider
    ChangeNotifierProvider(
      create: (context) => BentoCartProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Bentobox',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const DummyMenuScreen(),
    );
  }
}

class DummyMenuScreen extends StatelessWidget {
  const DummyMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // context.watch listens for changes so the UI updates automatically
    final cartCount = context.watch<BentoCartProvider>().itemCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carenderia Menu'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text('Cart: $cartCount', style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // context.read calls the function without listening for UI redraws
            context.read<BentoCartProvider>().addItem('Pork Sisig');
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Added Pork Sisig to Bento!')),
            );
          },
          child: const Text('+ Add Pork Sisig'),
        ),
      ),
    );
  }
}