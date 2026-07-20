import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_logo.dart' show AppLogoMark, AppLogoSize;

/// Real phone + OTP login — the same `POST /auth/mobile/send-otp` /
/// `verify-otp` pattern the patient app uses. A brand-new phone number logs
/// in as a `patient`-role account with no doctor profile yet; `AppState`
/// resolves what to show next (`AuthStage`) once verification succeeds, so
/// this screen only needs to drive the two-step phone -> OTP form.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  String _error = '';

  static final _phonePattern = RegExp(r'^\+?\d{10,13}$');

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  String get _normalizedPhone {
    final raw = _phoneCtrl.text.trim();
    return raw.startsWith('+') ? raw : '+91$raw';
  }

  Future<void> _sendOtp() async {
    if (!_phonePattern.hasMatch(_normalizedPhone)) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    setState(() => _error = '');
    final app = context.read<AppState>();
    final result = await app.sendOtp(_normalizedPhone);
    if (!mounted) return;
    if (result) {
      setState(() => _otpSent = true);
    } else {
      setState(() => _error = 'Could not send OTP — please try again.');
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length < 4) {
      setState(() => _error = 'Enter the OTP you received.');
      return;
    }
    setState(() => _error = '');
    final app = context.read<AppState>();
    final ok = await app.verifyOtp(phone: _normalizedPhone, otp: _otpCtrl.text.trim());
    if (!mounted) return;
    if (!ok) setState(() => _error = 'Invalid or expired OTP — please try again.');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.blue50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogoMark(size: AppLogoSize.large)),
              const SizedBox(height: 20),
              Text('MediConnectAI for Doctors', textAlign: TextAlign.center, style: AppText.display(size: 20)),
              const SizedBox(height: 6),
              Text(
                _otpSent ? 'Enter the code sent to $_normalizedPhone' : 'Log in with your registered mobile number',
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, color: AppColors.ink600),
              ),
              const SizedBox(height: 28),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: _otpSent ? _otpStep(app) : _phoneStep(app),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, textAlign: TextAlign.center, style: AppText.body(size: 12.5, color: AppColors.red600, weight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneStep(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('MOBILE NUMBER', style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ink600).copyWith(letterSpacing: .3)),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          style: AppText.body(size: 14),
          decoration: const InputDecoration(hintText: '+91 98765 43210', prefixIcon: Icon(Icons.phone_outlined, size: 18)),
        ),
        const SizedBox(height: 18),
        AppButton(label: 'Send OTP', block: true, loading: app.otpSending, onPressed: app.otpSending ? null : _sendOtp),
      ],
    );
  }

  Widget _otpStep(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ENTER OTP', style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ink600).copyWith(letterSpacing: .3)),
        const SizedBox(height: 6),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: AppText.body(size: 18, weight: FontWeight.w700).copyWith(letterSpacing: 4),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(counterText: '', hintText: '••••'),
        ),
        if (app.devOtp != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Dev OTP: ${app.devOtp}', textAlign: TextAlign.center, style: AppText.body(size: 11.5, color: AppColors.ink400)),
          ),
        const SizedBox(height: 8),
        AppButton(label: 'Verify & Continue', block: true, loading: app.otpVerifying, onPressed: app.otpVerifying ? null : _verifyOtp),
        const SizedBox(height: 10),
        AppButton(
          label: 'Change number',
          variant: AppButtonVariant.ghost,
          block: true,
          onPressed: () => setState(() {
            _otpSent = false;
            _otpCtrl.clear();
            _error = '';
          }),
        ),
      ],
    );
  }
}
