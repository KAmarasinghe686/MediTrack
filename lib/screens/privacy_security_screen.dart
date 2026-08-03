import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../services/pin_security_service.dart';
import '../services/qr_service.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  static const _galleryChannel = MethodChannel('meditrack/gallery');
  bool _pinLock = false;
  bool _qrSharing = true;
  bool _dataSharing = false;
  bool _isLoading = true;

  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final GlobalKey _qrImageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final cachedPinLock = await PinSecurityService.cachedPinLockEnabled();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('privacy')
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _pinLock = cachedPinLock ?? (data['pinLock'] ?? false);
          _qrSharing = data['qrSharing'] ?? true;
          _dataSharing = data['dataSharing'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _pinLock = cachedPinLock ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pinLock = cachedPinLock ?? false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (_pinLock) {
      if (_pinController.text.isEmpty || _pinController.text.length < 4) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a 4-digit PIN'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_pinController.text != _confirmPinController.text) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PINs do not match!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    try {
      // Disabling a local app lock must take effect even when Firestore is
      // offline or its queued write has not reached the server yet.
      if (!_pinLock) {
        await PinSecurityService.cachePinLockEnabled(false);
      }
      final privacyRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('privacy');
      final pinSalt = _pinLock ? PinSecurityService.createSalt() : null;
      final batch = FirebaseFirestore.instance.batch();
      batch.set(privacyRef, {
        'pinLock': _pinLock,
        'pinHash': _pinLock
            ? PinSecurityService.hashPin(_pinController.text, pinSalt!)
            : FieldValue.delete(),
        'pinSalt': _pinLock ? pinSalt : FieldValue.delete(),
        'pin': FieldValue.delete(),
        'qrSharing': _qrSharing,
        'dataSharing': _dataSharing,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // A disabled sharing setting must invalidate an already-issued QR token;
      // otherwise a photo of an old QR could still grant access.
      if (!_qrSharing) {
        batch.delete(FirebaseFirestore.instance.collection('qr_tokens').doc(userId));
      }
      await batch.commit();
      await PinSecurityService.cachePinLockEnabled(_pinLock);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Privacy settings saved!'),
          backgroundColor: Colors.green,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showQRCodeDialog() async {
    if (!_qrSharing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Turn on QR Code Sharing first.')),
      );
      return;
    }

    final accessData = await QRService().getPatientAccessData();
    if (!mounted) return;
    if (accessData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the access QR code.')),
      );
      return;
    }
    final accessUrl = accessData['url']!;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your Medical QR Code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Show this only to people you want to access your record.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _qrImageKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: QrImageView(
                    data: accessUrl,
                    version: QrVersions.auto,
                    size: 200,
                    gapless: false,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Scan this QR to open your secured medical profile',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        SharePlus.instance.share(
                          ShareParams(
                            text: 'Access my MediTrack medical profile: $accessUrl',
                          ),
                        );
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveQrToGallery,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveQrToGallery() async {
    try {
      final renderObject = _qrImageKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('QR image is not ready yet.');
      }
      final image = await renderObject.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) throw StateError('Could not create the QR image.');
      await _galleryChannel.invokeMethod<void>('savePngToGallery', {
        'bytes': Uint8List.fromList(bytes),
        'name': 'meditrack_access_qr_${DateTime.now().millisecondsSinceEpoch}',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('QR code saved to your gallery.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Could not save QR code: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Security Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage PIN lock and sharing preferences',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                Card(
                  child: ExpansionTile(
                    leading: Icon(
                      Icons.lock_outline,
                      color: _pinLock ? Colors.blue : Colors.grey,
                    ),
                    title: const Text('PIN Lock'),
                    subtitle: Text(_pinLock ? 'PIN is enabled' : 'PIN is disabled'),
                    children: [
                      SwitchListTile(
                        title: const Text('Enable PIN Lock'),
                        subtitle: const Text('Require PIN to open the app'),
                        value: _pinLock,
                        onChanged: (value) async {
                          setState(() {
                            _pinLock = value;
                            if (!value) {
                              _pinController.clear();
                              _confirmPinController.clear();
                            }
                          });
                          if (!value) {
                            await PinSecurityService.cachePinLockEnabled(false);
                          }
                        },
                      ),
                      if (_pinLock) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Enter 4-digit PIN',
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _confirmPinController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm PIN',
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.qr_code),
                    title: const Text('QR Code'),
                    subtitle: const Text('View, share or save your QR code'),
                    trailing: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                      onPressed: _showQRCodeDialog,
                    ),
                    onTap: _showQRCodeDialog,
                  ),
                ),

                Card(
                  child: SwitchListTile(
                    title: const Text('QR Code Sharing'),
                    subtitle: const Text('Allow others to scan your QR'),
                    value: _qrSharing,
                    onChanged: (value) {
                      setState(() => _qrSharing = value);
                    },
                    secondary: Icon(
                      _qrSharing ? Icons.share : Icons.share,
                      color: _qrSharing ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),

                Card(
                  child: SwitchListTile(
                    title: const Text('Data Sharing'),
                    subtitle: const Text('Share anonymized data for research'),
                    value: _dataSharing,
                    onChanged: (value) {
                      setState(() => _dataSharing = value);
                    },
                    secondary: Icon(
                      _dataSharing ? Icons.data_usage : Icons.data_usage,
                      color: _dataSharing ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Save Settings'),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Settings are saved to your account',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
    );
  }
}
