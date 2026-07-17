import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import 'call_tab.dart';

/// Full-screen video call, pushed from the Consultation screen's video
/// icon rather than living as one of the 5 clinical tabs (Notes,
/// Prescription, Lab Tests, Reports, History) — matches the new design,
/// where call controls live in the header, not the tab bar.
class VideoCallScreen extends StatelessWidget {
  const VideoCallScreen({super.key});

  Future<bool> _confirmLeaveDuringCall(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the call?'),
        content: const Text('The video call is still active. Leaving now will end the call for the patient.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('End Call & Leave')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final patient = app.activePatient;
    final inCall = app.rtcState == 'connected' || app.rtcState == 'reconnecting';

    return PopScope(
      canPop: !inCall,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _confirmLeaveDuringCall(context);
        if (shouldLeave && context.mounted) {
          app.endCall();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.blue50,
        appBar: AppBar(
          backgroundColor: AppColors.blue50,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.line),
          ),
          title: Row(
            children: [
              InitialsAvatar(name: patient?.name ?? '—', size: 32, fontSize: 11),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient?.name ?? 'Video Call', style: AppText.display(size: 14.5), overflow: TextOverflow.ellipsis),
                    Text(_statusLabel(app.rtcState), style: AppText.body(size: 10.5, color: _statusColor(app.rtcState), weight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: const SingleChildScrollView(child: CallTab()),
      ),
    );
  }

  String _statusLabel(String rtcState) {
    switch (rtcState) {
      case 'connecting':
        return 'Connecting…';
      case 'connected':
        return 'Live';
      case 'reconnecting':
        return 'Reconnecting…';
      default:
        return 'Not connected';
    }
  }

  Color _statusColor(String rtcState) {
    switch (rtcState) {
      case 'connecting':
        return AppColors.blue600;
      case 'connected':
        return AppColors.green600;
      case 'reconnecting':
        return AppColors.amber600;
      default:
        return AppColors.ink400;
    }
  }
}
