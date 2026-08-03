import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meditrack/services/hospital_place_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('queries OSM nodes, ways, and relations and sorts by distance',
      () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'elements': [
            {
              'type': 'way',
              'id': 20,
              'center': {'lat': 6.94, 'lon': 79.86},
              'tags': {'healthcare': 'hospital', 'name': 'Far Hospital'},
            },
            {
              'type': 'node',
              'id': 10,
              'lat': 6.9272,
              'lon': 79.8613,
              'tags': {'amenity': 'hospital', 'name': 'Near Hospital'},
            },
          ],
        }),
        200,
      );
    });

    final service = HospitalPlaceService(
      client: client,
      endpoints: [Uri.parse('https://overpass.test/api/interpreter')],
      retryDelay: Duration.zero,
    );

    final hospitals = await service.findNearbyHospitals(
      latitude: 6.9271,
      longitude: 79.8612,
      forceRefresh: true,
    );

    expect(hospitals.map((hospital) => hospital.name), [
      'Near Hospital',
      'Far Hospital',
    ]);
    expect(hospitals.first.id, 'osm-node-10');
    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.body, contains('nwr%5B%22amenity%22%3D%22hospital'));
    expect(
      capturedRequest.body,
      contains('nwr%5B%22healthcare%22%3D%22hospital'),
    );
    expect(capturedRequest.body, contains('around%3A5000'));
  });

  test('uses another Overpass endpoint after a gateway timeout', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) return http.Response('Gateway timeout', 504);
      return http.Response(
        jsonEncode({
          'elements': [
            {
              'type': 'relation',
              'id': 30,
              'center': {'lat': 6.9272, 'lon': 79.8613},
              'tags': {'amenity': 'hospital', 'name': 'Fallback Hospital'},
            },
          ],
        }),
        200,
      );
    });

    final service = HospitalPlaceService(
      client: client,
      endpoints: [
        Uri.parse('https://first-overpass.test/api/interpreter'),
        Uri.parse('https://second-overpass.test/api/interpreter'),
      ],
      retryDelay: Duration.zero,
    );

    final hospitals = await service.findNearbyHospitals(
      latitude: 6.9271,
      longitude: 79.8612,
      forceRefresh: true,
    );

    expect(calls, 2);
    expect(hospitals.single.name, 'Fallback Hospital');
  });

  test('returns cached hospitals when all Overpass endpoints fail', () async {
    final successfulService = HospitalPlaceService(
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 40,
                  'lat': 6.9272,
                  'lon': 79.8613,
                  'tags': {'amenity': 'hospital', 'name': 'Cached Hospital'},
                },
              ],
            }),
            200,
          )),
      endpoints: [Uri.parse('https://overpass.test/api/interpreter')],
      retryDelay: Duration.zero,
    );
    await successfulService.findNearbyHospitals(
      latitude: 6.9271,
      longitude: 79.8612,
      forceRefresh: true,
    );

    final offlineService = HospitalPlaceService(
      client: MockClient((request) async => http.Response('Unavailable', 503)),
      endpoints: [Uri.parse('https://overpass.test/api/interpreter')],
      retryDelay: Duration.zero,
    );
    final hospitals = await offlineService.findNearbyHospitals(
      latitude: 6.9271,
      longitude: 79.8612,
      forceRefresh: true,
    );

    expect(hospitals.single.name, 'Cached Hospital');
  });
}
