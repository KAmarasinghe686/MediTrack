import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../widgets/screen_heroes.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  // Controllers
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController(); // NEW: For long-term notes

  // Time slots
  List<TimeSlot> _selectedTimeSlots = [];
  List<String> _selectedDays = [];

  // Frequency & Duration
  String _selectedFrequency = 'Daily'; // Daily, Weekly, Bi-Weekly, Monthly
  String _selectedDuration = 'Long-term'; // NEW: Short-term, Long-term

  // Dates (for short-term medications)
  DateTime? _startDate;
  DateTime? _endDate;

  // Refill settings (for long-term medications)
  bool _isRefillable = false;
  int _refillDays = 7;
  int _refillCount = 0;

  // Notification
  String _selectedNotifyBefore = 'On Time';
  int? _editingIndex;
  DateTime _selectedPlannerDate = DateUtils.dateOnly(DateTime.now());
  bool _showMonthlyPlanner = false;
  double _calendarScale = 1.0;

  // Time input
  final TextEditingController _hourController = TextEditingController();
  final TextEditingController _minuteController =
      TextEditingController(text: '00');
  String _selectedAmPm = 'AM';
  Stream<List<Map<String, dynamic>>>? _medicationsCache;
  StreamSubscription<List<Map<String, dynamic>>>? _medicationSummarySubscription;

  // Options
  final List<String> _dayOptions = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];
  final List<String> _frequencyOptions = [
    'Daily',
    'Weekly',
    'Bi-Weekly',
    'Monthly'
  ];
  final List<String> _durationOptions = ['Short-term', 'Long-term']; // NEW
  final List<String> _notifyBeforeOptions = [
    'On Time',
    '5 min before',
    '10 min before',
    '15 min before',
    '30 min before',
    '1 hour before',
    '2 hours before',
  ];

  String get _userId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 30));
    _medicationSummarySubscription = _medications.listen((medications) {
      unawaited(_syncEmergencyMedicationSummary(medications));
    });
  }

  @override
  void dispose() {
    _medicationSummarySubscription?.cancel();
    _nameController.dispose();
    _dosageController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _medicationsStream() {
    return FirebaseFirestore.instance
        .collection('medications')
        .doc(_userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      return (data['medications'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
    });
  }

  Stream<List<Map<String, dynamic>>> get _medications =>
      _medicationsCache ??= _medicationsStream();

  Future<void> _syncEmergencyMedicationSummary(List medications) async {
    final currentMedications = medications
        .where((medication) => medication is Map && medication['isActive'] != false)
        .map((medication) {
      final name = medication['name']?.toString().trim() ?? '';
      final dosage = medication['dosage']?.toString().trim() ?? '';
      return [name, dosage].where((value) => value.isNotEmpty).join(' ');
    }).where((value) => value.isNotEmpty).toList();

    await FirebaseFirestore.instance
        .collection('emergency_profiles')
        .doc(_userId)
        .set(
      {
        'currentMedications': currentMedications,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String?> _refreshNotificationSchedule() async {
    try {
      final remindersEnabled =
          await NotificationService.medicationRemindersEnabled();
      if (!remindersEnabled) {
        return 'Medication reminders are turned off in Notification Settings.';
      }

      final permissionIssue =
          await NotificationService.medicationReminderPermissionIssue();
      if (permissionIssue != null) return permissionIssue;

      // Keep the add/edit path identical to the settings screen: cancel old
      // OS alarms and inbox placeholders, then rebuild only active medicines.
      await NotificationService.applyMedicationReminderSettings(enabled: true);
      return null;
    } catch (error) {
      debugPrint('Could not schedule medication reminders: $error');
      return 'Medication saved, but its reminder could not be scheduled.';
    }
  }

  String? _medicationValidationError() {
    if (_nameController.text.trim().isEmpty ||
        _dosageController.text.trim().isEmpty ||
        _selectedTimeSlots.isEmpty) {
      return 'Fill name, dosage and add at least one time';
    }
    if (_selectedFrequency != 'Daily' && _selectedDays.isEmpty) {
      return 'Select at least one day';
    }

    if (_selectedDuration == 'Short-term') {
      if (_startDate == null || _endDate == null) {
        return 'Select start and end dates';
      }
      if (_endDate!.isBefore(_startDate!)) {
        return 'End date must be after start date';
      }
    }
    return null;
  }

  Future<bool> _saveMedication() async {
    final validationError = _medicationValidationError();
    if (validationError != null) {
      _showSnack(validationError, Colors.red);
      return false;
    }

    final med = {
      'name': _nameController.text.trim(),
      'dosage': _dosageController.text.trim(),
      'times': _selectedTimeSlots.map((s) => s.toMap()).toList(),
      'reason': _reasonController.text.trim(),
      'notes': _notesController.text.trim(), // NEW
      'frequency': _selectedFrequency,
      'days': _selectedDays,
      'duration': _selectedDuration, // NEW
      'startDate':
          _startDate != null ? Timestamp.fromDate(_startDate!) : null, // NEW
      'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null, // NEW
      'isRefillable': _isRefillable, // NEW
      'refillDays': _refillDays, // NEW
      'refillCount': _refillCount, // NEW
      'notifyBefore': _selectedNotifyBefore,
      // FieldValue.serverTimestamp cannot be nested inside an array item.
      'createdAt': Timestamp.now(),
      'isActive': true, // NEW
    };

    final docRef =
        FirebaseFirestore.instance.collection('medications').doc(_userId);
    final doc = await docRef.get();
    List meds = doc.exists ? (doc.data()!['medications'] as List) : [];

    final bool isEditing = _editingIndex != null;
    if (isEditing) {
      meds[_editingIndex!] = med;
    } else {
      meds.add(med);
    }

    await docRef.set(
        {'medications': meds, 'lastUpdated': FieldValue.serverTimestamp()});
    await _syncEmergencyMedicationSummary(meds);

    // Do not keep the add/edit dialog open while notification scheduling runs.
    final reminderIssue = await _refreshNotificationSchedule();

    _clearForm();
    if (reminderIssue != null) {
      _showSnack(reminderIssue, Colors.orange);
      _editingIndex = null;
      return true;
    }
    _showSnack(isEditing ? '✅ Medication updated!' : '✅ Medication added!',
        Colors.green);
    _editingIndex = null;
    return true;
  }

  void _editMedication(Map<String, dynamic> med, int index) {
    _editingIndex = index;
    _nameController.text = med['name'] ?? '';
    _dosageController.text = med['dosage'] ?? '';
    _reasonController.text = med['reason'] ?? '';
    _notesController.text = med['notes'] ?? ''; // NEW
    _selectedFrequency = med['frequency'] ?? 'Daily';
    _selectedDuration = med['duration'] ?? 'Long-term'; // NEW
    _selectedDays = List<String>.from(med['days'] ?? []);
    _selectedNotifyBefore = med['notifyBefore'] ?? 'On Time';

    // Load dates
    if (med['startDate'] != null) {
      _startDate = (med['startDate'] as Timestamp).toDate();
    }
    if (med['endDate'] != null) {
      _endDate = (med['endDate'] as Timestamp).toDate();
    }

    // Load refill settings
    _isRefillable = med['isRefillable'] ?? false;
    _refillDays = med['refillDays'] ?? 7;
    _refillCount = med['refillCount'] ?? 0;

    final times = med['times'] as List? ?? [];
    _selectedTimeSlots = times.map((t) {
      if (t is Map) {
        return TimeSlot(
            hour: t['hour'] ?? 8,
            minute: t['minute'] ?? 0,
            amPm: t['amPm'] ?? 'AM');
      }
      return TimeSlot(hour: 8, minute: 0, amPm: 'AM');
    }).toList();
    _showDialog(isEditing: true);
  }

  Future<void> _deleteMedication(int index) async {
    final doc = await FirebaseFirestore.instance
        .collection('medications')
        .doc(_userId)
        .get();
    if (!doc.exists) return;
    List meds = doc.data()!['medications'] as List;
    meds.removeAt(index);
    await doc.reference.update(
        {'medications': meds, 'lastUpdated': FieldValue.serverTimestamp()});
    await _syncEmergencyMedicationSummary(meds);
    await _refreshNotificationSchedule();
    _showSnack('🗑️ Removed', Colors.orange);
  }

  void _clearForm() {
    _nameController.clear();
    _dosageController.clear();
    _reasonController.clear();
    _notesController.clear();
    _selectedTimeSlots.clear();
    _selectedDays.clear();
    _selectedFrequency = 'Daily';
    _selectedDuration = 'Long-term';
    _selectedNotifyBefore = 'On Time';
    _editingIndex = null;
    _hourController.clear();
    _minuteController.text = '00';
    _selectedAmPm = 'AM';
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 30));
    _isRefillable = false;
    _refillDays = 7;
    _refillCount = 0;
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _showDialog({bool isEditing = false}) {
    _hourController.clear();
    _minuteController.text = '00';
    _selectedAmPm = 'AM';

    final List<TimeSlot> dialogSlots = List.from(_selectedTimeSlots);

    // Local state for dialog
    String localFrequency = _selectedFrequency;
    String localDuration = _selectedDuration;
    List<String> localDays = List.from(_selectedDays);
    String localNotifyBefore = _selectedNotifyBefore;
    DateTime? localStartDate = _startDate;
    DateTime? localEndDate = _endDate;
    bool localIsRefillable = _isRefillable;
    int localRefillDays = _refillDays;
    int localRefillCount = _refillCount;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(isEditing ? Icons.edit : Icons.add,
                  color: Theme.of(context).primaryColor),
              const SizedBox(width: 10),
              Text(isEditing ? 'Edit Medication' : 'Add Medication'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                const Text('Name',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Paracetamol',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // Dosage
                const Text('Dosage',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                TextField(
                  controller: _dosageController,
                  decoration: InputDecoration(
                    hintText: 'e.g. 500mg',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // Reason
                const Text('Reason (optional)',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                TextField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Fever, Pain',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // 📌 NEW: Duration
                const Text('Duration',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: localDuration,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  items: _durationOptions
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() {
                      localDuration = v!;
                      if (v == 'Short-term') {
                        localStartDate = DateTime.now();
                        localEndDate =
                            DateTime.now().add(const Duration(days: 30));
                      } else {
                        localIsRefillable = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),

                // 📌 NEW: Date Range for Short-term
                if (localDuration == 'Short-term') ...[
                  const Text('Start & End Dates',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: localStartDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() => localStartDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  localStartDate != null
                                      ? '${localStartDate!.day}/${localStartDate!.month}/${localStartDate!.year}'
                                      : 'Start Date',
                                ),
                                const Icon(Icons.calendar_today, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: localEndDate ??
                                  DateTime.now().add(const Duration(days: 30)),
                              firstDate: localStartDate ?? DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() => localEndDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  localEndDate != null
                                      ? '${localEndDate!.day}/${localEndDate!.month}/${localEndDate!.year}'
                                      : 'End Date',
                                ),
                                const Icon(Icons.calendar_today, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // 📌 NEW: Refill Settings for Long-term
                if (localDuration == 'Long-term') ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Refill Reminder'),
                    subtitle:
                        const Text('Get reminded when it\'s time to refill'),
                    value: localIsRefillable,
                    onChanged: (v) =>
                        setDialogState(() => localIsRefillable = v),
                  ),
                  if (localIsRefillable) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Refill every',
                            style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 50,
                          child: TextFormField(
                            initialValue: localRefillDays.toString(),
                            keyboardType: TextInputType.number,
                            maxLength: 3,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              counterText: '',
                            ),
                            onChanged: (v) =>
                                localRefillDays = int.tryParse(v) ?? 7,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('days', style: TextStyle(fontSize: 13)),
                        const Spacer(),
                        const Text('Refill #', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 40,
                          child: TextFormField(
                            initialValue: localRefillCount.toString(),
                            keyboardType: TextInputType.number,
                            maxLength: 3,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              counterText: '',
                            ),
                            onChanged: (v) =>
                                localRefillCount = int.tryParse(v) ?? 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],

                // Frequency
                const Text('Frequency',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: localFrequency,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  items: _frequencyOptions
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => localFrequency = v!),
                ),
                const SizedBox(height: 14),

                // Days (for non-daily)
                if (localFrequency != 'Daily') ...[
                  const Text('Select Days',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: _dayOptions.map((day) {
                      return FilterChip(
                        label: Text(day),
                        selected: localDays.contains(day),
                        onSelected: (v) => setDialogState(() {
                          v ? localDays.add(day) : localDays.remove(day);
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Time Slots
                const Text('Add Time Slots',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Add up to 3 times per day',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _hourController,
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        decoration: const InputDecoration(
                          labelText: 'Hour',
                          hintText: '1-12',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _minuteController,
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        decoration: const InputDecoration(
                          labelText: 'Minute',
                          hintText: '00-59',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedAmPm,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        items: ['AM', 'PM']
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => _selectedAmPm = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        tooltip: 'Add time',
                        onPressed: () {
                          final hour = _hourController.text.trim();
                          final minute = _minuteController.text.trim();
                          if (hour.isEmpty || minute.isEmpty) {
                            _showSnack('Enter hour and minute', Colors.orange);
                            return;
                          }
                          final h = int.tryParse(hour) ?? -1;
                          final m = int.tryParse(minute) ?? -1;
                          if (h < 1 || h > 12) {
                            _showSnack('Hour: 1-12', Colors.orange);
                            return;
                          }
                          if (m < 0 || m > 59) {
                            _showSnack('Minute: 0-59', Colors.orange);
                            return;
                          }
                          if (dialogSlots.length >= 3) {
                            _showSnack('Max 3 times', Colors.orange);
                            return;
                          }
                          final exists = dialogSlots.any((slot) =>
                              slot.hour == h &&
                              slot.minute == m &&
                              slot.amPm == _selectedAmPm);
                          if (exists) {
                            _showSnack('Time already added', Colors.orange);
                            return;
                          }
                          setDialogState(() {
                            dialogSlots.add(TimeSlot(
                                hour: h, minute: m, amPm: _selectedAmPm));
                            _hourController.clear();
                            _minuteController.text = '00';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Time slots list
                if (dialogSlots.isNotEmpty) ...[
                  const Divider(),
                  ...dialogSlots.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final slot = entry.value;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.access_time, size: 18),
                      title: Text(
                        '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')} ${slot.amPm}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.red),
                        onPressed: () =>
                            setDialogState(() => dialogSlots.removeAt(idx)),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 14),

                // 📌 NEW: Notes
                const Text('Notes (optional)',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Take with food, avoid alcohol',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // Notify Before
                const Text('Notify Me',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: localNotifyBefore,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  items: _notifyBeforeOptions
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => localNotifyBefore = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _clearForm();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Update local state before saving
                setState(() {
                  _selectedFrequency = localFrequency;
                  _selectedDuration = localDuration;
                  _selectedDays = localDays;
                  _selectedNotifyBefore = localNotifyBefore;
                  _startDate = localStartDate;
                  _endDate = localEndDate;
                  _isRefillable = localIsRefillable;
                  _refillDays = localRefillDays;
                  _refillCount = localRefillCount;
                  _selectedTimeSlots = List.from(dialogSlots);
                });

                final validationError = _medicationValidationError();
                if (validationError != null) {
                  _showSnack(validationError, Colors.red);
                  return;
                }

                // Close immediately. A slow/offline Firestore request must not
                // trap the user inside the add-medication dialog.
                Navigator.pop(context);
                try {
                  await _saveMedication();
                } catch (error) {
                  _showSnack('Could not save medication: $error', Colors.red);
                }
              },
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to medication settings
            },
            tooltip: 'Medication Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: MediTrackImageBanner(
              title: 'Medication routine',
              subtitle: 'Simple reminders that fit into your day.',
              imageUrl: 'assets/images/medication_reminder_hero.png',
              icon: Icons.medication_liquid_rounded,
              showOverlay: false,
              fullWhiteOverlayOpacity: 0.56,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _medications,
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final meds = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: meds.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    _MedicationWeekPlanner(
                      medications: meds,
                      selectedDate: _selectedPlannerDate,
                      showMonth: _showMonthlyPlanner,
                      onDateSelected: (date) {
                        setState(() => _selectedPlannerDate = date);
                      },
                      onViewChanged: (showMonth) {
                        setState(() => _showMonthlyPlanner = showMonth);
                      },
                      onNavigate: (direction) {
                        setState(() {
                          _selectedPlannerDate = _showMonthlyPlanner
                              ? DateTime(
                                  _selectedPlannerDate.year,
                                  _selectedPlannerDate.month + direction,
                                  1,
                                )
                              : _selectedPlannerDate.add(
                                  Duration(days: direction * 7),
                                );
                        });
                      },
                      calendarScale: _calendarScale,
                      onZoomChanged: (scale) {
                        setState(() => _calendarScale = scale);
                      },
                    ),
                    if (meds.isEmpty) ...[
                      const SizedBox(height: 24),
                      const Icon(
                        Icons.medication_outlined,
                        size: 58,
                        color: Color(0xFF8BA4A3),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No medication reminders yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('Add a medicine to see it in your weekly plan.'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add medication'),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 24, bottom: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Your medications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }

              final med = meds[index - 1];
              final timesData = med['times'] as List? ?? [];
              String timeStr = '';
              if (timesData.isNotEmpty && timesData.first is Map) {
                timeStr = timesData.map((t) {
                  if (t is Map) {
                    return '${t['hour'].toString().padLeft(2, '0')}:${t['minute'].toString().padLeft(2, '0')} ${t['amPm']}';
                  }
                  return t.toString();
                }).join(', ');
              }
              final notifyBefore = med['notifyBefore'] ?? 'On Time';
              final duration = med['duration'] ?? 'Long-term';
              final endDate = med['endDate'] != null
                  ? (med['endDate'] as Timestamp).toDate()
                  : null;
              final isExpired = duration == 'Short-term' &&
                  endDate != null &&
                  endDate.isBefore(DateTime.now());

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isExpired ? Colors.grey[300] : Colors.blue[50],
                    child: Icon(
                      Icons.medication,
                      color: isExpired ? Colors.grey : Colors.blue,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '${med['name']} ${med['dosage']}',
                    style: TextStyle(
                      decoration: isExpired ? TextDecoration.lineThrough : null,
                      color: isExpired ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (timeStr.isNotEmpty) Text(timeStr),
                      if (notifyBefore != 'On Time')
                        Text('🔔 $notifyBefore',
                            style: TextStyle(
                                fontSize: 12, color: Colors.blue[600])),
                      if (med['reason'] != null &&
                          med['reason'].toString().isNotEmpty)
                        Text('📝 ${med['reason']}',
                            style: const TextStyle(fontSize: 12)),
                      if (duration == 'Short-term' && endDate != null)
                        Text(
                          '⏳ Until ${endDate.day}/${endDate.month}/${endDate.year}',
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  isExpired ? Colors.red : Colors.green[600]),
                        ),
                      if (duration == 'Long-term' &&
                          med['isRefillable'] == true)
                        Text(
                          '🔄 Refill every ${med['refillDays'] ?? 7} days',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.orange),
                        ),
                      if (isExpired)
                        const Text(
                          '⚠️ Expired',
                          style: TextStyle(fontSize: 11, color: Colors.red),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editMedication(med, index - 1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteMedication(index - 1),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TimeSlot {
  final int hour;
  final int minute;
  final String amPm;

  TimeSlot({required this.hour, required this.minute, required this.amPm});

  Map<String, dynamic> toMap() =>
      {'hour': hour, 'minute': minute, 'amPm': amPm};
}

class _MedicationWeekPlanner extends StatelessWidget {
  const _MedicationWeekPlanner({
    required this.medications,
    required this.selectedDate,
    required this.onDateSelected,
    required this.showMonth,
    required this.onViewChanged,
    required this.onNavigate,
    required this.calendarScale,
    required this.onZoomChanged,
  });

  final List<Map<String, dynamic>> medications;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final bool showMonth;
  final ValueChanged<bool> onViewChanged;
  final ValueChanged<int> onNavigate;
  final double calendarScale;
  final ValueChanged<double> onZoomChanged;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final weekStart = selectedDate
        .subtract(Duration(days: selectedDate.weekday - DateTime.monday));
    final monthStart = DateTime(selectedDate.year, selectedDate.month);
    final monthGridStart =
        monthStart.subtract(Duration(days: monthStart.weekday - DateTime.monday));
    final visibleDates = showMonth
        ? List.generate(42, (index) => monthGridStart.add(Duration(days: index)))
        : List.generate(7, (index) => weekStart.add(Duration(days: index)));
    final selectedDoses = _dosesFor(selectedDate);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF173F5F), Color(0xFF14B8A6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showMonth
                            ? 'Monthly medication planner'
                            : 'Weekly medication planner',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        showMonth
                            ? 'Tap a date to see its doses'
                            : 'Your upcoming doses for this week',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<bool>(
                  tooltip: 'Change calendar view',
                  icon: const Icon(Icons.view_module_outlined, color: Colors.white),
                  onSelected: onViewChanged,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: false, child: Text('Week view')),
                    PopupMenuItem(value: true, child: Text('Month view')),
                  ],
                ),
                IconButton(
                  tooltip: 'Zoom out calendar',
                  onPressed: calendarScale <= 0.8
                      ? null
                      : () => onZoomChanged(
                            (calendarScale - 0.2).clamp(0.8, 1.8).toDouble(),
                          ),
                  icon: const Icon(Icons.zoom_out_rounded, color: Colors.white),
                ),
                IconButton(
                  tooltip: 'Zoom in calendar',
                  onPressed: calendarScale >= 1.8
                      ? null
                      : () => onZoomChanged(
                            (calendarScale + 0.2).clamp(0.8, 1.8).toDouble(),
                          ),
                  icon: const Icon(Icons.zoom_in_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous ${showMonth ? 'month' : 'week'}',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => onNavigate(-1),
                ),
                Expanded(
                  child: Text(
                    showMonth
                        ? '${_monthName(selectedDate.month)} ${selectedDate.year}'
                        : 'Week of ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Next ${showMonth ? 'month' : 'week'}',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => onNavigate(1),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final effectiveScale =
                  calendarScale > textScale ? calendarScale : textScale;
              final grid = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: constraints.maxWidth * effectiveScale,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleDates.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4 * effectiveScale,
                      crossAxisSpacing: 4 * effectiveScale,
                        childAspectRatio: showMonth ? 0.58 : 0.55,
                    ),
                    itemBuilder: (context, index) {
                      final date = visibleDates[index];
                      return _PlannerDay(
                        date: date,
                        label: _dayLabels[date.weekday - 1],
                        isToday: DateUtils.isSameDay(date, today),
                        isSelected: DateUtils.isSameDay(date, selectedDate),
                        doses: _dosesFor(date),
                          onTap: () => onDateSelected(date),
                      );
                    },
                  ),
                ),
              );
              if (effectiveScale > 1.0) return grid;
              return GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() > 150) onNavigate(velocity < 0 ? 1 : -1);
                },
                child: grid,
              );
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: selectedDoses.isEmpty
                  ? Text(
                      'No doses on ${_dayLabels[selectedDate.weekday - 1]}, ${selectedDate.day}.',
                      style: const TextStyle(color: Color(0xFF6E7F8E)),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedDoses
                          .map(
                            (dose) => Chip(
                              avatar: const Icon(
                                Icons.medication_liquid_rounded,
                                size: 16,
                                color: Color(0xFF14B8A6),
                              ),
                              label: Text('${dose.time} - ${dose.name}'),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<_PlannerDose> _dosesFor(DateTime date) {
    final weekday = _dayLabels[date.weekday - 1];
    final doses = <_PlannerDose>[];

    for (final medication in medications) {
      if (medication['isActive'] == false || !_isActiveOn(medication, date)) {
        continue;
      }

      if (!_occursOn(medication, date, weekday)) continue;

      final times = medication['times'] as List? ?? [];
      for (final time in times.whereType<Map>()) {
        final hour = (time['hour'] as num?)?.toInt();
        final minute = (time['minute'] as num?)?.toInt();
        final amPm = time['amPm'] as String? ?? 'AM';
        if (hour == null || minute == null) continue;
        doses.add(_PlannerDose(
          name: medication['name'] as String? ?? 'Medication',
          time:
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $amPm',
          sortValue: _to24Hour(hour, minute, amPm),
        ));
      }
    }

    doses.sort((a, b) => a.sortValue.compareTo(b.sortValue));
    return doses;
  }

  bool _isActiveOn(Map<String, dynamic> medication, DateTime date) {
    if (medication['duration'] != 'Short-term') return true;
    final start = medication['startDate'];
    final end = medication['endDate'];
    final startDate =
        start is Timestamp ? DateUtils.dateOnly(start.toDate()) : null;
    final endDate = end is Timestamp ? DateUtils.dateOnly(end.toDate()) : null;
    return (startDate == null || !date.isBefore(startDate)) &&
        (endDate == null || !date.isAfter(endDate));
  }

  bool _occursOn(Map<String, dynamic> medication, DateTime date, String weekday) {
    final frequency = medication['frequency'] as String? ?? 'Daily';
    if (frequency == 'Daily') return true;

    final days = List<String>.from(medication['days'] as List? ?? []);
    final start = medication['startDate'];
    final startDate = start is Timestamp ? DateUtils.dateOnly(start.toDate()) : date;
    if (frequency == 'Monthly') return date.day == startDate.day;

    final matchesWeekday = days.isEmpty
        ? date.weekday == startDate.weekday
        : days.contains(weekday);
    if (!matchesWeekday) return false;
    if (frequency != 'Bi-Weekly') return true;

    final daysSinceStart = date.difference(startDate).inDays;
    return daysSinceStart >= 0 && (daysSinceStart ~/ 7).isEven;
  }

  int _to24Hour(int hour, int minute, String amPm) {
    var result = hour % 12;
    if (amPm == 'PM') result += 12;
    return result * 60 + minute;
  }

  String _monthName(int month) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][month - 1];
}

class _PlannerDay extends StatelessWidget {
  const _PlannerDay({
    required this.date,
    required this.label,
    required this.isToday,
    required this.isSelected,
    required this.doses,
    required this.onTap,
  });

  final DateTime date;
  final String label;
  final bool isToday;
  final bool isSelected;
  final List<_PlannerDose> doses;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFFD7F5F0) : const Color(0xFFF7FAF9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected || isToday
                  ? const Color(0xFF14B8A6)
                  : const Color(0xFFE0EAE8),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.substring(0, 1),
                style: TextStyle(
                  color: isSelected || isToday
                      ? const Color(0xFF0E8277)
                      : const Color(0xFF6E7F8E),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${date.day}',
                style: TextStyle(
                  color: Color(0xFF173F5F),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (doses.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${doses.length} dose${doses.length == 1 ? '' : 's'}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlannerDose {
  const _PlannerDose({
    required this.name,
    required this.time,
    required this.sortValue,
  });

  final String name;
  final String time;
  final int sortValue;
}
