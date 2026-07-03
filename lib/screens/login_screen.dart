import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/otp_box_input.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _inputController = TextEditingController();
  final _otpBoxKey = GlobalKey<OtpBoxInputState>();
  String _otp = '';
  bool _otpSent = false;
  int _countdown = 30;
  Timer? _timer;
  String _error = '';

  void _startTimer() {
    setState(() => _countdown = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        _timer?.cancel();
      }
    });
  }

  void _handleSendOtp() {
    final val = _inputController.text.trim();
    if (val.isEmpty) {
      setState(() => _error = 'Please enter a valid email or mobile number.');
      return;
    }
    final app = context.read<AppState>();
    app.sendOtp(val);
    setState(() {
      _error = '';
      _otpSent = true;
      // There's no real SMS/email gateway behind this demo — auto-fill the
      // code the mock backend actually issued so "the OTP never arrives"
      // isn't a dead end. Matches the pre-filled boxes in the design too.
      _otp = app.otpCode;
    });
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpBoxKey.currentState?.fill(app.otpCode);
    });
  }

  void _handleVerifyOtp() {
    if (_otp.length != 4) {
      setState(() => _error = 'Please enter the 4-digit verification code.');
      return;
    }
    final success = context.read<AppState>().verifyOtp(_otp);
    if (!success) {
      setState(() => _error = 'Invalid OTP. Please try again.');
    }
  }

  void _changeContact() {
    setState(() {
      _otpSent = false;
      _otp = '';
      _error = '';
    });
    _timer?.cancel();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      body: SafeArea(
        child: Stack(
          children: [
            if (_otpSent)
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.ink900),
                  onPressed: _changeContact,
                ),
              ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BrandIcon(icon: _otpSent ? Icons.mark_chat_read_outlined : Icons.local_hospital_rounded),
                    const SizedBox(height: 16),
                    if (!_otpSent) ...[
                      Text(
                        'MediConnectAI',
                        textAlign: TextAlign.center,
                        style: AppText.display(size: 24, color: AppColors.blue900),
                      ),
                      Text(
                        'Doctor Companion App',
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 13, color: AppColors.ink600, weight: FontWeight.w500),
                      ),
                    ],
                    const SizedBox(height: 32),
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _otpSent ? 'Enter OTP' : 'Welcome Back, Doctor 👋',
                            textAlign: TextAlign.center,
                            style: AppText.display(size: 17),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _otpSent
                                ? 'A 4-digit code has been sent to\n${_inputController.text}'
                                : 'Sign in using your registered mobile number or email',
                            textAlign: TextAlign.center,
                            style: AppText.body(size: 12.5, color: AppColors.ink600),
                          ),
                          const SizedBox(height: 22),
                          if (!_otpSent) ...[
                            Text(
                              'Mobile Number or Email',
                              style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.ink600),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _inputController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'e.g. dr.rhea@mediconnect.ai',
                              ),
                            ),
                          ] else ...[
                            OtpBoxInput(
                              key: _otpBoxKey,
                              length: 4,
                              autoFocus: false,
                              onChanged: (v) => setState(() => _otp = v),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: Text(
                                _countdown > 0 ? 'Resend code in ${_countdown}s' : "Didn't receive code?",
                                style: AppText.body(size: 12, color: AppColors.ink400),
                              ),
                            ),
                            if (_countdown == 0)
                              Center(
                                child: TextButton(
                                  onPressed: _handleSendOtp,
                                  child: Text(
                                    'Resend OTP',
                                    style: AppText.body(size: 12, color: AppColors.blue600, weight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(_error, textAlign: TextAlign.center, style: AppText.body(size: 12, color: AppColors.red600)),
                          ],
                          const SizedBox(height: 20),
                          AppButton(
                            label: _otpSent ? 'Verify OTP' : 'Send OTP',
                            icon: Icon(_otpSent ? Icons.lock_outline : Icons.send_outlined, size: 16),
                            variant: AppButtonVariant.primary,
                            block: true,
                            onPressed: _otpSent ? _handleVerifyOtp : _handleSendOtp,
                          ),
                          if (_otpSent) ...[
                            const SizedBox(height: 10),
                            AppButton(
                              label: 'Change Email / Phone',
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              variant: AppButtonVariant.ghost,
                              block: true,
                              onPressed: _changeContact,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TrustLine(
                      text: _otpSent ? 'Your data is 100% secure and encrypted.' : 'Secure. Private. Trusted.',
                    ),
                    if (!_otpSent) ...[
                      const SizedBox(height: 20),
                      Text(
                        'By signing in, you agree to our Clinical Terms of Service and HIPAA Privacy Disclosures.',
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 11, color: AppColors.ink400),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blue600, AppColors.blue700],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(29, 111, 224, 0.25), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 34, color: Colors.white),
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_outlined, size: 13, color: AppColors.ink400),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 11, color: AppColors.ink400, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
