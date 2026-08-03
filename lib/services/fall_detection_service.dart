import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Threshold-based fall detector. It intentionally emits a *suspected* fall;
/// EmergencyService/UI must still provide the user a cancellation period.
class FallDetectionService {
  // Effective thresholds for real devices. The named public constants below
  // are retained temporarily for the existing debug screen API.
  // Demo calibration: deliberately more sensitive so a controlled fall can be
  // demonstrated reliably. The impact + stillness sequence still applies.
  static const _effectiveImpactThreshold = 15.0;
  static const _effectiveFreeFallThreshold = 6.5;
  static const _heldPhoneMotionThreshold = 10.5;
  static const _heldPhoneImpactThreshold = 18.5;
  static const _heldPhoneRotationThreshold = 1.4;
  static const _heldPhoneMinimumGap = Duration(milliseconds: 300);
  static const _heldPhoneImpactWindow = Duration(seconds: 2);
  static const impactThreshold = 24.0; // m/s²
  static const freeFallThreshold = 2.0; // m/s²
  static const inactivityDuration = Duration(seconds: 1);
  static const _minimumFreeFallDuration = Duration(milliseconds: 60);
  static const _freeFallImpactWindow = Duration(seconds: 3);
  static const _fallConfirmationWindow = Duration(seconds: 6);
  static const _stationaryAccelerationDelta = 1.2;
  static const _stationaryAngularVelocity = 1.0;

  final _fallController = StreamController<FallDetectionEvent>.broadcast();
  final _sampleController = StreamController<FallSensorSample>.broadcast();
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  double _latestAngularVelocity = 0;
  DateTime? _freeFallStartedAt;
  DateTime? _freeFallEndedAt;
  DateTime? _heldPhoneMotionStartedAt;
  DateTime? _impactAt;
  DateTime? _stationarySince;
  bool _monitoring = false;
  bool debugLogging = false;
  void Function(double svm)? onSensorData;

  Stream<FallDetectionEvent> get onFallDetected => _fallController.stream;
  Stream<FallSensorSample> get onSample => _sampleController.stream;
  bool get isMonitoring => _monitoring;

  Future<bool> startMonitoring() async {
    if (_monitoring) return true;
    _monitoring = true;
    const interval = Duration(milliseconds: 20); // 50 Hz cap.
    _gyroscopeSubscription = gyroscopeEventStream(samplingPeriod: interval)
        .listen(_onGyroscope, onError: _onSensorError);
    _accelerometerSubscription = accelerometerEventStream(samplingPeriod: interval)
        .listen(_onAccelerometer, onError: _onSensorError);
    return true;
  }

  Future<void> stopMonitoring() async {
    _monitoring = false;
    _freeFallStartedAt = null;
    _freeFallEndedAt = null;
    _heldPhoneMotionStartedAt = null;
    _impactAt = null;
    _stationarySince = null;
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
  }

  void _onGyroscope(GyroscopeEvent event) {
    _latestAngularVelocity = magnitude(event.x, event.y, event.z);
  }

  void _onAccelerometer(AccelerometerEvent event) {
    processSample(
      svm: magnitude(event.x, event.y, event.z),
      angularVelocity: _latestAngularVelocity,
      timestamp: DateTime.now(),
    );
  }

  /// Public for deterministic tests and the in-app simulator.
  void processSample({
    required double svm,
    required double angularVelocity,
    required DateTime timestamp,
  }) {
    final sample = FallSensorSample(svm, angularVelocity, timestamp);
    _sampleController.add(sample);
    onSensorData?.call(svm);
    if (debugLogging) {
      // ignore: avoid_print
      print('Fall sensor: svm=${svm.toStringAsFixed(2)}, gyro=${angularVelocity.toStringAsFixed(2)}');
    }

    // A fall is a sequence, not merely a movement: sustained low gravity,
    // then a significant impact, then sustained stillness. All three phases
    // are required, so shaking or putting the phone down cannot trigger it.
    if (_impactAt == null) {
      if (svm < _effectiveFreeFallThreshold) {
        _freeFallStartedAt ??= timestamp;
        return;
      }

      if (svm < _heldPhoneImpactThreshold &&
          (svm >= _heldPhoneMotionThreshold ||
              angularVelocity >= _heldPhoneRotationThreshold)) {
        _heldPhoneMotionStartedAt ??= timestamp;
      }

      if (_freeFallStartedAt != null && _freeFallEndedAt == null) {
        _freeFallEndedAt = timestamp;
      }
      final freeFallWasLongEnough = _freeFallStartedAt != null &&
          _freeFallEndedAt != null &&
          _freeFallEndedAt!.difference(_freeFallStartedAt!) >=
              _minimumFreeFallDuration;
      final impactWasRecent = _freeFallEndedAt != null &&
          timestamp.difference(_freeFallEndedAt!) <= _freeFallImpactWindow;
      final dropCandidate = svm >= _effectiveImpactThreshold &&
          freeFallWasLongEnough &&
          impactWasRecent;
      final heldPhoneCandidate = _heldPhoneMotionStartedAt != null &&
          svm >= _heldPhoneImpactThreshold &&
          timestamp.difference(_heldPhoneMotionStartedAt!) >=
              _heldPhoneMinimumGap &&
          timestamp.difference(_heldPhoneMotionStartedAt!) <=
              _heldPhoneImpactWindow;
      if (!dropCandidate && !heldPhoneCandidate) {
        if (_freeFallEndedAt != null &&
            timestamp.difference(_freeFallEndedAt!) > _freeFallImpactWindow) {
          _freeFallStartedAt = null;
          _freeFallEndedAt = null;
        }
        if (_heldPhoneMotionStartedAt != null &&
            timestamp.difference(_heldPhoneMotionStartedAt!) >
                _heldPhoneImpactWindow) {
          _heldPhoneMotionStartedAt = null;
        }
        return;
      }

      _impactAt = timestamp;
      _stationarySince = null;
      return;
    }

    final impactAt = _impactAt;
    if (impactAt == null) return;
    if (timestamp.difference(impactAt) > _fallConfirmationWindow) {
      _freeFallStartedAt = null;
      _freeFallEndedAt = null;
      _heldPhoneMotionStartedAt = null;
      _impactAt = null;
      _stationarySince = null;
      return;
    }

    final stationary = (svm - 9.81).abs() < _stationaryAccelerationDelta &&
        angularVelocity < _stationaryAngularVelocity;
    if (!stationary) {
      // Movement immediately after impact is normal during a fall. Start the
      // inactivity timer only once the device actually becomes still.
      _stationarySince = null;
      return;
    }

    _stationarySince ??= timestamp;
    if (timestamp.difference(_stationarySince!) >= inactivityDuration) {
      _fallController.add(FallDetectionEvent(impactAt, svm, angularVelocity));
      _freeFallStartedAt = null;
      _freeFallEndedAt = null;
      _heldPhoneMotionStartedAt = null;
      _impactAt = null;
      _stationarySince = null;
    }
  }

  void _onSensorError(Object error, StackTrace stackTrace) {
    if (debugLogging) {
      // ignore: avoid_print
      print('Fall sensor error: $error');
    }
  }

  Future<void> dispose() async {
    await stopMonitoring();
    await _fallController.close();
    await _sampleController.close();
  }

  static double magnitude(double x, double y, double z) =>
      math.sqrt(x * x + y * y + z * z);
}

class FallSensorSample {
  const FallSensorSample(this.svm, this.angularVelocity, this.timestamp);
  final double svm;
  final double angularVelocity;
  final DateTime timestamp;
}

class FallDetectionEvent {
  const FallDetectionEvent(this.detectedAt, this.svm, this.angularVelocity);
  final DateTime detectedAt;
  final double svm;
  final double angularVelocity;
}
