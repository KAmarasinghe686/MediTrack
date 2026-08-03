import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'hospital_place_service.dart';
import 'notification_service.dart';

enum CheckInMode { trusted, all }

class HospitalLocation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radius;

  const HospitalLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.radius = 300.0,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius': radius,
      };

  factory HospitalLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HospitalLocation(
      id: doc.id,
      name: data['name'] ?? 'Unknown Hospital',
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      radius: (data['radius'] as num?)?.toDouble() ?? 300.0,
    );
  }

  factory HospitalLocation.fromNearbyHospital(NearbyHospital hospital) {
    return HospitalLocation(
      id: hospital.id,
      name: hospital.name,
      lat: hospital.lat,
      lng: hospital.lng,
      radius: hospital.radius,
    );
  }
}

class GeofenceService {
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;
  GeofenceService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HospitalPlaceService _hospitalPlaceService = HospitalPlaceService();

  StreamSubscription<Position>? _positionStream;
  List<HospitalLocation> _trustedHospitals = [];
  List<NearbyHospital> _nearbyHospitals = [];
  final Map<String, bool> _insideState = {};
  CheckInMode _checkInMode = CheckInMode.trusted;
  Position? _lastDiscoveryPosition;
  DateTime? _lastDiscoveryAt;
  bool _isRefreshingNearby = false;

  bool get isGeofencing => _positionStream != null;
  CheckInMode get checkInMode => _checkInMode;
  List<NearbyHospital> get nearbyHospitals =>
      List.unmodifiable(_nearbyHospitals);

  final StreamController<HospitalLocation> _enterController =
      StreamController<HospitalLocation>.broadcast();
  Stream<HospitalLocation> get onHospitalEnter => _enterController.stream;

  final StreamController<List<NearbyHospital>> _nearbyController =
      StreamController<List<NearbyHospital>>.broadcast();
  Stream<List<NearbyHospital>> get onNearbyHospitalsChanged =>
      _nearbyController.stream;

  Future<bool> requestPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    return permission != LocationPermission.deniedForever;
  }

  Future<void> loadHospitals() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _trustedHospitals = [];
      return;
    }

    final snapshot = await _db
        .collection('trusted_hospitals')
        .where('userId', isEqualTo: userId)
        .get();

    _trustedHospitals = snapshot.docs
        .map((doc) => HospitalLocation.fromFirestore(doc))
        .toList();
  }

  Future<void> addHospital(HospitalLocation hospital) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _db.collection('trusted_hospitals').add({
      ...hospital.toMap(),
      'userId': userId,
      'addedAt': FieldValue.serverTimestamp(),
    });

    await loadHospitals();
  }

  Future<void> removeHospital(String hospitalId) async {
    await _db.collection('trusted_hospitals').doc(hospitalId).delete();
    await loadHospitals();
  }

  Stream<List<HospitalLocation>> hospitalsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();

    return _db
        .collection('trusted_hospitals')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HospitalLocation.fromFirestore(doc))
            .toList());
  }

  Future<bool> updateCheckInMode(CheckInMode mode) async {
    if (isGeofencing) {
      await stopGeofencing();
      return startGeofencing(mode: mode);
    }
    return _prepareMode(mode);
  }

  Future<bool> _prepareMode(CheckInMode mode) async {
    _checkInMode = mode;
    _insideState.clear();

    if (mode == CheckInMode.trusted) {
      await loadHospitals();
      return true;
    }

    if (!await requestPermissions()) return false;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    await refreshNearbyHospitals(position: position);
    return true;
  }

  Future<List<NearbyHospital>> refreshNearbyHospitals({
    Position? position,
    bool forceRefresh = false,
  }) async {
    final currentPosition = position ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

    final hospitals = await _hospitalPlaceService.findNearbyHospitals(
      latitude: currentPosition.latitude,
      longitude: currentPosition.longitude,
      forceRefresh: forceRefresh,
    );

    _nearbyHospitals = hospitals;
    _lastDiscoveryPosition = currentPosition;
    _lastDiscoveryAt = DateTime.now();

    final activeIds = hospitals.map((hospital) => hospital.id).toSet();
    _insideState.removeWhere((id, _) => !activeIds.contains(id));
    _nearbyController.add(List.unmodifiable(hospitals));
    return nearbyHospitals;
  }

  Future<bool> startGeofencing({
    CheckInMode mode = CheckInMode.trusted,
  }) async {
    if (!await requestPermissions()) return false;
    if (!await _prepareMode(mode)) return false;

    await stopGeofencing();
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: mode == CheckInMode.all ? 50 : 25,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _handlePosition,
      onError: (_) {},
    );
    return true;
  }

  void _handlePosition(Position position) {
    if (_checkInMode == CheckInMode.all && _shouldRefreshNearby(position)) {
      unawaited(_refreshNearbyAndCheck(position));
      return;
    }
    unawaited(_checkGeofences(position));
  }

  bool _shouldRefreshNearby(Position position) {
    if (_isRefreshingNearby) return false;
    if (_lastDiscoveryPosition == null || _lastDiscoveryAt == null) return true;

    final movedDistance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _lastDiscoveryPosition!.latitude,
      _lastDiscoveryPosition!.longitude,
    );
    final cacheAge = DateTime.now().difference(_lastDiscoveryAt!);
    return movedDistance >= 1000 || cacheAge >= const Duration(minutes: 15);
  }

  Future<void> _refreshNearbyAndCheck(Position position) async {
    _isRefreshingNearby = true;
    try {
      await refreshNearbyHospitals(position: position);
    } catch (_) {
      // Continue checking the last cached hospital list if discovery is offline.
    } finally {
      _isRefreshingNearby = false;
    }
    await _checkGeofences(position);
  }

  List<HospitalLocation> get _activeHospitals {
    if (_checkInMode == CheckInMode.trusted) return _trustedHospitals;
    return _nearbyHospitals.map(HospitalLocation.fromNearbyHospital).toList();
  }

  Future<void> _checkGeofences(Position position) async {
    for (final hospital in _activeHospitals) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        hospital.lat,
        hospital.lng,
      );

      final isInside = distance <= hospital.radius;
      final wasInside = _insideState[hospital.id] ?? false;

      if (isInside && !wasInside) {
        // Set state before awaiting so overlapping GPS updates cannot duplicate it.
        _insideState[hospital.id] = true;
        await _logEvent('ENTER', hospital);
      } else if (!isInside && wasInside) {
        _insideState[hospital.id] = false;
        await _logEvent('EXIT', hospital);
      }
    }
  }

  Future<void> _logEvent(
    String eventType,
    HospitalLocation hospital,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _db.collection('geofence_events').add({
      'patientId': userId,
      'event': eventType,
      'hospitalName': hospital.name,
      'hospitalId': hospital.id,
      'checkInMode': _checkInMode.name,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (eventType == 'ENTER') {
      _enterController.add(hospital);
      unawaited(NotificationService.showImmediateNotification(
        title: 'Hospital check-in',
        body: '📍 Auto checked in at ${hospital.name}',
      ));
    }
  }

  // ✅ FIXED: Now returns bool to indicate if simulation succeeded
  Future<bool> testTriggerEnter() async {
    if (_checkInMode == CheckInMode.trusted) {
      await loadHospitals();
    } else if (_nearbyHospitals.isEmpty) {
      await refreshNearbyHospitals();
    }

    final hospitals = _activeHospitals;
    if (hospitals.isNotEmpty) {
      _enterController.add(hospitals.first);
      return true;
    }
    return false;
  }

  Future<void> stopGeofencing() async {
    final subscription = _positionStream;
    _positionStream = null;
    await subscription?.cancel();
  }
}