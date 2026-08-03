import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/pin_security_service.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const PinLockScreen({super.key, required this.onSuccess});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _enteredPin = '';
  bool _isError = false;

  Future<bool> _verifyPin() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('privacy')
        .get();

    if (!doc.exists) return false;
    final data = doc.data()!;
    final savedHash = data['pinHash']?.toString();
    final salt = data['pinSalt']?.toString();
    if (savedHash != null && salt != null) {
      return PinSecurityService.hashPin(_enteredPin, salt) == savedHash;
    }

    // Compatibility for existing users. Their PIN is migrated to a hash after
    // one successful unlock, then the raw value is removed.
    final legacyPin = data['pin']?.toString() ?? '';
    if (_enteredPin != legacyPin) return false;
    final newSalt = PinSecurityService.createSalt();
    try {
      await doc.reference.update({
        'pinHash': PinSecurityService.hashPin(_enteredPin, newSalt),
        'pinSalt': newSalt,
        'pin': FieldValue.delete(),
      });
    } catch (_) {
      // A successful legacy PIN must still unlock the app if a temporary
      // network issue prevents the one-time migration.
    }
    return true;
  }

  void _addDigit(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _isError = false;
      });
      if (_enteredPin.length == 4) {
        _verifyPin().then((isValid) {
          if (isValid) {
            widget.onSuccess();
          } else {
            setState(() {
              _isError = true;
              _enteredPin = '';
            });
          }
        });
      }
    }
  }

  void _deleteDigit() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _isError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Enter PIN',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isError ? 'Invalid PIN. Try again.' : 'Enter your 4-digit PIN',
                style: TextStyle(
                  fontSize: 14,
                  color: _isError ? Colors.red : Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isError ? Colors.red : Colors.grey,
                        width: 2,
                      ),
                      color: index < _enteredPin.length
                          ? Colors.blue
                          : Colors.transparent,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.2,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  if (index == 9) return Container();
                  if (index == 10) return Container();
                  if (index == 11) {
                    return IconButton(
                      icon: const Icon(Icons.backspace, size: 28),
                      onPressed: _deleteDigit,
                    );
                  }
                  final digit = (index + 1).toString();
                  return ElevatedButton(
                    onPressed: () => _addDigit(digit),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20),
                    ),
                    child: Text(
                      digit,
                      style: const TextStyle(fontSize: 28),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
