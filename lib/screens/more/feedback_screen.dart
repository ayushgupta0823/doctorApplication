import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

const _kSupportEmail = 'support@mediconnectai.app';

/// A genuinely real action: composes an email to the support address via
/// the device's mail client, prefilled with the doctor's message and
/// account context — there's no in-app feedback-submission endpoint, so
/// this is honest about where the message actually goes.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(AppState app) async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write something before sending.');
      return;
    }
    setState(() => _error = null);
    final uri = Uri(
      scheme: 'mailto',
      path: _kSupportEmail,
      query: 'subject=${Uri.encodeComponent('MediConnectAI Doctor App Feedback')}'
          '&body=${Uri.encodeComponent('$text\n\n— ${app.doctorDisplayName}')}',
    );
    final launched = await launchUrl(uri);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No mail app is configured on this device.'), backgroundColor: AppColors.red600),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Feedback', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text("Tell us what's working and what isn't. This opens your mail app addressed to $_kSupportEmail.", style: AppText.body(size: 12.5, color: AppColors.ink600)),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 10,
            decoration: const InputDecoration(hintText: 'Your feedback…'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: AppText.body(size: 11.5, color: AppColors.red600)),
          ],
          const SizedBox(height: 16),
          AppButton(label: 'Send Feedback', icon: const Icon(Icons.send_outlined, size: 16), block: true, onPressed: () => _send(app)),
        ].animate(interval: 60.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
      ),
    );
  }
}
