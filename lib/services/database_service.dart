/// DatabaseService — singleton SQLite layer for Spendly.
///
/// Tables:
///   expenses        — one row per expense (header data)
///   expense_items   — one row per line item, FK to expenses.id
///
/// Usage:
///   final db = DatabaseService.instance;
///   final id  = await db.insertExpense(expense);
///   final all = await db.getExpenses();
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'spendly.db';
  static const _dbVersion = 2;

  // Table / column names
  static const _tExpenses = 'expenses';
  static const _tItems = 'expense_items';
  static const _tBudgets = 'budgets';

  Database? _db;

  // ─── Open ─────────────────────────────────────────────────────────────────

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tExpenses (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant_name  TEXT    NOT NULL,
        category       TEXT    NOT NULL,
        total_amount   REAL    NOT NULL,
        date           TEXT    NOT NULL,
        payment_method TEXT    NOT NULL DEFAULT 'Cash',
        notes          TEXT    NOT NULL DEFAULT '',
        image_path     TEXT    NOT NULL DEFAULT '',
        ai_confidence  REAL,
        created_at     TEXT    NOT NULL,
        modified_at    TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tItems (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_id  INTEGER NOT NULL,
        name        TEXT    NOT NULL,
        quantity    REAL    NOT NULL DEFAULT 1.0,
        unit_price  REAL    NOT NULL DEFAULT 0.0,
        subtotal    REAL    NOT NULL,
        FOREIGN KEY (expense_id) REFERENCES $_tExpenses(id) ON DELETE CASCADE
      )
    ''');

    // Index for fast date-range queries used by analytics / budget.
    await db.execute(
        'CREATE INDEX idx_expenses_date ON $_tExpenses(date)');
    await db.execute(
        'CREATE INDEX idx_items_expense_id ON $_tItems(expense_id)');

    await _createBudgetsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createBudgetsTable(db);
    }
  }

  Future<void> _createBudgetsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tBudgets (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        category  TEXT    NOT NULL,
        year      INTEGER NOT NULL,
        month     INTEGER NOT NULL,
        amount    REAL    NOT NULL,
        UNIQUE(category, year, month)
      )
    ''');
  }

  // ─── Close (for testing) ──────────────────────────────────────────────────

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD — Expenses
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inserts [expense] (with its items) in a single transaction.
  /// Returns the new row's id.
  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    int newId = 0;

    await db.transaction((txn) async {
      newId = await txn.insert(_tExpenses, expense.toMap()); // Insert the expense header, get the new id.
      for (final item in expense.items) {
        await txn.insert(_tItems, item.toMap(expenseId: newId)); // Insert each item with the new expenseId as FK.
      }
    });

    return newId;
  }

  /// Returns all expenses sorted newest-first, each with its items.
  Future<List<Expense>> getExpenses() async {// Used by the "All Expenses" screen.
    final db = await database; 
    final rows = await db.query( // Get all expenses, sorted by date (newest first).
      _tExpenses,
      orderBy: 'date DESC, created_at DESC',
    );
    return _attachItems(db, rows); 
  }

  /// Returns the [limit] most-recent expenses (for the home dashboard).
  Future<List<Expense>> getRecentExpenses({int limit = 5}) async {
    final db = await database;
    final rows = await db.query(
      _tExpenses,
      orderBy: 'date DESC, created_at DESC',
      limit: limit,
    );
    return _attachItems(db, rows);
  }

  /// Returns a single expense by [id], or null if not found.
  Future<Expense?> getExpenseById(int id) async {
    final db = await database;
    final rows = await db.query(
      _tExpenses,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final items = await _itemsFor(db, id);
    return Expense.fromMap(rows.first, items: items);
  }

  /// Updates an existing expense and replaces its items.
  Future<void> updateExpense(Expense expense) async {
    assert(expense.id != null, 'Cannot update an expense without an id');
    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        _tExpenses,
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );
      // Replace items
      await txn.delete(
        _tItems,
        where: 'expense_id = ?',
        whereArgs: [expense.id],
      );
      for (final item in expense.items) {
        await txn.insert(_tItems, item.toMap(expenseId: expense.id));
      }
    });
  }

  /// Deletes an expense and all its items (CASCADE also handles items via FK).
  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete(_tExpenses, where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANALYTICS QUERIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Total amount spent in a given [year]/[month].
  Future<double> getMonthlyTotal(int year, int month) async {
    final db = await database;
    final start = _monthStart(year, month);
    final end = _monthEnd(year, month);
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) AS total '
      'FROM $_tExpenses WHERE date >= ? AND date <= ?',
      [start, end],
    );
    return (result.first['total'] as num).toDouble();
  }

  /// Sum per category for a given [year]/[month].
  /// Returns a map of category → total.
  Future<Map<String, double>> getCategoryTotals(int year, int month) async {
    final db = await database;
    final start = _monthStart(year, month);
    final end = _monthEnd(year, month);
    final rows = await db.rawQuery(
      'SELECT category, COALESCE(SUM(total_amount), 0) AS total '
      'FROM $_tExpenses WHERE date >= ? AND date <= ? '
      'GROUP BY category',
      [start, end],
    );
    return {
      for (final r in rows)
        r['category'] as String: (r['total'] as num).toDouble(),
    };
  }

  /// Returns spending grouped by day for a date range (for bar chart).
  /// Map key is "YYYY-MM-DD".
  Future<Map<String, double>> getDailyTotals(
      DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT substr(date, 1, 10) AS day, "
      "COALESCE(SUM(total_amount), 0) AS total "
      'FROM $_tExpenses '
      'WHERE date >= ? AND date <= ? '
      'GROUP BY day '
      'ORDER BY day',
      [from.toIso8601String(), to.toIso8601String()],
    );
    return {
      for (final r in rows)
        r['day'] as String: (r['total'] as num).toDouble(),
    };
  }

  /// Total number of expenses in the DB.
  Future<int> getExpenseCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS cnt FROM $_tExpenses');
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Total number of distinct categories used.
  Future<int> getDistinctCategoryCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(DISTINCT category) AS cnt FROM $_tExpenses');
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Average daily spend for the current month (total ÷ days elapsed so far).
  Future<double> getAverageDailySpend() async {
    final now = DateTime.now();
    final total = await getMonthlyTotal(now.year, now.month);
    final daysElapsed = now.day; // 1-based, always >= 1
    return total / daysElapsed;
  }

  /// Highest single expense amount ever recorded.
  Future<double> getHighestExpense() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COALESCE(MAX(total_amount), 0) AS max_amt FROM $_tExpenses');
    return (result.first['max_amt'] as num).toDouble();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns all budget amounts for a given [year]/[month].
  /// Map key is category name, value is the budget amount.
  Future<Map<String, double>> getBudgets(int year, int month) async {
    final db = await database;
    final rows = await db.query(
      _tBudgets,
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
    );
    return {
      for (final r in rows)
        r['category'] as String: (r['amount'] as num).toDouble(),
    };
  }

  /// Inserts or updates the budget for [category] in the given [year]/[month].
  Future<void> upsertBudget(
      String category, int year, int month, double amount) async {
    final db = await database;
    await db.rawInsert(
      'INSERT INTO $_tBudgets (category, year, month, amount) VALUES (?, ?, ?, ?) '
      'ON CONFLICT(category, year, month) DO UPDATE SET amount = excluded.amount',
      [category, year, month, amount],
    );
  }

  /// Returns the count of categories with a budget set for [year]/[month].
  Future<int> getBudgetCount(int year, int month) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $_tBudgets WHERE year = ? AND month = ?',
      [year, month],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<ExpenseItem>> _itemsFor(Database db, int expenseId) async {
    final rows = await db.query(
      _tItems,
      where: 'expense_id = ?',
      whereArgs: [expenseId],
      orderBy: 'id',
    );
    return rows.map(ExpenseItem.fromMap).toList();
  }

  Future<List<Expense>> _attachItems(
      Database db, List<Map<String, dynamic>> rows) async {
    final expenses = <Expense>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final items = await _itemsFor(db, id);
      expenses.add(Expense.fromMap(row, items: items));
    }
    return expenses;
  }

  String _monthStart(int year, int month) =>
      DateTime(year, month, 1).toIso8601String();

  String _monthEnd(int year, int month) =>
      DateTime(year, month + 1, 1)
          .subtract(const Duration(seconds: 1))
          .toIso8601String();
}
