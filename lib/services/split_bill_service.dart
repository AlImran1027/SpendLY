// Firestore security rules required (paste into Firebase Console → Firestore → Rules):
//
// match /userProfiles/{uid} {
//   allow read: if request.auth != null;
//   allow write: if request.auth.uid == uid;
// }
// match /splitRequests/{splitId} {
//   allow read: if request.auth != null && (
//     resource.data.initiatorUid == request.auth.uid ||
//     resource.data.recipientUids.hasAny([request.auth.uid])
//   );
//   allow create: if request.auth != null;
//   allow update: if request.auth != null && (
//     resource.data.initiatorUid == request.auth.uid ||
//     resource.data.recipientUids.hasAny([request.auth.uid])
//   );
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/expense.dart';
import '../models/split_request.dart';
import '../models/user_profile.dart';
import 'database_service.dart';

class SplitBillService {
  SplitBillService._();
  static final SplitBillService instance = SplitBillService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ═══════════════════════════════════════════════════════════════════════════
  // USER PROFILE & FCM TOKEN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Upserts the current user's profile — including the current FCM token —
  /// into the global userProfiles collection so other users can discover them
  /// by email and so Cloud Functions can send them FCM notifications.
  Future<void> saveCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (_) {}

    await _db.collection('userProfiles').doc(user.uid).set({
      'uid': user.uid,
      'email': (user.email ?? '').toLowerCase().trim(),
      'displayName': user.displayName ?? '',
      'fcmToken': ?fcmToken,
    }, SetOptions(merge: true));
  }

  /// Refreshes the FCM token in Firestore whenever Firebase issues a new one.
  /// Call once at startup after the user is authenticated.
  Future<void> updateFcmToken() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db
            .collection('userProfiles')
            .doc(uid)
            .update({'fcmToken': token});
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMAIL SEARCH
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns up to 8 profiles whose email starts with [query], excluding the
  /// current user. Requires `userProfiles` to store email in lowercase.
  Future<List<UserProfile>> searchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final snap = await _db
        .collection('userProfiles')
        .where('email', isGreaterThanOrEqualTo: q)
        .where('email', isLessThan: '${q}z')
        .limit(8)
        .get();
    final currentUid = _uid;
    return snap.docs
        .map((d) => UserProfile.fromFirestore(d))
        .where((u) => u.uid != currentUid)
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREATE SPLIT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates a splitRequest document in Firestore. The initiator's expense is
  /// NOT saved here — it is saved only once all recipients accept (or when the
  /// initiator explicitly dismisses remaining rejections).
  Future<void> createSplitRequest({
    required String merchant,
    required String category,
    required DateTime date,
    required String paymentMethod,
    required String notes,
    required String imagePath,
    required double? aiConfidence,
    required List<ExpenseItem> items,
    required double originalTotal,
    required List<UserProfile> recipients,
    int? splitCount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No authenticated user');

    final effectiveSplitCount = splitCount ?? (recipients.length + 1);
    final amountPerPerson = originalTotal / effectiveSplitCount;
    final now = DateTime.now();

    final recipientsMap = {
      for (final r in recipients)
        r.uid: {
          'uid': r.uid,
          'email': r.email,
          'name': r.displayName,
          'status': 'pending',
        },
    };

    final itemMaps = items.map((i) => i.toFirestoreMap()).toList();

    await _db.collection('splitRequests').add({
      'initiatorUid': user.uid,
      'initiatorEmail': user.email ?? '',
      'initiatorName': user.displayName ?? '',
      'merchant': merchant,
      'category': category,
      'date': Timestamp.fromDate(date),
      'paymentMethod': paymentMethod,
      'notes': notes,
      'imagePath': imagePath,
      'originalTotal': originalTotal,
      'splitCount': effectiveSplitCount,
      'amountPerPerson': amountPerPerson,
      'createdAt': Timestamp.fromDate(now),
      'initiatorExpenseSaved': false,
      'aiConfidence': ?aiConfidence,
      'items': itemMaps,
      'recipientUids': recipients.map((r) => r.uid).toList(),
      'recipients': recipientsMap,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUERIES — one-shot
  // ═══════════════════════════════════════════════════════════════════════════

  /// Splits where the current user is a recipient with status 'pending'.
  ///
  /// NOTE: orderBy is intentionally omitted here to avoid requiring a composite
  /// Firestore index (recipientUids array-contains + createdAt). Results are
  /// sorted client-side instead.
  Future<List<SplitRequest>> getPendingSplitsForMe() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _db
          .collection('splitRequests')
          .where('recipientUids', arrayContains: uid)
          .get();
      final results = snap.docs
          .map((d) => SplitRequest.fromFirestore(d))
          .where((s) => s.recipients[uid]?.status == 'pending')
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results;
    } catch (e) {
      debugPrint('SplitBillService.getPendingSplitsForMe error: $e');
      return [];
    }
  }

  /// Splits the current user initiated that have at least one 'rejected'
  /// recipient (not yet dismissed by the initiator).
  ///
  /// orderBy omitted to avoid requiring a composite Firestore index.
  Future<List<SplitRequest>> getSplitsWithRejections() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _db
          .collection('splitRequests')
          .where('initiatorUid', isEqualTo: uid)
          .get();
      final results = snap.docs
          .map((d) => SplitRequest.fromFirestore(d))
          .where((s) => s.recipients.values.any((r) => r.status == 'rejected'))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results;
    } catch (e) {
      debugPrint('SplitBillService.getSplitsWithRejections error: $e');
      return [];
    }
  }

  /// Splits initiated by the current user where every recipient has accepted
  /// but the initiator's expense has not yet been saved locally.
  Future<List<SplitRequest>> getFullyAcceptedSplitsForInitiator() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _db
          .collection('splitRequests')
          .where('initiatorUid', isEqualTo: uid)
          .where('initiatorExpenseSaved', isEqualTo: false)
          .get();
      return snap.docs
          .map((d) => SplitRequest.fromFirestore(d))
          .where((s) => s.allAccepted)
          .toList();
    } catch (e) {
      debugPrint('SplitBillService.getFullyAcceptedSplitsForInitiator error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REAL-TIME STREAM
  // ═══════════════════════════════════════════════════════════════════════════

  /// Live stream of split requests where the current user is a pending recipient.
  ///
  /// orderBy omitted to avoid the composite Firestore index requirement.
  /// Results are sorted newest-first in the stream map.
  Stream<List<SplitRequest>> watchPendingSplitsForMe() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('splitRequests')
        .where('recipientUids', arrayContains: uid)
        .snapshots()
        .map((snap) {
          final results = snap.docs
              .map((d) => SplitRequest.fromFirestore(d))
              .where((s) => s.recipients[uid]?.status == 'pending')
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return results;
        });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECIPIENT ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Accepts a split: creates the expense for the current user and marks their
  /// status as 'accepted'.
  Future<void> acceptSplit(SplitRequest split) async {
    final uid = _uid;
    if (uid == null) return;
    final now = DateTime.now();

    final fromLabel = split.initiatorName.isNotEmpty
        ? split.initiatorName
        : split.initiatorEmail;
    final expense = Expense(
      merchantName: split.merchant,
      category: split.category,
      totalAmount: split.amountPerPerson,
      date: split.date,
      paymentMethod: split.paymentMethod,
      notes: split.notes.isEmpty
          ? 'Split with $fromLabel'
          : '${split.notes} (Split with $fromLabel)',
      imagePath: split.imagePath,
      aiConfidence: null,
      createdAt: now,
      modifiedAt: now,
      items: const [],
    );
    await DatabaseService.instance.insertExpense(expense);

    await _db
        .collection('splitRequests')
        .doc(split.id)
        .update({'recipients.$uid.status': 'accepted'});
  }

  /// Rejects a split: updates the recipient's status to 'rejected' without
  /// creating an expense. The initiator will see a rejection banner.
  Future<void> rejectSplit(SplitRequest split) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('splitRequests')
        .doc(split.id)
        .update({'recipients.$uid.status': 'rejected'});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIATOR ACTIONS (after a rejection)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Resets all 'rejected' recipients back to 'pending' and bumps [retriedAt]
  /// so recipients receive a fresh push notification on their next load.
  Future<void> retrySplit(SplitRequest split) async {
    final updates = <String, dynamic>{
      'retriedAt': Timestamp.now(),
    };
    for (final entry in split.recipients.entries) {
      if (entry.value.status == 'rejected') {
        updates['recipients.${entry.key}.status'] = 'pending';
      }
    }
    await _db.collection('splitRequests').doc(split.id).update(updates);
  }

  /// Marks all 'rejected' recipients as 'dismissed' and saves the initiator's
  /// expense share (even though not everyone accepted).
  Future<void> dismissRejection(SplitRequest split) async {
    final updates = <String, dynamic>{};
    for (final entry in split.recipients.entries) {
      if (entry.value.status == 'rejected') {
        updates['recipients.${entry.key}.status'] = 'dismissed';
      }
    }
    if (updates.isNotEmpty) {
      await _db.collection('splitRequests').doc(split.id).update(updates);
    }

    if (!split.initiatorExpenseSaved) {
      await saveInitiatorExpense(split);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIATOR EXPENSE SAVE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Saves the initiator's expense share to SQLite and marks the Firestore
  /// document so this is not repeated.
  Future<void> saveInitiatorExpense(SplitRequest split) async {
    final now = DateTime.now();
    final splitNote = split.notes.isEmpty
        ? 'Split ${split.splitCount} ways'
        : '${split.notes} (Split ${split.splitCount} ways)';

    final expense = Expense(
      merchantName: split.merchant,
      category: split.category,
      totalAmount: split.amountPerPerson,
      date: split.date,
      paymentMethod: split.paymentMethod,
      notes: splitNote,
      imagePath: split.imagePath,
      aiConfidence: split.aiConfidence,
      createdAt: now,
      modifiedAt: now,
      items: split.expenseItems,
    );
    await DatabaseService.instance.insertExpense(expense);

    await _db
        .collection('splitRequests')
        .doc(split.id)
        .update({'initiatorExpenseSaved': true});
  }

  /// Finds all fully-accepted splits where the initiator's expense hasn't been
  /// saved yet, saves each one, and returns the list that was saved.
  Future<List<SplitRequest>> saveFullyAcceptedInitiatorExpenses() async {
    final splits = await getFullyAcceptedSplitsForInitiator();
    final saved = <SplitRequest>[];
    for (final split in splits) {
      try {
        await saveInitiatorExpense(split);
        saved.add(split);
      } catch (_) {}
    }
    return saved;
  }
}

