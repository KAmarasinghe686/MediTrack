import 'package:flutter_test/flutter_test.dart';
import '../lib/services/fall_detection_service.dart';

void main() {
  test('confirms sustained free-fall, impact, then three seconds of inactivity', () async {
    final service = FallDetectionService();
    final events = <FallDetectionEvent>[];
    final subscription = service.onFallDetected.listen(events.add);
    final now = DateTime(2026, 1, 1);

    service.processSample(svm: 1, angularVelocity: 1, timestamp: now);
    service.processSample(
      svm: 1,
      angularVelocity: 1,
      timestamp: now.add(const Duration(milliseconds: 220)),
    );
    service.processSample(
      svm: 26,
      angularVelocity: 2,
      timestamp: now.add(const Duration(milliseconds: 350)),
    );
    service.processSample(
      svm: 9.81,
      angularVelocity: 0.1,
      timestamp: now.add(const Duration(seconds: 1)),
    );
    service.processSample(
      svm: 9.81,
      angularVelocity: 0.1,
      timestamp: now.add(const Duration(seconds: 4)),
    );

    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
    await subscription.cancel();
    await service.dispose();
  });

  test('does not confirm below the impact threshold', () async {
    final service = FallDetectionService();
    final events = <FallDetectionEvent>[];
    final subscription = service.onFallDetected.listen(events.add);
    final now = DateTime(2026, 1, 1);

    service.processSample(svm: 12, angularVelocity: 3, timestamp: now);
    service.processSample(
      svm: 9.81,
      angularVelocity: 0.1,
      timestamp: now.add(const Duration(seconds: 3)),
    );

    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    await subscription.cancel();
    await service.dispose();
  });

  test('confirms the held-phone path after motion, impact, and stillness',
      () async {
    final service = FallDetectionService();
    final events = <FallDetectionEvent>[];
    final subscription = service.onFallDetected.listen(events.add);
    final now = DateTime(2026, 1, 1);

    service.processSample(svm: 12, angularVelocity: 1.2, timestamp: now);
    service.processSample(
      svm: 14,
      angularVelocity: 1.4,
      timestamp: now.add(const Duration(milliseconds: 350)),
    );
    service.processSample(
      svm: 9.81,
      angularVelocity: 0.1,
      timestamp: now.add(const Duration(seconds: 1)),
    );
    service.processSample(
      svm: 9.81,
      angularVelocity: 0.1,
      timestamp: now.add(const Duration(seconds: 2)),
    );

    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
    await subscription.cancel();
    await service.dispose();
  });
}
