import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final _localAuth = LocalAuthentication();
  bool _checkingSupport = true;
  bool _biometricsAvailable = false;
  bool _authenticating = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    bool supported = false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final deviceSupported = await _localAuth.isDeviceSupported();
      supported = canCheck || deviceSupported;
    } catch (_) {
      supported = false;
    }
    if (mounted) {
      setState(() {
        _biometricsAvailable = supported;
        _checkingSupport = false;
      });
    }
  }

  Future<void> _unlock(AppState app) async {
    setState(() {
      _authenticating = true;
      _error = '';
    });
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Unlock MediConnectAI to resume your workspace session',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (!mounted) return;
      if (didAuthenticate) {
        app.unlockApp();
      } else {
        setState(() => _error = 'Authentication was cancelled.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Biometric authentication failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.blue50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.fingerprint_outlined,
                size: 72,
                color: AppColors.blue600,
              ),
              const SizedBox(height: 16),
              Text(
                'Application Locked',
                textAlign: TextAlign.center,
                style: AppText.display(size: 20, color: AppColors.blue900),
              ),
              const SizedBox(height: 6),
              Text(
                'MediConnectAI has locked due to inactivity or manual security command.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, color: AppColors.ink600),
              ),
              const SizedBox(height: 32),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Re-authenticate',
                      style: AppText.display(size: 15),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _checkingSupport
                          ? 'Checking device biometric capability…'
                          : _biometricsAvailable
                              ? 'Use biometric credentials to restore your active workspace session securely.'
                              : 'No biometric hardware is enrolled on this device. Use password log out to sign back in.',
                      style: AppText.body(size: 12, color: AppColors.ink600),
                      textAlign: TextAlign.center,
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error,
                        style: AppText.body(size: 12, color: AppColors.red600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_checkingSupport)
                      const Center(child: CircularProgressIndicator())
                    else if (_biometricsAvailable)
                      AppButton(
                        label: _authenticating ? 'Authenticating…' : 'Unlock with Face ID / Fingerprint',
                        variant: AppButtonVariant.primary,
                        icon: const Icon(Icons.face),
                        loading: _authenticating,
                        block: true,
                        onPressed: _authenticating ? null : () => _unlock(app),
                      ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: 'Use Password Log Out',
                      variant: AppButtonVariant.ghost,
                      block: true,
                      onPressed: app.logout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
