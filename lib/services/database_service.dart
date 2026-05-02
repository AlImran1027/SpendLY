import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/expense.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No authenticated user');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _expenses =>
      _db.collection('users').doc(_uid).collection('expenses');

  CollectionReference<Map<String, dynamic>> get _budgets =>
      _db.collection('users').doc(_uid).collection('budgets');

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD — Expenses
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String> insertExpense(Expense expense) async {
    final doc = await _expenses.add(expense.toFirestore());
    return doc.id;
  }

  Future<List<Expense>> getExpenses() async {
    final snap =
        await _expenses.orderBy('date', descending: true).get();
    return snap.docs.map((d) => Expense.fromFirestore(d)).toList();
  }

  Future<List<Expense>> getRecentExpenses({int limit = 5}) async {
    final snap = await _expenses
        .orderBy('date', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => Expense.fromFirestore(d)).toList();
  }

  Future<Expense?> getExpenseById(String id) async {
    final doc = await _expenses.doc(id).get();
    if (!doc.exists) return null;
    return Expense.fromFirestore(doc);
  }

  Future<void> updateExpense(Expense expense) async {
    assert(expense.id != null, 'Cannot update an expense without an id');
    await _expenses.doc(expense.id).update(expense.toFirestore());
  }

  Future<void> deleteExpense(String id) async {
    await _expenses.doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANALYTICS QUERIES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Expense>> _getExpensesForMonth(int year, int month) async {
    final start = Timestamp.fromDate(DateTime(year, month, 1));
    final end = Timestamp.fromDate(DateTime(year, month + 1, 1));
    final snap = await _expenses
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .get();
    return snap.docs.map((d) => Expense.fromFirestore(d)).toList();
  }

  Future<double> getMonthlyTotal(int year, int month) async {
    final expenses = await _getExpensesForMonth(year, month);
    return expenses.fold<double>(0.0, (sum, e) => sum + e.totalAmount);
  }

  Future<Map<String, double>> getCategoryTotals(int year, int month) async {
    final expenses = await _getExpensesForMonth(year, month);
    final totals = <String, double>{};
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.totalAmount;
    }
    return totals;
  }

  Future<Map<String, double>> getDailyTotals(
      DateTime from, DateTime to) async {
    final start = Timestamp.fromDate(from);
    final end = Timestamp.fromDate(to.add(const Duration(days: 1)));
    final snap = await _expenses
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .get();
    final totals = <String, double>{};
    for (final doc in snap.docs) {
      final e = Expense.fromFirestore(doc);
      final day = e.date.toIso8601String().substring(0, 10);
      totals[day] = (totals[day] ?? 0) + e.totalAmount;
    }
    return totals;
  }

  Future<int> getExpenseCount() async {
    final snap = await _expenses.count().get();
    return snap.count ?? 0;
  }

  Future<int> getDistinctCategoryCount() async {
    final snap = await _expenses.get();
    final categories = snap.docs
        .map((d) => d.data()['category'] as String? ?? '')
        .toSet();
    return categories.where((c) => c.isNotEmpty).length;
  }

  Future<double> getAverageDailySpend() async {
    final now = DateTime.now();
    final total = await getMonthlyTotal(now.year, now.month);
    return total / now.day;
  }

  Future<double> getHighestExpense() async {
    final snap = await _expenses
        .orderBy('totalAmount', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return 0.0;
    return (snap.docs.first.data()['totalAmount'] as num?)?.toDouble() ?? 0.0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, double>> getBudgets(int year, int month) async {
    final snap = await _budgets
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .get();
    return {
      for (final d in snap.docs)
        d.data()['category'] as String: (d.data()['amount'] as num).toDouble(),
    };
  }

  Future<void> upsertBudget(
      String category, int year, int month, double amount) async {
    final docId = '${category}_${year}_$month';
    await _budgets.doc(docId).set({
      'category': category,
      'year': year,
      'month': month,
      'amount': amount,
    });
  }

  Future<int> getBudgetCount(int year, int month) async {
    final snap = await _budgets
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .count()
        .get();
    return snap.count ?? 0;
  }
}
