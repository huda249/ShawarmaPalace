import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
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
          seedColor: const Color(0xFFB71C1C),
          primary: const Color(0xFFB71C1C),
          secondary: const Color(0xFFFFB300),
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

/// Main screen displaying the seeded restaurant menu from SQLite.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State createState() => _HomeScreenState();
}

class _HomeScreenState extends State {
  List _foodItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  /// Loads all seeded food items from the local SQLite database.
  Future _loadMenu() async {
    final items = await DatabaseHelper.instance.getAllFoodItems();
    setState(() {
      _foodItems = items;
      _isLoading = false;
    });
  }

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _foodItems.length,
        itemBuilder: (context, index) {
          final item = _foodItems[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
              child: Text('${index + 1}'),
            ),
            title: Text(item['name']),
            trailing: Text(
              '\$${(item['cost'] as num).toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          );
        },
      ),
    );
  }
}