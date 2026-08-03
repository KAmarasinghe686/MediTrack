import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/medical_record.dart';

class RecordService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<MedicalRecord>> getPatientRecords() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();

    return _db
        .collection('records')
        .where('patientId', isEqualTo: userId)
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MedicalRecord.fromFirestore(doc)).toList());
  }

  Future<void> uploadNewRecord({
    required File file,
    required String title,
    required String type,
    String? extractedText,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final storageRef = _storage.ref().child('patient_records/$userId/$fileName');

    final uploadTask = await storageRef.putFile(file);
    final fileUrl = await uploadTask.ref.getDownloadURL();

    final record = MedicalRecord(
      id: '',
      patientId: userId,
      title: title,
      type: type,
      fileUrl: fileUrl,
      uploadDate: DateTime.now(),
    );

    final recordData = record.toMap();
    if (extractedText != null && extractedText.trim().isNotEmpty) {
      recordData['extractedText'] = extractedText.trim();
    }
    await _db.collection('records').add(recordData);
  }

  // ✅ UPDATE RECORD
  Future<void> updateRecord(String docId, String newTitle, String newType) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    await _db.collection('records').doc(docId).update({
      'title': newTitle,
      'type': newType,
    });
  }

  // ✅ DELETE RECORD
  Future<void> deleteRecord(String docId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Delete from Firestore
    await _db.collection('records').doc(docId).delete();

    // Delete from Storage (optional - uncomment if you want to delete files too)
    // try {
    //   // Extract path from URL
    //   final ref = _storage.refFromURL(fileUrl);
    //   await ref.delete();
    // } catch (e) {
    //   print('Could not delete file from storage: $e');
    // }
  }
}
