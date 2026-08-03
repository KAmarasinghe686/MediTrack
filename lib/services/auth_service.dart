// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firebase project's OAuth 2.0 Web client ID. google_sign_in v7 needs this
  // on Android so it can request the ID token Firebase Authentication uses.
  static const _googleServerClientId =
      '914871814119-pa2ppq52el6m1m1219a730of0kp7bmj9.apps.googleusercontent.com';

  // Stream to listen to login/logout changes automatically
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user ID easily
  String? get currentUserId => _auth.currentUser?.uid;

  // 1. Sign In
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Uses the same Firebase account/session flow as email login, then keeps
  /// the user's profile document available to the rest of the app.
  Future<void> signInWithGoogle() async {
    try {
      UserCredential credential;
      if (kIsWeb) {
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize(
          serverClientId: _googleServerClientId,
        );
        final googleUser = await googleSignIn.authenticate();
        final googleAuth = googleUser.authentication;
        credential = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: googleAuth.idToken),
        );
      }

      final user = credential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? 'MediTrack User',
          'email': user.email ?? '',
          'role': 'patient',
          'profileImageUrl': user.photoURL,
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // 2. Register & Save to Firestore
  Future<void> register(String name, String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Set display name in Firebase Auth
      await credential.user?.updateDisplayName(name);

      // Create a Firestore document for the new user
      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'name': name,
          'email': email,
          'role': 'patient',
          'createdAt': FieldValue.serverTimestamp(),
          'emergencyContacts': [],
          'bloodType': 'Unknown',
        });
      }
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // 3. Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Helper to make Firebase errors user-friendly
  String _handleAuthException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found for that email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'invalid-email':
          return 'The email address is badly formatted.';
        default:
          return e.message ?? 'An unknown authentication error occurred.';
      }
    }
    return e.toString();
  }

  /// Development helper: sign in as demo user or create the account if missing.
  Future<void> signInOrCreateDemoUser({
    String email = 'demo@meditrack.dev',
    String password = 'Test1234!',
    String name = 'Demo User',
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        UserCredential credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (credential.user != null) {
          await credential.user?.updateDisplayName(name);
          await _firestore.collection('users').doc(credential.user!.uid).set({
            'uid': credential.user!.uid,
            'name': name,
            'email': email,
            'role': 'patient',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        return;
      }

      if (e.code == 'wrong-password') {
        throw _handleAuthException(e);
      }

      throw _handleAuthException(e);
    } catch (e) {
      try {
        UserCredential credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (credential.user != null) {
          await credential.user?.updateDisplayName(name);
          await _firestore.collection('users').doc(credential.user!.uid).set({
            'uid': credential.user!.uid,
            'name': name,
            'email': email,
            'role': 'patient',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        return;
      } catch (e2) {
        throw _handleAuthException(e2);
      }
    }
  }
}

// Global instance used by Login and Register screens
final authService = AuthService();
