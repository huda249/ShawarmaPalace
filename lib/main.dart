import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Keeps Windows desktop working alongside Android/iOS
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

/// Main screen for setting a daily budget, picking a date, and selecting food.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State createState() => _HomeScreenState();
}

class _HomeScreenState extends State {
  List _foodItems = [];
  final Set _selectedIds = {};
  final TextEditingController _budgetController = TextEditingController(text: '25.00');
  DateTime _selectedDate = DateTime.now();
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

  /// Parses the user's target daily budget safely.
  double get _targetBudget {
    return double.tryParse(_budgetController.text) ?? 0.0;
  }

  /// Calculates the total cost of all currently checked food items.
  double get _currentTotal {
    double total = 0.0;
    for (final item in _foodItems) {
      if (_selectedIds.contains(item['id'])) {
        total += (item['cost'] as num).toDouble();
      }
    }
    return total;
  }

  /// Opens the calendar date picker dialog.
  Future _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Toggles a food item selection and prevents exceeding the target budget.
  void _toggleItem(Map item) {
    final int id = item['id'] as int;
    final double cost = (item['cost'] as num).toDouble();

    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        // Check if adding this item exceeds the target cost
        if (_currentTotal + cost > _targetBudget + 0.001) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot add ${item['name']}: exceeds target budget of \$${_targetBudget.toStringAsFixed(2)}!',
              ),
              backgroundColor: Colors.red.shade800,
            ),
          );
        } else {
          _selectedIds.add(id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

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
          : Column(
        children: [
          // Budget & Date Control Panel
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.amber.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _budgetController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Target Cost per Day (\$)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(formattedDate),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected: ${_selectedIds.length} items',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Total: \$${_currentTotal.toStringAsFixed(2)} / \$${_targetBudget.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFFB71C1C),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Menu Selection List
          Expanded(
            child: ListView.builder(
              itemCount: _foodItems.length,
              itemBuilder: (context, index) {
                final item = _foodItems[index];
                final isSelected = _selectedIds.contains(item['id']);
                return CheckboxListTile(
                  value: isSelected,
                  activeColor: const Color(0xFFB71C1C),
                  onChanged: (_) => _toggleItem(item),
                  title: Text(item['name']),
                  subtitle: Text('\$${(item['cost'] as num).toStringAsFixed(2)}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}