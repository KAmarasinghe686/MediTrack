import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/common_widgets.dart';
import '../widgets/screen_heroes.dart';
import '../theme/clinical_theme.dart';

class EmergencyProfileScreen extends StatefulWidget {
  const EmergencyProfileScreen({super.key});

  @override
  State<EmergencyProfileScreen> createState() => _EmergencyProfileScreenState();
}

class _EmergencyProfileScreenState extends State<EmergencyProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Blood type
  String? _selectedBloodType;
  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  // Allergies - categorized
  final List<String> _drugAllergies = [];
  final TextEditingController _drugController = TextEditingController();

  final List<String> _foodAllergies = [];
  final TextEditingController _foodController = TextEditingController();

  final List<String> _otherAllergies = [];
  final TextEditingController _otherController = TextEditingController();

  // Contacts - with relationship (free text)
  final List<Map<String, String>> _contacts = [];
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactRelationshipController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final doc = await _db.collection('emergency_profiles').doc(userId).get();
      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data()!;
        _selectedBloodType = data['bloodType'] ?? '';
        _drugAllergies.clear();
        _drugAllergies.addAll(List<String>.from(data['drugAllergies'] ?? []));
        _foodAllergies.clear();
        _foodAllergies.addAll(List<String>.from(data['foodAllergies'] ?? []));
        _otherAllergies.clear();
        _otherAllergies.addAll(List<String>.from(data['otherAllergies'] ?? []));

        // ✅ Load contacts with relationship
        _contacts.clear();
        final contacts = data['emergencyContacts'] as Map? ?? {};
        contacts.forEach((key, value) {
          if (value is String) {
            // Old format: just phone number
            _contacts.add({
              'name': key,
              'relationship': 'Unknown',
              'phone': value,
            });
          } else if (value is Map) {
            // New format: {relationship, phone}
            _contacts.add({
              'name': key,
              'relationship': value['relationship']?.toString() ?? 'Unknown',
              'phone': value['phone']?.toString() ?? '',
            });
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    if (_selectedBloodType == null || _selectedBloodType!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select blood type')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // ✅ Build contacts map with relationship
      final contactsMap = <String, dynamic>{};
      for (var contact in _contacts) {
        final name = contact['name']?.trim() ?? '';
        final relationship = contact['relationship']?.trim() ?? 'Unknown';
        final phone = contact['phone']?.trim() ?? '';
        if (name.isNotEmpty && phone.isNotEmpty) {
          contactsMap[name] = {
            'relationship': relationship,
            'phone': phone,
          };
        }
      }

      await _db.collection('emergency_profiles').doc(userId).set({
        'bloodType': _selectedBloodType,
        'drugAllergies': _drugAllergies,
        'foodAllergies': _foodAllergies,
        'otherAllergies': _otherAllergies,
        'emergencyContacts': contactsMap,
        'updatedAt': FieldValue.serverTimestamp(),
      // Do not use merge here. Firestore merges nested map keys when merge is
      // enabled, which would keep contacts the user removed from this list.
      }).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Emergency profile saved!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saving timed out. Check your internet connection and try again.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Add to list
  void _addItem(List<String> list, TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      list.add(text);
      controller.clear();
    });
  }

  // Remove from list
  void _removeItem(List<String> list, int index) {
    setState(() => list.removeAt(index));
  }

  // Contact add with relationship
  void _addContact() {
    final name = _contactNameController.text.trim();
    final relationship = _contactRelationshipController.text.trim();
    final phone = _contactPhoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter name and phone')),
      );
      return;
    }

    setState(() {
      _contacts.add({
        'name': name,
        'relationship': relationship.isEmpty ? 'Unknown' : relationship,
        'phone': phone,
      });
      _contactNameController.clear();
      _contactRelationshipController.clear();
      _contactPhoneController.clear();
    });
  }

  void _removeContact(int index) {
    setState(() => _contacts.removeAt(index));
  }

  // ✅ Build allergy section
  Widget _buildAllergySection({
    required String title,
    required List<String> items,
    required TextEditingController controller,
    required Color color,
    required IconData icon,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                onSubmitted: (value) => _addItem(items, controller),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add_circle, color: ClinicalPalette.teal),
              onPressed: () => _addItem(items, controller),
            ),
          ],
        ),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Chip(
                  label: Text(item),
                  backgroundColor: color.withValues(alpha: 0.15),
                  deleteIcon: const Icon(Icons.close, size: 16, color: Colors.grey),
                  onDeleted: () => _removeItem(items, idx),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Profile'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveProfile,
            ),
        ],
      ),
      body: FluidBlobBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MediTrackIllustrationPanel(
                    title: 'Emergency profile',
                    subtitle: 'Keep critical details ready when care matters most.',
                    imageUrl: 'assets/images/emergency_illustration.png',
                    tags: ['Private', 'Ready to share'],
                  ),
                  const SizedBox(height: 22),
                  const SectionHeader(
                    title: 'Critical information',
                    subtitle: 'Details shared during an emergency.',
                  ),
                  const SizedBox(height: 12),
                  // Blood Type
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bloodtype_rounded,
                                  color: ClinicalPalette.teal),
                              SizedBox(width: 8),
                              Text('Blood Type *',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBloodType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: _bloodTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedBloodType = value),
                  ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Allergies
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Allergies', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  _buildAllergySection(
                    title: 'Drug Allergies',
                    items: _drugAllergies,
                    controller: _drugController,
                    color: Colors.red,
                    icon: Icons.medication,
                    hintText: 'e.g. Penicillin',
                  ),
                  _buildAllergySection(
                    title: 'Food Allergies',
                    items: _foodAllergies,
                    controller: _foodController,
                    color: Colors.orange,
                    icon: Icons.restaurant,
                    hintText: 'e.g. Peanuts',
                  ),
                  _buildAllergySection(
                    title: 'Other Allergies',
                    items: _otherAllergies,
                    controller: _otherController,
                    color: Colors.purple,
                    icon: Icons.warning,
                    hintText: 'e.g. Latex',
                  ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ❌ REMOVED: Medications section (now read from medication_screen)

                  // Contacts with Relationship
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.contact_phone_rounded,
                                  color: ClinicalPalette.teal),
                              SizedBox(width: 8),
                              Text('Emergency Contacts',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 14),
                  TextField(
                    controller: _contactNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Contact name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _contactRelationshipController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Relationship (optional)',
                      prefixIcon: Icon(Icons.family_restroom_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _contactPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'Phone number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _addContact,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Add contact'),
                    ),
                  ),
                  if (_contacts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: _contacts.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final contact = entry.value;
                          return Chip(
                            label: Text('${contact['name']} (${contact['relationship']}) - ${contact['phone']}'),
                            backgroundColor: Colors.orange.shade50,
                            deleteIcon: const Icon(Icons.close, size: 16, color: Colors.grey),
                            onDeleted: () => _removeContact(idx),
                          );
                        }).toList(),
                      ),
                    ),

                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const CircularProgressIndicator()
                          : const Text('Save Emergency Profile', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
