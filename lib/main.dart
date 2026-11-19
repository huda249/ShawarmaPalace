import 'package:flutter/material.dart';

void main() {
  runApp(const RestaurantApp());
}

/// Root widget that configures the restaurant's name and color theme.
class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shawarma Palace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB71C1C), // Deep Red
          primary: const Color(0xFFB71C1C),
          secondary: const Color(0xFFFFB300), // Warm Gold
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFB71C1C),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Main landing screen for the food ordering app.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu),
            SizedBox(width: 8),
            Text('Shawarma Palace'),
          ],
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood, size: 80, color: Color(0xFFB71C1C)),
            SizedBox(height: 16),
            Text(
              'Welcome to Shawarma Palace',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Plan your daily meal order within your budget.'),
          ],
        ),
      ),
    );
  }
}