import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyProfile {
  final String bloodType;
  final List<String> drugAllergies;
  final List<String> foodAllergies;
  final List<String> otherAllergies;
  final Map<String, dynamic> emergencyContacts; // ✅ Now supports {relationship, phone}

  EmergencyProfile({
    required this.bloodType,
    required this.drugAllergies,
    required this.foodAllergies,
    required this.otherAllergies,
    required this.emergencyContacts,
  });

  List<String> get allergies {
    final combined = <String>[];
    combined.addAll(drugAllergies);
    combined.addAll(foodAllergies);
    combined.addAll(otherAllergies);
    return combined;
  }

  factory EmergencyProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyProfile(
      bloodType: data['bloodType'] ?? 'Unknown',
      drugAllergies: List<String>.from(data['drugAllergies'] ?? []),
      foodAllergies: List<String>.from(data['foodAllergies'] ?? []),
      otherAllergies: List<String>.from(data['otherAllergies'] ?? []),
      emergencyContacts: data['emergencyContacts'] as Map<String, dynamic>? ?? {},
    );
  }
}