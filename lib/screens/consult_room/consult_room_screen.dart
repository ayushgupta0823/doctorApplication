import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_tabs.dart';
import '../../widgets/avatar.dart';
import 'consultation_history_tab.dart';
import 'consultation_reports_tab.dart';
import 'lab_tests_tab.dart';
import 'prescription_tab.dart';
import 'video_call_screen.dart';

/// The Consultation screen: pushed from the Queue, Patient Details, or
/// Home when a doctor starts/resumes a consult for a specific patient.
/// Call controls live in the header (phone/video icons) rather than as a
/// tab. Clinical tabs: Prescription, Lab Tests, Reports, History.
class ConsultRoomScreen extends StatelessWidget {
  const ConsultRoomScreen({super.key});

  Future<void> _finishConsultation(BuildContext context, AppState app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete this consultation?'),
        content: const Text('This marks the consultation as completed in the queue and returns you there.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      app.completeConsultation();
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmLeaveDuringCall(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the consult room?'),
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

    if (patient == null || patient.status == ConsultStatus.completed || patient.status == ConsultStatus.noShow) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => Navigator.pop(context))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.blue100, shape: BoxShape.circle, boxShadow: AppShadow.sm),
                  child: const Icon(Icons.event_busy_outlined, size: 28, color: AppColors.blue700),
                ),
                const SizedBox(height: 16),
                Text('No Active Consultation', style: AppText.display(size: 16)),
                const SizedBox(height: 6),
                Text('This consultation has already ended.', textAlign: TextAlign.center, style: AppText.body(size: 13, color: AppColors.ink600)),
              ].animate(interval: 60.ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
            ),
          ),
        ),
      );
    }

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
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.of(context).maybePop()),
          titleSpacing: 0,
          title: Row(
            children: [
              InitialsAvatar(name: patient.name, size: 34, fontSize: 12),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(patient.name, overflow: TextOverflow.ellipsis, style: AppText.display(size: 14))),
                        if (patient.isUrgent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(color: AppColors.red100, borderRadius: BorderRadius.circular(100)),
                            child: Text('High Risk Patient', style: AppText.mono(size: 7, color: AppColors.red600, weight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text('${patient.age} Y · ${patient.gender == 'F' ? 'Female' : 'Male'}', style: AppText.body(size: 10.5, color: AppColors.ink600)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (inCall) _CallTimerChip(seconds: app.callSeconds),
            _HeaderIconButton(
              tooltip: 'Video call',
              icon: Icons.videocam,
              active: inCall,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VideoCallScreen())),
            ),
            _HeaderIconButton(
              tooltip: 'Finish consultation',
              icon: Icons.check_circle_outline,
              active: false,
              iconColor: AppColors.green600,
              onPressed: () => _finishConsultation(context, app),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.blue50,
                border: const Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: AppTabBar(
                selected: app.consultSubTab,
                onChanged: (v) => app.setConsultSubTab(v as ConsultSubTab),
                tabs: const [
                  AppTab(label: 'Prescription', value: ConsultSubTab.prescription),
                  AppTab(label: 'Lab Tests', value: ConsultSubTab.labTests),
                  AppTab(label: 'Reports', value: ConsultSubTab.reports),
                  AppTab(label: 'History', value: ConsultSubTab.history),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(app.consultSubTab),
                  child: SingleChildScrollView(child: _buildTab(app.consultSubTab)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(ConsultSubTab tab) {
    switch (tab) {
      case ConsultSubTab.prescription:
        return const PrescriptionTab();
      case ConsultSubTab.labTests:
        return const LabTestsTab();
      case ConsultSubTab.reports:
        return const ConsultationReportsTab();
      case ConsultSubTab.history:
        return const ConsultationHistoryTab();
    }
  }
}

/// Circular tinted icon button used in the Consult Room's app bar —
/// gives the video-call / finish-consultation actions the same "raised
/// chip" treatment as the rest of the design system instead of bare
/// unstyled icons.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onPressed,
    this.iconColor,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? (active ? AppColors.green600 : AppColors.ink900);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: active ? AppColors.green100 : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, color: color, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}

class _CallTimerChip extends StatelessWidget {
  const _CallTimerChip({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.green100,
        borderRadius: BorderRadius.circular(100),
        boxShadow: AppShadow.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.green600, shape: BoxShape.circle))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 700.ms)
              .then()
              .fadeOut(duration: 700.ms),
          const SizedBox(width: 6),
          Text('$mm:$ss', style: AppText.mono(size: 11, weight: FontWeight.w700, color: AppColors.green600)),
        ],
      ),
    );
  }
}

