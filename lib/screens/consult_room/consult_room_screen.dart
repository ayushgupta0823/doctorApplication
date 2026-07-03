import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import 'ai_tools_tab.dart';
import 'consultation_history_tab.dart';
import 'consultation_reports_tab.dart';
import 'lab_tests_tab.dart';
import 'prescription_tab.dart';
import 'video_call_screen.dart';

/// The Consultation screen: pushed from the Queue, Patient Details, or
/// Home when a doctor starts/resumes a consult for a specific patient.
/// Call controls live in the header (phone/video icons) rather than as a
/// tab, matching the reference design's 5 clinical tabs: Notes,
/// Prescription, Lab Tests, Reports, History.
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
                Container(width: 64, height: 64, decoration: const BoxDecoration(color: AppColors.blue100, shape: BoxShape.circle), child: const Icon(Icons.event_busy_outlined, size: 28, color: AppColors.blue700)),
                const SizedBox(height: 16),
                Text('No Active Consultation', style: AppText.display(size: 16)),
                const SizedBox(height: 6),
                Text('This consultation has already ended.', textAlign: TextAlign.center, style: AppText.body(size: 13, color: AppColors.ink600)),
              ],
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
            IconButton(
              tooltip: 'Video call',
              icon: Icon(Icons.videocam, color: inCall ? AppColors.green600 : AppColors.ink900, size: 21),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VideoCallScreen())),
            ),
            IconButton(
              tooltip: 'Finish consultation',
              icon: const Icon(Icons.check_circle_outline, color: AppColors.green600, size: 22),
              onPressed: () => _finishConsultation(context, app),
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _SubTab(label: 'Notes', active: app.consultSubTab == ConsultSubTab.notes, onTap: () => app.setConsultSubTab(ConsultSubTab.notes)),
                  _SubTab(label: 'Prescription', active: app.consultSubTab == ConsultSubTab.prescription, onTap: () => app.setConsultSubTab(ConsultSubTab.prescription)),
                  _SubTab(label: 'Lab Tests', active: app.consultSubTab == ConsultSubTab.labTests, onTap: () => app.setConsultSubTab(ConsultSubTab.labTests)),
                  _SubTab(label: 'Reports', active: app.consultSubTab == ConsultSubTab.reports, onTap: () => app.setConsultSubTab(ConsultSubTab.reports)),
                  _SubTab(label: 'History', active: app.consultSubTab == ConsultSubTab.history, onTap: () => app.setConsultSubTab(ConsultSubTab.history)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
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
      case ConsultSubTab.notes:
        return const AiToolsTab();
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

class _CallTimerChip extends StatelessWidget {
  const _CallTimerChip({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: AppColors.green100, borderRadius: BorderRadius.circular(100)),
      child: Text('$mm:$ss', style: AppText.mono(size: 11, weight: FontWeight.w700, color: AppColors.green600)),
    );
  }
}

class _SubTab extends StatelessWidget {
  const _SubTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? AppColors.blue600 : Colors.transparent, width: 2))),
          alignment: Alignment.center,
          child: Text(label, style: AppText.body(size: 12.5, weight: FontWeight.w700, color: active ? AppColors.blue700 : AppColors.ink400)),
        ),
      ),
    );
  }
}
