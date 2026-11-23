import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_helper.dart';

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

/// Main screen for setting a daily budget, selecting food, and saving plans.
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

  double get _targetBudget => double.tryParse(_budgetController.text) ?? 0.0;

  double get _currentTotal {
    double total = 0.0;
    for (final item in _foodItems) {
      if (_selectedIds.contains(item['id'])) {
        total += (item['cost'] as num).toDouble();
      }
    }
    return total;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

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

  /// Saves the selected food items and date into the local SQLite database.
  Future _saveOrderPlan() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one food item first.')),
      );
      return;
    }

    final selectedNames = _foodItems
        .where((item) => _selectedIds.contains(item['id']))
        .map((item) => '${item['name']} (\$${(item['cost'] as num).toStringAsFixed(2)})')
        .join(', ');

    final dateStr = _formatDate(_selectedDate);
    await DatabaseHelper.instance.insertOrderPlan(dateStr, selectedNames, _currentTotal);

    setState(() {
      _selectedIds.clear();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order plan saved for $dateStr!'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formatDate(_selectedDate);

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
        actions: [
          IconButton(
            tooltip: 'View & Query Order Plans',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderPlansScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB71C1C),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saveOrderPlan,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Order Plan'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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

/// Screen to query order plans by date and list all plans descending by date.
class OrderPlansScreen extends StatefulWidget {
  const OrderPlansScreen({super.key});

  @override
  State createState() => _OrderPlansScreenState();
}

class _OrderPlansScreenState extends State {
  List _allPlans = [];
  List _queryResults = [];
  String? _searchedDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllPlans();
  }

  /// Loads all saved order plans ordered by date descending.
  Future _loadAllPlans() async {
    final plans = await DatabaseHelper.instance.getAllOrderPlans();
    setState(() {
      _allPlans = plans;
      _isLoading = false;
    });
  }

  /// Picks a date and queries the local database for matching order plans.
  Future _searchByDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      final dateStr =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      final results = await DatabaseHelper.instance.getOrderPlansByDate(dateStr);
      setState(() {
        _searchedDate = dateStr;
        _queryResults = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Order Plans')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Query Section
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _searchByDate,
                  icon: const Icon(Icons.search),
                  label: const Text('Query by Date'),
                ),
                const SizedBox(width: 12),
                if (_searchedDate != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchedDate = null;
                        _queryResults = [];
                      });
                    },
                    child: const Text('Clear Search'),
                  ),
              ],
            ),
            if (_searchedDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Query Result for $_searchedDate:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              if (_queryResults.isEmpty)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('No order plan found for $_searchedDate.'),
                  ),
                )
              else
                ..._queryResults.map((plan) => Card(
                  color: Colors.green.shade50,
                  child: ListTile(
                    title: Text('Date: ${plan['date']} — Total: \$${(plan['total_cost'] as num).toStringAsFixed(2)}'),
                    subtitle: Text(plan['items']),
                  ),
                )),
              const Divider(height: 24),
            ],

            // All Order Plans (Ordered by Date Descending)
            const Text(
              'All Order Plans (Newest First):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _allPlans.isEmpty
                  ? const Center(child: Text('No order plans saved yet.'))
                  : ListView.builder(
                itemCount: _allPlans.length,
                itemBuilder: (context, index) {
                  final plan = _allPlans[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long, color: Color(0xFFB71C1C)),
                      title: Text(
                        '${plan['date']}  •  \$${(plan['total_cost'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(plan['items']),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}