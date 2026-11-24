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

/// Main screen for managing food items, setting a daily budget, and saving plans.
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

  /// Loads all food items from the local SQLite database.
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

  /// Opens a dialog to add a new food item or update an existing one.
  Future _showFoodDialog({Map? existingItem}) async {
    final nameController = TextEditingController(
      text: existingItem != null ? existingItem['name'] : '',
    );
    final costController = TextEditingController(
      text: existingItem != null ? (existingItem['cost'] as num).toStringAsFixed(2) : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existingItem == null ? 'Add Food Item' : 'Update Food Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Food Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cost (\$)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final cost = double.tryParse(costController.text.trim());
              if (name.isEmpty || cost == null || cost < 0) return;

              if (existingItem == null) {
                await DatabaseHelper.instance.insertFoodItem(name, cost);
              } else {
                await DatabaseHelper.instance.updateFoodItem(existingItem['id'] as int, name, cost);
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadMenu();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Deletes a food item from the database and refreshes the list.
  Future _deleteFood(int id) async {
    await DatabaseHelper.instance.deleteFoodItem(id);
    _selectedIds.remove(id);
    _loadMenu();
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        tooltip: 'Add Food Item',
        onPressed: () => _showFoodDialog(),
        child: const Icon(Icons.add),
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
              padding: const EdgeInsets.only(bottom: 72),
              itemCount: _foodItems.length,
              itemBuilder: (context, index) {
                final item = _foodItems[index];
                final isSelected = _selectedIds.contains(item['id']);
                return ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFFB71C1C),
                    onChanged: (_) => _toggleItem(item),
                  ),
                  title: Text(item['name']),
                  subtitle: Text('\$${(item['cost'] as num).toStringAsFixed(2)}'),
                  onTap: () => _toggleItem(item),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit Food Item',
                        icon: const Icon(Icons.edit, color: Colors.blueGrey),
                        onPressed: () => _showFoodDialog(existingItem: item),
                      ),
                      IconButton(
                        tooltip: 'Delete Food Item',
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteFood(item['id'] as int),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen to query, edit, delete, and list all saved order plans descending by date.
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

  /// Opens a dialog to update a saved order plan's date, items, or total cost.
  Future _editOrderPlanDialog(Map plan) async {
    final dateController = TextEditingController(text: plan['date']);
    final itemsController = TextEditingController(text: plan['items']);
    final totalController = TextEditingController(
      text: (plan['total_cost'] as num).toStringAsFixed(2),
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Order Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dateController,
              decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: itemsController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Food Items'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: totalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Total Cost (\$)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final date = dateController.text.trim();
              final items = itemsController.text.trim();
              final total = double.tryParse(totalController.text.trim());
              if (date.isEmpty || items.isEmpty || total == null) return;

              await DatabaseHelper.instance.updateOrderPlan(
                plan['id'] as int,
                date,
                items,
                total,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadAllPlans();
              if (_searchedDate != null) {
                final refreshed = await DatabaseHelper.instance.getOrderPlansByDate(_searchedDate!);
                setState(() => _queryResults = refreshed);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  /// Deletes a saved order plan from the local database.
  Future _deleteOrderPlan(int id) async {
    await DatabaseHelper.instance.deleteOrderPlan(id);
    _loadAllPlans();
    if (_searchedDate != null) {
      final refreshed = await DatabaseHelper.instance.getOrderPlansByDate(_searchedDate!);
      setState(() => _queryResults = refreshed);
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
                    title: Text(
                      'Date: ${plan['date']} — Total: \$${(plan['total_cost'] as num).toStringAsFixed(2)}',
                    ),
                    subtitle: Text(plan['items']),
                  ),
                )),
              const Divider(height: 24),
            ],
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit Order Plan',
                            icon: const Icon(Icons.edit, color: Colors.blueGrey),
                            onPressed: () => _editOrderPlanDialog(plan),
                          ),
                          IconButton(
                            tooltip: 'Delete Order Plan',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteOrderPlan(plan['id'] as int),
                          ),
                        ],
                      ),
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