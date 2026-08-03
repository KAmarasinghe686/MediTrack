import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/emergency_profile.dart';

class EmergencyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<EmergencyProfile?> getEmergencyProfile() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();

    return _db
        .collection('emergency_profiles')
        .doc(userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.exists ? EmergencyProfile.fromFirestore(snapshot) : null);
  }

  /// Shared entry point for manual SOS and sensor-detected events.
  Future<void> triggerEmergency({
    required String reason,
    required String source,
  }) async {
    await triggerPanicAlert(reason: reason, source: source);
  }

  /// Kept for the test UI; cancellation belongs to the UI grace-period before
  /// an alert is persisted.
  Future<void> cancelEmergency() async {}

  Future<void> triggerPanicAlert({
    String reason = 'Manual SOS',
    String source = 'manual_sos',
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    Position? position;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        // ✅ FIXED: Use LocationSettings
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      }
    } catch (_) {
      // Location is best effort
    }

    await _db.collection('emergency_alerts').add({
      'patientId': userId,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'ACTIVE',
      'reason': reason,
      'source': source,
      'latitude': position?.latitude,
      'longitude': position?.longitude,
    }).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'Emergency alert could not be saved. Check your internet connection.',
      ),
    );
  }
}



