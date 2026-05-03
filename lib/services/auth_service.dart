import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'split_bill_service.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  Future<UserCredential> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Best-effort: refresh the profile for split-bill discovery.
    // Firestore failure must not block login.
    try {
      await SplitBillService.instance.saveCurrentUserProfile();
    } catch (_) {}
    return credential;
  }

  Future<UserCredential> register(
      String name, String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefUserName, name.trim());
    await prefs.setString(AppConstants.prefUserEmail, email.trim());
    // Best-effort: make user discoverable for split-bill.
    // Firestore failure must not block registration.
    try {
      await SplitBillService.instance.saveCurrentUserProfile();
    } catch (_) {}
    return credential;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefIsLoggedIn, false);
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Updates the display name in Firebase Auth and SharedPreferences.
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefUserName, name.trim());
  }

  /// Updates the photo URL in Firebase Auth and syncs the Firestore userProfile.
  Future<void> updatePhotoURL(String url) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updatePhotoURL(url);
    try {
      await SplitBillService.instance.saveCurrentUserProfile();
    } catch (_) {}
  }

  /// Re-authenticates then updates the password in Firebase Auth.
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
          code: 'no-current-user', message: 'No authenticated user');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Re-authenticates, deletes all Firestore data, then deletes the Auth user.
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
          code: 'no-current-user', message: 'No authenticated user');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    // Delete all Firestore data for this user.
    final uid = user.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final expenses = await userRef.collection('expenses').get();
    for (final doc in expenses.docs) {
      await doc.reference.delete();
    }
    final budgets = await userRef.collection('budgets').get();
    for (final doc in budgets.docs) {
      await doc.reference.delete();
    }

    // Delete the Firebase Auth account last.
    await user.delete();
  }

  /// Converts a FirebaseAuthException code to a user-friendly message.
  String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password';
      case 'email-already-in-use':
        return 'An account with this email already exists';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase Console';
      case 'app-not-authorized':
        return 'App not authorized — check your Firebase configuration';
      case 'CONFIGURATION_NOT_FOUND':
        return 'Firebase project not configured correctly';
      default:
        return 'Authentication failed (${e.code}). Please try again';
    }
  }
}
