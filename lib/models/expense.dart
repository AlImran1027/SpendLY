import 'package:cloud_firestore/cloud_firestore.dart';

import 'extracted_receipt_data.dart';

// ─── ExpenseItem ──────────────────────────────────────────────────────────────

class ExpenseItem {
  final String name;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  const ExpenseItem({
    required this.name,
    this.quantity = 1.0,
    required this.unitPrice,
    required this.subtotal,
  });

  Map<String, dynamic> toFirestoreMap() => {
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'subtotal': subtotal,
      };

  factory ExpenseItem.fromFirestoreMap(Map<String, dynamic> m) => ExpenseItem(
        name: m['name'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unitPrice: (m['unitPrice'] as num).toDouble(),
        subtotal: (m['subtotal'] as num).toDouble(),
      );

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
  final String? id;
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

  // ── Firestore ───────────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'merchantName': merchantName,
        'category': category,
        'totalAmount': totalAmount,
        'date': Timestamp.fromDate(date),
        'paymentMethod': paymentMethod,
        'notes': notes,
        'imagePath': imagePath,
        if (aiConfidence != null) 'aiConfidence': aiConfidence,
        'createdAt': Timestamp.fromDate(createdAt),
        'modifiedAt': Timestamp.fromDate(modifiedAt),
        'items': items.map((i) => i.toFirestoreMap()).toList(),
      };

  factory Expense.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return Expense(
      id: doc.id,
      merchantName: m['merchantName'] as String? ?? '',
      category: m['category'] as String? ?? '',
      totalAmount: (m['totalAmount'] as num?)?.toDouble() ?? 0.0,
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentMethod: m['paymentMethod'] as String? ?? 'Cash',
      notes: m['notes'] as String? ?? '',
      imagePath: m['imagePath'] as String? ?? '',
      aiConfidence: m['aiConfidence'] != null
          ? (m['aiConfidence'] as num).toDouble()
          : null,
      createdAt:
          (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      modifiedAt:
          (m['modifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: (m['items'] as List<dynamic>? ?? [])
          .map((i) => ExpenseItem.fromFirestoreMap(i as Map<String, dynamic>))
          .toList(),
    );
  }

  // ── Cross-model helpers ──────────────────────────────────────────────────────

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

  Expense copyWith({
    String? id,
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
