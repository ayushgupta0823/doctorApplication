import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'invite_application_screen.dart';

/// Entry point for the hospital-invite flow. A real deployment would deep-
/// link straight here from the emailed invite URL (needs Android App Links /
/// iOS Universal Links pointed at the hospital-admin's domain — infra setup
/// outside this app's code); until that's wired up, the doctor pastes the
/// invite link or its token directly.
class InviteEntryScreen extends StatefulWidget {
  const InviteEntryScreen({super.key});

  @override
  State<InviteEntryScreen> createState() => _InviteEntryScreenState();
}

class _InviteEntryScreenState extends State<InviteEntryScreen> {
  final _inputCtrl = TextEditingController();
  bool _loading = false;
  bool _confirming = false;
  String _error = '';
  Map<String, dynamic>? _invite;
  String? _token;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  /// Accepts either a bare token or a full `.../invite/accept?token=...` URL.
  String? _extractToken(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;
    final uri = Uri.tryParse(input);
    final fromQuery = uri?.queryParameters['token'];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
    return input;
  }

  Future<void> _lookUp() async {
    final token = _extractToken(_inputCtrl.text);
    if (token == null) {
      setState(() => _error = 'Paste your invite link or code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
      _invite = null;
    });
    final invite = await context.read<AppState>().loadInvite(token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (invite == null) {
        _error = "Couldn't find that invite — check the link/code and try again.";
      } else if (invite['type'] != 'doctor') {
        _error = 'This invite is not a doctor invite.';
      } else {
        _invite = invite;
        _token = token;
      }
    });
  }

  Future<void> _confirmAndContinue() async {
    final invite = _invite;
    final token = _token;
    if (invite == null || token == null) return;
    setState(() => _confirming = true);
    final email = invite['email'] as String?;
    if (email != null) {
      final err = await context.read<AppState>().setMyEmail(email);
      if (err != null) {
        if (!mounted) return;
        setState(() {
          _confirming = false;
          _error = err;
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() => _confirming = false);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => InviteApplicationScreen(token: token, invite: invite)));
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        title: Text('Hospital Invite', style: AppText.display(size: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paste the invite link or code a hospital admin sent you by email.',
                style: AppText.body(size: 13, color: AppColors.ink600),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 3,
                      style: AppText.body(size: 13),
                      decoration: const InputDecoration(hintText: 'https://.../invite/accept?token=... or the code itself'),
                    ),
                    const SizedBox(height: 12),
                    AppButton(label: 'Look Up Invite', block: true, loading: _loading, onPressed: _loading ? null : _lookUp),
                  ],
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: AppText.body(size: 12.5, color: AppColors.red600, weight: FontWeight.w600)),
              ],
              if (invite != null) ...[
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Invite found', style: AppText.display(size: 14)),
                      const SizedBox(height: 8),
                      Text('Hospital: ${invite['hospitalName'] ?? 'Unknown'}', style: AppText.body(size: 13)),
                      Text('Sent to: ${invite['email'] ?? '—'}', style: AppText.body(size: 13, color: AppColors.ink600)),
                      const SizedBox(height: 14),
                      Text(
                        "By continuing, this invite's email will be linked to your account.",
                        style: AppText.body(size: 11.5, color: AppColors.ink400),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Confirm & Continue',
                        block: true,
                        loading: _confirming,
                        onPressed: _confirming ? null : _confirmAndContinue,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
