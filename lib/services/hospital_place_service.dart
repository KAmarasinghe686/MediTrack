import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NearbyHospital {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double distance;
  final double radius;

  const NearbyHospital({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.distance,
    this.radius = 300,
  });

  NearbyHospital withDistanceFrom(double latitude, double longitude) {
    return NearbyHospital(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      distance: Geolocator.distanceBetween(
        latitude,
        longitude,
        lat,
        lng,
      ),
      radius: radius,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius': radius,
      };

  factory NearbyHospital.fromJson(Map<String, dynamic> json) {
    return NearbyHospital(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Unnamed hospital',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      distance: 0,
      radius: (json['radius'] as num?)?.toDouble() ?? 300,
    );
  }
}

class HospitalDiscoveryException implements Exception {
  final String message;

  const HospitalDiscoveryException(this.message);

  @override
  String toString() => message;
}

class HospitalPlaceService {
  static const double searchRadiusMeters = 5000;
  static const String _cacheKey = 'nearby_osm_hospitals_v2';

  static final List<Uri> _defaultEndpoints = [
    Uri.parse('https://maps.mail.ru/osm/tools/overpass/api/interpreter'),
    Uri.parse('https://overpass-api.de/api/interpreter'),
  ];

  final http.Client _client;
  final List<Uri> _endpoints;
  final Duration requestTimeout;
  final Duration retryDelay;
  final Duration cacheFreshness;
  final Duration staleCacheLifetime;

  HospitalPlaceService({
    http.Client? client,
    List<Uri>? endpoints,
    this.requestTimeout = const Duration(seconds: 25),
    this.retryDelay = const Duration(milliseconds: 800),
    this.cacheFreshness = const Duration(hours: 6),
    this.staleCacheLifetime = const Duration(days: 7),
  })  : _client = client ?? http.Client(),
        _endpoints = List.unmodifiable(endpoints ?? _defaultEndpoints);

  Future<List<NearbyHospital>> findNearbyHospitals({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final cached = _readCache(preferences);

    if (!forceRefresh &&
        cached != null &&
        _canUseCache(cached, latitude, longitude, cacheFreshness)) {
      return _sortAndMeasure(cached.hospitals, latitude, longitude);
    }

    Object? lastFailure;

    for (var index = 0; index < _endpoints.length; index++) {
      try {
        final response = await _client.post(
          _endpoints[index],
          headers: {
            'Accept': 'application/json',
            if (!kIsWeb)
              'User-Agent': 'MediTrack/1.0 (OpenStreetMap hospital lookup)',
          },
          body: {
            'data': _buildQuery(latitude, longitude),
          },
        ).timeout(requestTimeout);

        if (response.statusCode == 200) {
          final hospitals = _parseHospitals(
            response.body,
            latitude,
            longitude,
          );

          if (hospitals.isEmpty) {
            await preferences.remove(_cacheKey);
          } else {
            await _writeCache(
              preferences,
              hospitals,
              latitude,
              longitude,
            );
          }
          return hospitals;
        }

        if (!_isRetryableStatus(response.statusCode)) {
          throw HospitalDiscoveryException(
            _messageForStatus(response.statusCode),
          );
        }
        lastFailure = 'Overpass returned HTTP ${response.statusCode}.';
      } on HospitalDiscoveryException {
        rethrow;
      } on TimeoutException {
        lastFailure = 'The OpenStreetMap request timed out.';
      } on http.ClientException catch (error) {
        lastFailure = error;
      } catch (error) {
        lastFailure = error;
      }

      if (index < _endpoints.length - 1 && retryDelay > Duration.zero) {
        await Future<void>.delayed(
          Duration(milliseconds: retryDelay.inMilliseconds * (index + 1)),
        );
      }
    }

    if (cached != null &&
        _canUseCache(cached, latitude, longitude, staleCacheLifetime)) {
      return _sortAndMeasure(cached.hospitals, latitude, longitude);
    }

    throw HospitalDiscoveryException(
      'The public OpenStreetMap servers did not respond. '
              'Try refreshing again in a moment. ${lastFailure ?? ''}'
          .trim(),
    );
  }

  String _buildQuery(double latitude, double longitude) {
    return '''
[out:json][timeout:20];
(
  nwr["amenity"="hospital"](around:5000,$latitude,$longitude);
  nwr["healthcare"="hospital"](around:5000,$latitude,$longitude);
);
out tags center;
''';
  }

  List<NearbyHospital> _parseHospitals(
    String responseBody,
    double latitude,
    double longitude,
  ) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>? ?? const [];
    final hospitalsById = <String, NearbyHospital>{};

    for (final rawElement in elements) {
      if (rawElement is! Map<String, dynamic>) continue;

      final type = rawElement['type']?.toString();
      final osmId = rawElement['id']?.toString();
      if (type == null || osmId == null) continue;

      final center = rawElement['center'] as Map<String, dynamic>?;
      final latValue = rawElement['lat'] ?? center?['lat'];
      final lngValue = rawElement['lon'] ?? center?['lon'];
      if (latValue is! num || lngValue is! num) continue;

      final tags = rawElement['tags'] as Map<String, dynamic>? ?? const {};
      final name = _hospitalName(tags);
      final hospital = NearbyHospital(
        id: 'osm-$type-$osmId',
        name: name,
        lat: latValue.toDouble(),
        lng: lngValue.toDouble(),
        distance: 0,
      ).withDistanceFrom(latitude, longitude);

      if (hospital.distance <= searchRadiusMeters) {
        hospitalsById[hospital.id] = hospital;
      }
    }

    final hospitals = hospitalsById.values.toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));
    return hospitals;
  }

  String _hospitalName(Map<String, dynamic> tags) {
    const possibleNames = ['name', 'name:en', 'official_name', 'operator'];
    for (final key in possibleNames) {
      final value = tags[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return 'Unnamed hospital';
  }

  bool _isRetryableStatus(int statusCode) {
    return statusCode == 408 ||
        statusCode == 429 ||
        statusCode == 403 ||
        statusCode == 406 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504 ||
        statusCode >= 500;
  }

  String _messageForStatus(int statusCode) {
    if (statusCode == 400) {
      return 'OpenStreetMap rejected the hospital search query.';
    }
    if (statusCode == 403 || statusCode == 406) {
      return 'The OpenStreetMap server refused the hospital search request.';
    }
    return 'OpenStreetMap hospital lookup failed with HTTP $statusCode.';
  }

  bool _canUseCache(
    _HospitalCache cache,
    double latitude,
    double longitude,
    Duration maximumAge,
  ) {
    final age = DateTime.now().difference(cache.cachedAt);
    if (age.isNegative || age > maximumAge) return false;

    final moved = Geolocator.distanceBetween(
      latitude,
      longitude,
      cache.originLatitude,
      cache.originLongitude,
    );
    return moved <= 1000;
  }

  List<NearbyHospital> _sortAndMeasure(
    List<NearbyHospital> hospitals,
    double latitude,
    double longitude,
  ) {
    final measured = hospitals
        .map((hospital) => hospital.withDistanceFrom(latitude, longitude))
        .where((hospital) => hospital.distance <= searchRadiusMeters)
        .toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));
    return measured;
  }

  _HospitalCache? _readCache(SharedPreferences preferences) {
    final stored = preferences.getString(_cacheKey);
    if (stored == null) return null;

    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      final hospitalJson = json['hospitals'] as List<dynamic>;
      return _HospitalCache(
        cachedAt: DateTime.parse(json['cachedAt'].toString()),
        originLatitude: (json['originLatitude'] as num).toDouble(),
        originLongitude: (json['originLongitude'] as num).toDouble(),
        hospitals: hospitalJson
            .whereType<Map<String, dynamic>>()
            .map(NearbyHospital.fromJson)
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    SharedPreferences preferences,
    List<NearbyHospital> hospitals,
    double latitude,
    double longitude,
  ) async {
    await preferences.setString(
      _cacheKey,
      jsonEncode({
        'cachedAt': DateTime.now().toIso8601String(),
        'originLatitude': latitude,
        'originLongitude': longitude,
        'hospitals': hospitals.map((hospital) => hospital.toJson()).toList(),
      }),
    );
  }
}

class _HospitalCache {
  final DateTime cachedAt;
  final double originLatitude;
  final double originLongitude;
  final List<NearbyHospital> hospitals;

  const _HospitalCache({
    required this.cachedAt,
    required this.originLatitude,
    required this.originLongitude,
    required this.hospitals,
  });
}
