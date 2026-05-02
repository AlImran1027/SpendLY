import 'package:cloud_firestore/cloud_firestore.dart';

import 'expense.dart';

// ─── SplitRecipient ───────────────────────────────────────────────────────────

class SplitRecipient {
  final String uid;
  final String email;
  final String name;

  /// 'pending' | 'accepted' | 'rejected' | 'dismissed'
  final String status;

  const SplitRecipient({
    required this.uid,
    required this.email,
    required this.name,
    required this.status,
  });

  factory SplitRecipient.fromMap(Map<String, dynamic> map) => SplitRecipient(
        uid: map['uid'] as String? ?? '',
        email: map['email'] as String? ?? '',
        name: map['name'] as String? ?? '',
        status: map['status'] as String? ?? 'pending',
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'name': name,
        'status': status,
      };

  SplitRecipient copyWith({String? status}) => SplitRecipient(
        uid: uid,
        email: email,
        name: name,
        status: status ?? this.status,
      );
}

// ─── SplitRequest ─────────────────────────────────────────────────────────────

class SplitRequest {
  final String? id;
  final String initiatorUid;
  final String initiatorEmail;
  final String initiatorName;
  final String merchant;
  final String category;
  final DateTime date;
  final String paymentMethod;
  final String notes;
  final String imagePath;
  final double originalTotal;
  final int splitCount;
  final double amountPerPerson;
  final DateTime createdAt;

  /// Set by retrySplit so recipients get a fresh notification on each retry.
  final DateTime? retriedAt;

  /// True once the initiator's expense share has been saved to SQLite.
  /// Prevents double-saving when all recipients accept or initiator dismisses.
  final bool initiatorExpenseSaved;

  /// Preserved from the original receipt extraction for later expense creation.
  final double? aiConfidence;

  /// Serialised receipt line-items stored so they can be attached to the
  /// initiator's expense once the split is fully accepted or dismissed.
  final List<Map<String, dynamic>> itemMaps;

  /// Flat list of recipient UIDs — used for Firestore array-contains queries.
  final List<String> recipientUids;

  /// Map of uid → SplitRecipient (status tracking).
  final Map<String, SplitRecipient> recipients;

  const SplitRequest({
    this.id,
    required this.initiatorUid,
    required this.initiatorEmail,
    required this.initiatorName,
    required this.merchant,
    required this.category,
    required this.date,
    required this.paymentMethod,
    required this.notes,
    required this.imagePath,
    required this.originalTotal,
    required this.splitCount,
    required this.amountPerPerson,
    required this.createdAt,
    this.retriedAt,
    this.initiatorExpenseSaved = false,
    this.aiConfidence,
    this.itemMaps = const [],
    required this.recipientUids,
    required this.recipients,
  });

  factory SplitRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final recipientsRaw = data['recipients'] as Map<String, dynamic>? ?? {};
    final recipients = recipientsRaw.map(
      (k, v) => MapEntry(k, SplitRecipient.fromMap(v as Map<String, dynamic>)),
    );

    final rawItems = data['items'] as List? ?? [];
    final itemMaps = rawItems
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return SplitRequest(
      id: doc.id,
      initiatorUid: data['initiatorUid'] as String? ?? '',
      initiatorEmail: data['initiatorEmail'] as String? ?? '',
      initiatorName: data['initiatorName'] as String? ?? '',
      merchant: data['merchant'] as String? ?? '',
      category: data['category'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentMethod: data['paymentMethod'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      imagePath: data['imagePath'] as String? ?? '',
      originalTotal: (data['originalTotal'] as num?)?.toDouble() ?? 0,
      splitCount: (data['splitCount'] as num?)?.toInt() ?? 1,
      amountPerPerson: (data['amountPerPerson'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      retriedAt: (data['retriedAt'] as Timestamp?)?.toDate(),
      initiatorExpenseSaved: data['initiatorExpenseSaved'] as bool? ?? false,
      aiConfidence: (data['aiConfidence'] as num?)?.toDouble(),
      itemMaps: itemMaps,
      recipientUids:
          List<String>.from(data['recipientUids'] as List? ?? []),
      recipients: recipients,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'initiatorUid': initiatorUid,
        'initiatorEmail': initiatorEmail,
        'initiatorName': initiatorName,
        'merchant': merchant,
        'category': category,
        'date': Timestamp.fromDate(date),
        'paymentMethod': paymentMethod,
        'notes': notes,
        'imagePath': imagePath,
        'originalTotal': originalTotal,
        'splitCount': splitCount,
        'amountPerPerson': amountPerPerson,
        'createdAt': Timestamp.fromDate(createdAt),
        if (retriedAt != null) 'retriedAt': Timestamp.fromDate(retriedAt!),
        'initiatorExpenseSaved': initiatorExpenseSaved,
        if (aiConfidence != null) 'aiConfidence': aiConfidence,
        'items': itemMaps,
        'recipientUids': recipientUids,
        'recipients': recipients.map((k, v) => MapEntry(k, v.toMap())),
      };

  /// True when every recipient has accepted — triggers expense save for initiator.
  bool get allAccepted =>
      recipients.isNotEmpty &&
      recipients.values.every((r) => r.status == 'accepted');

  /// Deserialises stored item maps back into [ExpenseItem] instances.
  List<ExpenseItem> get expenseItems => itemMaps.map((m) {
        final qty = (m['quantity'] as num?)?.toDouble() ?? 1.0;
        final unit = (m['unitPrice'] as num?)?.toDouble() ?? 0.0;
        return ExpenseItem(
          name: m['name'] as String? ?? '',
          quantity: qty,
          unitPrice: unit,
          subtotal: (m['subtotal'] as num?)?.toDouble() ?? qty * unit,
        );
      }).toList();

  /// All recipient names whose status matches [status].
  List<String> namesWithStatus(String status) => recipients.values
      .where((r) => r.status == status)
      .map((r) => r.name.isNotEmpty ? r.name : r.email)
      .toList();
}
