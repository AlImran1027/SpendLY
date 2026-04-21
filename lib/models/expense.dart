/// Expense and ExpenseItem models — the canonical persisted data structures.
///
/// These map 1-to-1 with the SQLite tables and are the source of truth for
/// all screens. Helper methods convert to/from [ExtractedReceiptData] so the
/// existing AI-extraction screens continue to work unchanged.
library;

import 'extracted_receipt_data.dart';

// ─── ExpenseItem ──────────────────────────────────────────────────────────────

class ExpenseItem {
  final int? id;
  final int? expenseId;
  final String name;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  const ExpenseItem({
    this.id,
    this.expenseId,
    required this.name,
    this.quantity = 1.0,
    required this.unitPrice,
    required this.subtotal,
  });

  // ── SQLite ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap({int? expenseId}) => {
        if (id != null) 'id': id,
        'expense_id': expenseId ?? this.expenseId,
        'name': name,
        'quantity': quantity,
        'unit_price': unitPrice,
        'subtotal': subtotal,
      };

  factory ExpenseItem.fromMap(Map<String, dynamic> m) => ExpenseItem(
        id: m['id'] as int?,
        expenseId: m['expense_id'] as int?,
        name: m['name'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unitPrice: (m['unit_price'] as num).toDouble(),
        subtotal: (m['subtotal'] as num).toDouble(),
      );

  // ── Cross-model helpers ──────────────────────────────────────────────────────

  ExtractedItem toExtractedItem() => ExtractedItem(
        name: name,
        quantity: quantity,
        unitPrice: unitPrice,
        subtotal: subtotal,
      );

  factory ExpenseItem.fromExtractedItem(ExtractedItem e) => ExpenseItem(
        name: e.name,
        quantity: e.quantity,
        unitPrice: e.unitPrice,
        subtotal: e.subtotal,
      );
}

// ─── Expense ──────────────────────────────────────────────────────────────────

class Expense {
  final int? id;
  final String merchantName;
  final String category;
  final double totalAmount;
  final DateTime date;
  final String paymentMethod;
  final String notes;
  final String imagePath;
  final double? aiConfidence;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final List<ExpenseItem> items;

  const Expense({
    this.id,
    required this.merchantName,
    required this.category,
    required this.totalAmount,
    required this.date,
    this.paymentMethod = 'Cash',
    this.notes = '',
    this.imagePath = '',
    this.aiConfidence,
    required this.createdAt,
    required this.modifiedAt,
    this.items = const [],
  });

  // ── SQLite ──────────────────────────────────────────────────────────────────

  /// Converts to a map for the `expenses` table (items excluded — stored
  /// separately in `expense_items`).
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'merchant_name': merchantName,
        'category': category,
        'total_amount': totalAmount,
        'date': date.toIso8601String(),
        'payment_method': paymentMethod,
        'notes': notes,
        'image_path': imagePath,
        'ai_confidence': aiConfidence,
        'created_at': createdAt.toIso8601String(),
        'modified_at': modifiedAt.toIso8601String(),
      };

  factory Expense.fromMap(Map<String, dynamic> m,
      {List<ExpenseItem> items = const []}) {
    return Expense(
      id: m['id'] as int?,
      merchantName: m['merchant_name'] as String,
      category: m['category'] as String,
      totalAmount: (m['total_amount'] as num).toDouble(),
      date: DateTime.parse(m['date'] as String),
      paymentMethod: m['payment_method'] as String? ?? 'Cash',
      notes: m['notes'] as String? ?? '',
      imagePath: m['image_path'] as String? ?? '',
      aiConfidence: m['ai_confidence'] != null
          ? (m['ai_confidence'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(m['created_at'] as String),
      modifiedAt: DateTime.parse(m['modified_at'] as String),
      items: items,
    );
  }

  // ── Cross-model helpers ──────────────────────────────────────────────────────

  /// Converts to [ExtractedReceiptData] for screens that still use that type.
  ExtractedReceiptData toExtractedReceiptData() => ExtractedReceiptData(
        merchantName: merchantName,
        date: date,
        totalAmount: totalAmount,
        items: items.map((i) => i.toExtractedItem()).toList(),
        category: category,
        paymentMethod: paymentMethod,
        imagePath: imagePath,
      );

  factory Expense.fromExtractedReceiptData(
    ExtractedReceiptData data, {
    String notes = '',
    double? aiConfidence,
  }) {
    final now = DateTime.now();
    return Expense(
      merchantName: data.merchantName,
      category: data.category,
      totalAmount: data.totalAmount,
      date: data.date ?? now,
      paymentMethod: data.paymentMethod,
      notes: notes,
      imagePath: data.imagePath,
      aiConfidence: aiConfidence,
      createdAt: now,
      modifiedAt: now,
      items: data.items.map(ExpenseItem.fromExtractedItem).toList(),
    );
  }

  /// Returns a copy with the given fields replaced.
  Expense copyWith({
    int? id,
    String? merchantName,
    String? category,
    double? totalAmount,
    DateTime? date,
    String? paymentMethod,
    String? notes,
    String? imagePath,
    double? aiConfidence,
    DateTime? createdAt,
    DateTime? modifiedAt,
    List<ExpenseItem>? items,
  }) {
    return Expense(
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      category: category ?? this.category,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      items: items ?? this.items,
    );
  }
}
