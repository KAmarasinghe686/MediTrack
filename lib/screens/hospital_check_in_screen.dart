import 'dart:async';

import 'package:flutter/material.dart';

import '../services/geofence_service.dart';
import '../services/hospital_place_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/screen_heroes.dart';
import '../theme/clinical_theme.dart';

class HospitalCheckInScreen extends StatefulWidget {
  const HospitalCheckInScreen({super.key});

  @override
  State<HospitalCheckInScreen> createState() => _HospitalCheckInScreenState();
}

class _HospitalCheckInScreenState extends State<HospitalCheckInScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  bool _autoCheckInEnabled = false;
  bool _isLoading = false;
  bool _isLoadingNearby = false;
  String _checkInMode = 'trusted';
  String _status = 'Inactive';
  String? _nearbyError;
  Color _statusColor = Colors.grey;
  List<NearbyHospital> _nearbyHospitals = [];
  StreamSubscription<List<NearbyHospital>>? _nearbySubscription;

  // ✅ NEW: Subscription for enter events
  StreamSubscription<HospitalLocation>? _enterSubscription;

  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  CheckInMode get _selectedMode =>
      _checkInMode == 'all' ? CheckInMode.all : CheckInMode.trusted;

  String get _activeStatus => _selectedMode == CheckInMode.all
      ? 'Monitoring hospitals within 5km...'
      : 'Monitoring trusted hospitals...';

  @override
  void initState() {
    super.initState();
    _checkInMode =
        _geofenceService.checkInMode == CheckInMode.all ? 'all' : 'trusted';
    _nearbyHospitals = _geofenceService.nearbyHospitals;
    _autoCheckInEnabled = _geofenceService.isGeofencing;
    _status = _autoCheckInEnabled ? _activeStatus : 'Inactive';
    _statusColor = _autoCheckInEnabled ? Colors.green : Colors.grey;

    _nearbySubscription =
        _geofenceService.onNearbyHospitalsChanged.listen((hospitals) {
      if (!mounted) return;
      setState(() {
        _nearbyHospitals = hospitals;
        _isLoadingNearby = false;
        _nearbyError = null;
      });
    });

    // ✅ NEW: Listen to enter events for simulation feedback
    _enterSubscription = _geofenceService.onHospitalEnter.listen((hospital) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Entered ${hospital.name}'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  Future<void> _updateGeofencingMode(String mode) async {
    final previousMode = _checkInMode;
    setState(() {
      _checkInMode = mode;
      _isLoadingNearby = mode == 'all';
      _nearbyError = null;
      _isLoading = true;
    });

    try {
      final changed = await _geofenceService.updateCheckInMode(_selectedMode);
      if (!mounted) return;

      if (!changed) {
        setState(() {
          _checkInMode = previousMode;
          _autoCheckInEnabled = _geofenceService.isGeofencing;
          _isLoadingNearby = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location services and permission are required for Emergency Mode.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _nearbyHospitals = _geofenceService.nearbyHospitals;
        _autoCheckInEnabled = _geofenceService.isGeofencing;
        _status = _autoCheckInEnabled ? _activeStatus : 'Inactive';
        _statusColor = _autoCheckInEnabled ? Colors.green : Colors.grey;
        _isLoadingNearby = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _nearbyError = error.toString();
        _autoCheckInEnabled = _geofenceService.isGeofencing;
        _status = _autoCheckInEnabled ? _activeStatus : 'Inactive';
        _statusColor = _autoCheckInEnabled ? Colors.green : Colors.grey;
        _isLoadingNearby = false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleGeofence(bool enable) async {
    setState(() => _isLoading = true);

    try {
      if (enable) {
        final started = await _geofenceService.startGeofencing(
          mode: _selectedMode,
        );
        if (!mounted) return;

        if (!started) {
          setState(() {
            _autoCheckInEnabled = false;
            _status = 'Inactive';
            _statusColor = Colors.grey;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied or disabled.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _autoCheckInEnabled = true;
          _status = _activeStatus;
          _statusColor = Colors.green;
          _nearbyHospitals = _geofenceService.nearbyHospitals;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedMode == CheckInMode.all
                  ? 'Emergency Mode monitoring started.'
                  : 'Trusted hospital monitoring started.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _geofenceService.stopGeofencing();
        if (!mounted) return;
        setState(() {
          _autoCheckInEnabled = false;
          _status = 'Inactive';
          _statusColor = Colors.grey;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _autoCheckInEnabled = _geofenceService.isGeofencing;
        _status = _autoCheckInEnabled ? _activeStatus : 'Inactive';
        _statusColor = _autoCheckInEnabled ? Colors.green : Colors.grey;
        _nearbyError = error.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start hospital monitoring: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshNearbyHospitals() async {
    setState(() {
      _isLoadingNearby = true;
      _nearbyError = null;
    });

    try {
      final hospitals = await _geofenceService.refreshNearbyHospitals(
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() => _nearbyHospitals = hospitals);
    } catch (error) {
      if (!mounted) return;
      setState(() => _nearbyError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingNearby = false);
    }
  }

  Future<void> _addAsTrusted(NearbyHospital hospital) async {
    try {
      await _geofenceService.addHospital(
        HospitalLocation.fromNearbyHospital(hospital),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${hospital.name} added to trusted hospitals.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add hospital: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddHospitalDialog() {
    _nameController.clear();
    _latController.clear();
    _lngController.clear();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Trusted Hospital'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Hospital Name',
                hintText: 'e.g. National Hospital Colombo',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g. 6.9271',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g. 79.8612',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: Find coordinates by searching the hospital on a map, then long-press the location.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              final lat = double.tryParse(_latController.text.trim());
              final lng = double.tryParse(_lngController.text.trim());

              if (name.isEmpty ||
                  lat == null ||
                  lng == null ||
                  lat < -90 ||
                  lat > 90 ||
                  lng < -180 ||
                  lng > 180) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a hospital name and valid coordinates: '
                      'latitude -90 to 90, longitude -180 to 180.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext);
              await _geofenceService.addHospital(
                HospitalLocation(
                  id: '',
                  name: name,
                  lat: lat,
                  lng: lng,
                ),
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$name added to trusted hospitals.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nearbySubscription?.cancel();
    // ✅ NEW: Cancel the enter subscription
    _enterSubscription?.cancel();
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Check-In'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddHospitalDialog,
            tooltip: 'Add Hospital',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const MediTrackImageBanner(
            title: 'Hospital check-in',
            subtitle: 'Let MediTrack help you arrive prepared.',
            imageUrl: 'assets/images/hospital_checkin_pastel_cartoon.png',
            icon: Icons.local_hospital_rounded,
            showOverlay: false,
            whiteOverlayOpacity: 1,
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Check-In Mode',
            subtitle: 'Choose which hospitals can trigger automatic check-in',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'trusted',
                  icon: Icon(Icons.verified_outlined),
                  label: Text('Trusted'),
                  tooltip: 'Trusted Hospitals Only',
                ),
                ButtonSegment<String>(
                  value: 'all',
                  icon: Icon(Icons.emergency_outlined),
                  label: Text('All Hospitals'),
                  tooltip: 'All Hospitals (Emergency Mode)',
                ),
              ],
              selected: {_checkInMode},
              showSelectedIcon: false,
              onSelectionChanged: _isLoading
                  ? null
                  : (selection) =>
                      unawaited(_updateGeofencingMode(selection.first)),
            ),
          ),
          const SizedBox(height: 12),
          if (_checkInMode == 'all') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Emergency Mode: All hospitals within 5km can trigger auto check-in. Continuous high-accuracy location uses more battery.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SectionHeader(
            title: 'Geofence Automation',
            subtitle: 'Auto check-in when you enter a monitored hospital zone',
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.location_on, color: _statusColor),
              title: const Text('Geofence status'),
              subtitle: Text(_status),
              trailing: StatusPill(
                label: _autoCheckInEnabled ? 'ACTIVE' : 'INACTIVE',
                color: _statusColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SwitchListTile(
                  value: _autoCheckInEnabled,
                  onChanged: _toggleGeofence,
                  title: const Text('Enable auto check-in'),
                  subtitle: Text(
                    _checkInMode == 'all'
                        ? 'Automatically check in at any nearby hospital'
                        : 'Automatically check in at trusted hospitals',
                  ),
                ),
          const SizedBox(height: 12),
          // ✅ FIXED: Updated button with feedback
          ElevatedButton.icon(
            onPressed: () async {
              if (!_autoCheckInEnabled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enable geofencing first.')),
                );
                return;
              }

              final triggered = await _geofenceService.testTriggerEnter();
              if (!context.mounted) return;

              if (!triggered) {
                final message = _checkInMode == 'trusted'
                    ? 'No trusted hospitals found. Add one first.'
                    : 'No nearby hospitals discovered. Try refreshing.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(message), backgroundColor: Colors.orange),
                );
              }
              // If triggered, the listener above will show a green snackbar.
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Simulate Hospital Arrival'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClinicalPalette.teal,
            ),
          ),
          if (_checkInMode == 'all') ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    title: 'Nearby Hospitals',
                    subtitle: 'Hospitals discovered within 5km',
                  ),
                ),
                IconButton(
                  onPressed: _isLoadingNearby ? null : _refreshNearbyHospitals,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh nearby hospitals',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoadingNearby)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_nearbyError != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _nearbyError!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              )
            else if (_nearbyHospitals.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No mapped hospitals were found within 5km.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._nearbyHospitals.map(
                (hospital) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_hospital,
                      color: ClinicalPalette.teal,
                    ),
                    title: Text(hospital.name),
                    subtitle: Text(_formatDistance(hospital.distance)),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => _addAsTrusted(hospital),
                      tooltip: 'Add to Trusted',
                    ),
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Hospital data © OpenStreetMap contributors · ODbL',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Trusted Hospitals',
                  subtitle: 'Tap + to add a hospital',
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_location_alt,
                  color: ClinicalPalette.teal,
                ),
                onPressed: _showAddHospitalDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<HospitalLocation>>(
            stream: _geofenceService.hospitalsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final hospitals = snapshot.data ?? [];
              if (hospitals.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.local_hospital,
                          size: 40,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No trusted hospitals added yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _showAddHospitalDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Hospital'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: hospitals
                    .map(
                      (hospital) => Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.local_hospital,
                            color: ClinicalPalette.teal,
                          ),
                          title: Text(hospital.name),
                          subtitle: Text(
                            'Radius: ${hospital.radius.toInt()}m · '
                            '${hospital.lat.toStringAsFixed(4)}, '
                            '${hospital.lng.toStringAsFixed(4)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await _geofenceService
                                  .removeHospital(hospital.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${hospital.name} removed.'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ClinicalPalette.tealSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClinicalPalette.teal.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: ClinicalPalette.teal,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _checkInMode == 'all'
                        ? 'When you enter any discovered hospital zone, MediTrack logs your check-in, shows a notification, and opens your QR code.'
                        : 'When you enter a trusted hospital zone, MediTrack logs your check-in, shows a notification, and opens your QR code.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double distance) {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)}km away';
    }
    return '${distance.toStringAsFixed(0)}m away';
  }
}
