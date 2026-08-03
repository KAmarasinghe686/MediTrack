import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hashes the local app-lock PIN before it is stored in Firestore. This is an
/// app convenience lock, not a replacement for Firebase Authentication.
class PinSecurityService {
  static const _pinLockEnabledKey = 'pin_lock_enabled';

  /// Persists the user's most recent choice on this device. Firestore remains
  /// the cross-device source of truth, but startup must not resurrect an old
  /// cloud value after the user has just disabled the lock.
  static Future<void> cachePinLockEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_pinLockEnabledKey, enabled);
  }

  static Future<bool?> cachedPinLockEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_pinLockEnabledKey);
  }

  static String createSalt() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  static String hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
