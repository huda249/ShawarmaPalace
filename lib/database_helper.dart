import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Handles SQLite database creation, seeding, and CRUD operations for food items and order plans.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Returns the existing database or opens/creates a new one.
  Future get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shawarma_palace.db');
    return _database!;
  }

  Future _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  /// Creates tables and seeds 20 initial food items on first install.
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE food_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        cost REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE order_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        items TEXT NOT NULL,
        total_cost REAL NOT NULL
      )
    ''');

    final initialMenu = [
      {'name': 'Chicken Shawarma Wrap', 'cost': 9.99},
      {'name': 'Beef Shawarma Wrap', 'cost': 10.99},
      {'name': 'Mixed Shawarma Wrap', 'cost': 11.49},
      {'name': 'Falafel Wrap', 'cost': 8.49},
      {'name': 'Chicken Shawarma Platter', 'cost': 16.99},
      {'name': 'Beef Shawarma Platter', 'cost': 17.99},
      {'name': 'Mixed Shawarma Platter', 'cost': 18.99},
      {'name': 'Falafel Platter', 'cost': 14.99},
      {'name': 'Chicken on the Rocks', 'cost': 13.99},
      {'name': 'Beef on the Rocks', 'cost': 14.99},
      {'name': 'Chicken on the Sticks', 'cost': 13.99},
      {'name': 'Lentil Soup', 'cost': 5.49},
      {'name': 'Fattoush Salad', 'cost': 7.99},
      {'name': 'Tabbouleh Salad', 'cost': 7.49},
      {'name': 'Hummus with Pita', 'cost': 6.99},
      {'name': 'Baba Ganoush with Pita', 'cost': 7.49},
      {'name': 'Garlic Potatoes', 'cost': 6.49},
      {'name': 'Crispy French Fries', 'cost': 4.99},
      {'name': 'Baklava (2 pcs)', 'cost': 3.99},
      {'name': 'Mango Juice', 'cost': 3.49},
    ];

    for (final item in initialMenu) {
      await db.insert('food_items', item);
    }
  }

  // ---------------- FOOD ITEMS CRUD ----------------

  /// Fetches all food items from the local database.
  Future getAllFoodItems() async {
    final db = await instance.database;
    return await db.query('food_items', orderBy: 'id ASC');
  }

  /// Adds a new food item to the menu table.
  Future insertFoodItem(String name, double cost) async {
    final db = await instance.database;
    return await db.insert('food_items', {'name': name, 'cost': cost});
  }

  /// Updates an existing food item's name and cost.
  Future updateFoodItem(int id, String name, double cost) async {
    final db = await instance.database;
    return await db.update(
      'food_items',
      {'name': name, 'cost': cost},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a food item by its ID.
  Future deleteFoodItem(int id) async {
    final db = await instance.database;
    return await db.delete('food_items', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- ORDER PLANS CRUD ----------------

  /// Inserts a new saved order plan into the local database.
  Future insertOrderPlan(String date, String items, double totalCost) async {
    final db = await instance.database;
    return await db.insert('order_plans', {
      'date': date,
      'items': items,
      'total_cost': totalCost,
    });
  }

  /// Fetches all saved order plans ordered by date descending.
  Future getAllOrderPlans() async {
    final db = await instance.database;
    return await db.query('order_plans', orderBy: 'date DESC, id DESC');
  }

  /// Queries saved order plans matching a specific date (YYYY-MM-DD).
  Future getOrderPlansByDate(String date) async {
    final db = await instance.database;
    return await db.query(
      'order_plans',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'id DESC',
    );
  }

  /// Updates an existing saved order plan.
  Future updateOrderPlan(int id, String date, String items, double totalCost) async {
    final db = await instance.database;
    return await db.update(
      'order_plans',
      {'date': date, 'items': items, 'total_cost': totalCost},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a saved order plan by its ID.
  Future deleteOrderPlan(int id) async {
    final db = await instance.database;
    return await db.delete('order_plans', where: 'id = ?', whereArgs: [id]);
  }
}