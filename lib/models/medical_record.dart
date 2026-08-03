import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalRecord {
  final String id;
  final String patientId;
  final String title;
  final String type;
  final String fileUrl;
  final DateTime uploadDate;

  MedicalRecord({
    required this.id,
    required this.patientId,
    required this.title,
    required this.type,
    required this.fileUrl,
    required this.uploadDate,
  });

  factory MedicalRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicalRecord(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      title: data['title'] ?? '',
      type: data['type'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      uploadDate: (data['uploadDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'title': title,
      'type': type,
      'fileUrl': fileUrl,
      'uploadDate': uploadDate,
    };
  }
}
