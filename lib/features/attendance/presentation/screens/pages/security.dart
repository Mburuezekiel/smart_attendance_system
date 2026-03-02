import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isBiometricEnabled = false;
  bool _isSupported = false;
  String _status = 'Biometrics not set up.';

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics;
    bool isDeviceSupported;
    try {
      canCheckBiometrics = await _auth.canCheckBiometrics;
      isDeviceSupported = await _auth.isDeviceSupported();
      _isSupported = canCheckBiometrics && isDeviceSupported;
      if (!_isSupported) {
        setState(() {
          _status = 'Biometric auth not available or device not supported.';
        });
        return;
      }
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Error checking biometrics: ${e.message}';
      });
      return;
    }

    setState(() {
      _status = _isBiometricEnabled
          ? 'Biometric authentication is enabled.'
          : 'Biometric authentication is disabled.';
    });
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      // local_auth v3: use authMessages + direct named params, no AuthenticationOptions
      authenticated = await _auth.authenticate(
        localizedReason: 'Scan your fingerprint or face to authenticate',
        biometricOnly: true,
        persistAcrossBackgrounding: true, // replaces stickyAuth in v3
      );
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Error during authentication: ${e.message}';
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      if (authenticated) {
        _isBiometricEnabled = true;
        _status = 'Biometric authentication has been successfully enabled.';
      } else {
        _isBiometricEnabled = false;
        _status = 'Failed to authenticate. Biometrics remain disabled.';
      }
    });
  }

  void _toggleBiometrics(bool value) {
    if (value) {
      _authenticate();
    } else {
      setState(() {
        _isBiometricEnabled = false;
        _status = 'Biometric authentication has been disabled.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            context.go('/settings');
          },
        ),
        title: const Text('Security & Biometrics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('Enable Biometric Authentication'),
              subtitle: Text(_status),
              value: _isBiometricEnabled,
              onChanged: _isSupported ? _toggleBiometrics : null,
              secondary: Icon(
                _isBiometricEnabled
                    ? Icons.fingerprint
                    : Icons.fingerprint_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(),
            const SizedBox(height: 20),
            Text(
              'Enabling biometrics allows you to quickly and securely sign in to your account using your fingerprint or face.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}