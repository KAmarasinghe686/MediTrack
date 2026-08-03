import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QRService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _generateFallbackCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(
          6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<Map<String, String>?> getPatientAccessData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    final privacy = await _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('privacy')
        .get();
    if (privacy.data()?['qrSharing'] == false) return null;

    final docRef = _db.collection('qr_tokens').doc(userId);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      final data = snapshot.data()!;
      final token = data['token'] ?? '';
      return {
        'qrToken': token,
        'fallbackCode': data['fallbackCode'] ?? '',
        'url':
            'https://meditrack-gr05.web.app/access.html?token=$token',
      };
    }

    final fallbackCode = _generateFallbackCode();
    final token =
        'meditrack-$userId-${DateTime.now().millisecondsSinceEpoch}';

    await docRef.set({
      'token': token,
      'userId': userId,
      'fallbackCode': fallbackCode,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {
      'qrToken': token,
      'fallbackCode': fallbackCode,
      'url': 'https://meditrack-gr05.web.app/access.html?token=$token',
    };
  }
}
