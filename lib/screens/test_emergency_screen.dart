import 'dart:async';

import 'package:flutter/material.dart';

import '../services/emergency_service.dart';
import '../services/fall_detection_service.dart';
import '../theme/clinical_theme.dart';

/// Debug-only tools for safely exercising the fall-detection flow.
class TestEmergencyScreen extends StatefulWidget {
  const TestEmergencyScreen({super.key});

  @override
  State<TestEmergencyScreen> createState() => _TestEmergencyScreenState();
}

class _TestEmergencyScreenState extends State<TestEmergencyScreen> {
  final _fallService = FallDetectionService()..debugLogging = true;
  final _emergencyService = EmergencyService();
  StreamSubscription<FallSensorSample>? _sampleSubscription;
  StreamSubscription<FallDetectionEvent>? _fallSubscription;
  FallSensorSample? _lastSample;
  double _highestSvm = 0;
  bool _monitoring = false;
  bool _simulating = false;
  String _status = 'Monitoring is off';

  @override
  void initState() {
    super.initState();
    _sampleSubscription = _fallService.onSample.listen((sample) {
      if (mounted) {
        setState(() {
          _lastSample = sample;
          if (sample.svm > _highestSvm) _highestSvm = sample.svm;
        });
      }
    });
    _fallSubscription = _fallService.onFallDetected.listen((_) {
      if (!mounted) return;
      setState(() => _status = 'Fall pattern confirmed');
      unawaited(_showFallDetectedDialog());
    });
  }

  @override
  void dispose() {
    _sampleSubscription?.cancel();
    _fallSubscription?.cancel();
    _fallService.dispose();
    super.dispose();
  }

  Future<void> _toggleMonitoring() async {
    if (_monitoring) {
      await _fallService.stopMonitoring();
      if (mounted) {
        setState(() {
          _monitoring = false;
          _status = 'Monitoring is off';
        });
      }
      return;
    }

    final started = await _fallService.startMonitoring();
    if (mounted) {
      setState(() {
        _monitoring = started;
        _highestSvm = 0;
        _status = started ? 'Listening to device motion' : 'Sensor unavailable';
      });
    }
  }

  Future<void> _simulateFall() async {
    setState(() => _simulating = true);
    final now = DateTime.now();
    _fallService.processSample(svm: 1.0, angularVelocity: 1.5, timestamp: now);
    _fallService.processSample(
      svm: 1.0,
      angularVelocity: 1.5,
      timestamp: now.add(const Duration(milliseconds: 220)),
    );
    _fallService.processSample(
      svm: 28,
      angularVelocity: 2,
      timestamp: now.add(const Duration(milliseconds: 350)),
    );
    _fallService.processSample(
      svm: 9.81,
      angularVelocity: 0.1,
      timestamp: now.add(const Duration(seconds: 1)),
    );
    _fallService.processSample(
      svm: 9.81,
      angularVelocity: 0.1,
      timestamp: now.add(const Duration(seconds: 4)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) setState(() => _simulating = false);
  }

  Future<void> _showFallDetectedDialog() async {
    final timeout = Timer(const Duration(seconds: 20), () {
      if (mounted) Navigator.of(context, rootNavigator: true).pop(true);
    });
    final sendAlert = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Possible fall detected'),
        content: const Text(
          'The fall pattern was detected. SOS will be sent in 20 seconds unless you confirm you are okay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('I am okay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    timeout.cancel();

    if (sendAlert != true || !mounted) return;

    try {
      await _emergencyService.triggerEmergency(
        reason: 'Possible fall detected',
        source: 'fall_detection',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency alert created.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create emergency alert: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _triggerManualTest() async {
    try {
      await _emergencyService.triggerEmergency(
        reason: 'Manual test emergency',
        source: 'test_button',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test emergency event created.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create test event: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sample = _lastSample;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Test Tools')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sensors_rounded, color: ClinicalPalette.teal),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Fall detection',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Chip(
                        label: Text(_monitoring ? 'ACTIVE' : 'OFF'),
                        backgroundColor: (_monitoring ? Colors.green : Colors.grey)
                            .withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_status),
                  if (sample != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Latest: ${sample.svm.toStringAsFixed(1)} m/s^2 | '
                      '${sample.angularVelocity.toStringAsFixed(2)} rad/s',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                    Text(
                      'Highest since start: ${_highestSvm.toStringAsFixed(1)} m/s^2 '
                      '(impact threshold: ${FallDetectionService.impactThreshold.toStringAsFixed(1)})',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _toggleMonitoring,
            icon: Icon(_monitoring ? Icons.stop_rounded : Icons.play_arrow_rounded),
            label: Text(_monitoring ? 'Stop monitoring' : 'Start monitoring'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _simulating ? null : _simulateFall,
            icon: const Icon(Icons.person_pin_circle_outlined),
            label: Text(_simulating ? 'Simulating...' : 'Simulate fall safely'),
          ),
          const SizedBox(height: 28),
          const Text(
            'Manual emergency test',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Creates a test emergency event in Firestore.',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _triggerManualTest,
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Create test event'),
            style: TextButton.styleFrom(foregroundColor: Colors.deepOrange),
          ),
        ],
      ),
    );
  }
}
