import 'dart:async';

/// Test-only trigger tracker. Android/iOS do not expose physical power-button
/// presses to ordinary Flutter apps, so this is deliberately not presented as
/// a hardware power-button detector.
class PowerButtonService {
  final _controller = StreamController<void>.broadcast();
  Stream<void> get onEmergencyGesture => _controller.stream;
  bool _listening = false;

  void startListening() => _listening = true;
  void stopListening() => _listening = false;

  /// Lets the test screen exercise the five-press gesture behaviour.
  void registerTestPress() {
    if (_listening) _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}
