import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class SecurityPrivacyScreen extends StatelessWidget {
  const SecurityPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Security & Privacy', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.draw_outlined, color: AppColors.blue700),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Digital Signature', style: AppText.body(size: 13, weight: FontWeight.bold)),
                      Text(
                        app.digitalSignature.isNotEmpty ? 'Configured for ${app.digitalSignature}' : 'Not yet configured',
                        style: AppText.body(size: 11, color: AppColors.ink600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.lock, size: 16, color: AppColors.green600),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.fingerprint, color: AppColors.blue700),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Biometric App Lock', style: AppText.body(size: 13, weight: FontWeight.bold)),
                      Text('Lock the app immediately; unlock with Face ID / fingerprint next time.', style: AppText.body(size: 11, color: AppColors.ink600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppButton(label: 'Lock App Now', variant: AppButtonVariant.danger, icon: const Icon(Icons.lock_outline, size: 16), block: true, onPressed: app.lockApp),
          const SizedBox(height: 20),
          Text(
            'All clinical data is stored securely on this device and synced only through encrypted channels once a backend is connected. Your digital signature is applied server-side and is never transmitted unlocked.',
            style: AppText.body(size: 11.5, color: AppColors.ink400),
          ),
        ],
      ),
    );
  }
}
