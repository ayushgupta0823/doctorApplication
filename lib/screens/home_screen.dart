import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/avatar.dart';
import '../widgets/notifications_dialog.dart';
import 'appointments_screen.dart';
import 'consult_room/consult_room_screen.dart';
import 'profile_screen.dart';

/// The Home tab: a daily control-center landing view (greeting, live queue
/// snapshot, next consultation countdown, risk alerts, quick actions, and
/// AI insights) — always reachable from the bottom nav rather than a
/// one-time screen the doctor leaves behind.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _countdownTimer;
  int _minsRemaining = 12;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_minsRemaining > 1) {
        setState(() => _minsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startOrResume(AppState app, QueuePatient patient) {
    if (patient.status == ConsultStatus.inProgress) {
      app.resumeConsult(patient.id);
    } else {
      app.startNewConsult(patient.id);
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsultRoomScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final total = app.queue.length;
    final waiting = app.queue.where((p) => p.status == ConsultStatus.waiting).length;
    final completed = app.queue.where((p) => p.status == ConsultStatus.completed).length;
    final inProgress = app.queue.where((p) => p.status == ConsultStatus.inProgress).length;
    final pending = app.queue.where((p) => p.status == ConsultStatus.confirmed || p.status == ConsultStatus.scheduled).length;

    final activePatients = app.queue.where((p) =>
        p.status == ConsultStatus.waiting || p.status == ConsultStatus.confirmed || p.status == ConsultStatus.scheduled || p.status == ConsultStatus.inProgress);
    final nextPatient = activePatients.isNotEmpty ? activePatients.first : null;

    final riskPatients = app.queue.where((p) => p.riskSummary.tags.isNotEmpty && p.status != ConsultStatus.completed).toList();
    final followUpCount = app.queue.where((p) => p.riskSummary.recentLabAbnormalities != 'None' && p.status != ConsultStatus.completed).length;

    return Scaffold(
      backgroundColor: AppColors.blue50,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: Row(
                      children: [
                        InitialsAvatar(name: app.doctorDisplayName, size: 46, fontSize: 15),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Good Morning,',
                                style: AppText.body(size: 11, color: AppColors.ink600, weight: FontWeight.w600),
                              ),
                              Text(
                                app.doctorDisplayName,
                                style: AppText.display(size: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                app.doctorQualificationsLabel,
                                style: AppText.body(size: 10, color: AppColors.ink400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Switch(
                      value: app.isOnline,
                      activeThumbColor: AppColors.green600,
                      onChanged: app.setAvailability,
                    ),
                    IconButton(
                      tooltip: 'Notifications',
                      icon: Badge(
                        isLabelVisible: app.unreadNotificationCount > 0,
                        label: Text('${app.unreadNotificationCount}'),
                        child: const Icon(Icons.notifications_outlined, size: 20),
                      ),
                      onPressed: () => showNotificationsDialog(context, app),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Live queue card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.blue700, AppColors.blue900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LIVE PATIENT QUEUE',
                                style: AppText.mono(size: 10, color: AppColors.blue100, weight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('$waiting Patients Waiting', style: AppText.display(size: 20, color: AppColors.white)),
                            const SizedBox(height: 6),
                            Text(
                              inProgress > 0 ? '$inProgress active consultation currently' : 'Select a patient to begin consultation',
                              style: AppText.body(size: 12, color: AppColors.blue100),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.people_alt_outlined, color: AppColors.white, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () => app.setTab(RootTab.queue),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(100)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('View Queue', style: AppText.body(size: 11.5, weight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 13, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (nextPatient != null) ...[
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    InitialsAvatar(name: nextPatient.name, size: 36, fontSize: 12),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NEXT CONSULTATION', style: AppText.mono(size: 9, color: AppColors.blue700, weight: FontWeight.w700)),
                          Text(nextPatient.name, style: AppText.body(size: 13, weight: FontWeight.bold)),
                          Text('${nextPatient.mode} · ${nextPatient.time}', style: AppText.body(size: 11, color: AppColors.ink600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(100)),
                      child: Text('in $_minsRemaining mins', style: AppText.mono(size: 11, color: AppColors.blue700, weight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (riskPatients.isNotEmpty) ...[
              Text('ATTENTION REQUIRED', style: AppText.mono(size: 10, color: AppColors.red600, weight: FontWeight.bold)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: riskPatients.expand((p) {
                    return p.riskSummary.tags.map((t) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.red100,
                            border: Border.all(color: AppColors.red600.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning, size: 12, color: AppColors.red600),
                              const SizedBox(width: 5),
                              Text('${p.name}: $t', style: AppText.body(size: 11, color: AppColors.red600, weight: FontWeight.w600)),
                            ],
                          ),
                        ));
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
            ],

            Text("TODAY'S SUMMARY", style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _HomeStat(label: 'Total', value: total, color: AppColors.blue700)),
                const SizedBox(width: 8),
                Expanded(child: _HomeStat(label: 'Waiting', value: waiting + pending, color: AppColors.amber600)),
                const SizedBox(width: 8),
                Expanded(child: _HomeStat(label: 'In Progress', value: inProgress, color: AppColors.blue600)),
                const SizedBox(width: 8),
                Expanded(child: _HomeStat(label: 'Completed', value: completed, color: AppColors.green600)),
              ],
            ),
            const SizedBox(height: 20),

            Text('QUICK ACTIONS', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
              children: [
                _QuickAction(
                  icon: Icons.play_circle_outline,
                  label: 'Start Consultation',
                  color: AppColors.green600,
                  onTap: nextPatient == null ? null : () => _startOrResume(app, nextPatient),
                ),
                _QuickAction(
                  icon: Icons.assignment_outlined,
                  label: 'Open Queue',
                  color: AppColors.blue600,
                  onTap: () => app.setTab(RootTab.queue),
                ),
                _QuickAction(
                  icon: Icons.event_note_outlined,
                  label: 'Appointments',
                  color: AppColors.tealDark,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AppointmentsScreen())),
                ),
                _QuickAction(
                  icon: Icons.medication_outlined,
                  label: 'New Prescription',
                  color: AppColors.amber600,
                  onTap: nextPatient == null ? null : () => _startOrResume(app, nextPatient),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('AI INSIGHTS', style: AppText.mono(size: 10, color: AppColors.tealDark, weight: FontWeight.bold)),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (followUpCount > 0)
                    _InsightRow(icon: Icons.event_repeat, text: '$followUpCount patient${followUpCount == 1 ? '' : 's'} need follow-up today'),
                  if (riskPatients.isNotEmpty)
                    _InsightRow(icon: Icons.warning_amber_rounded, text: 'High risk patient in queue', color: AppColors.red600),
                  if (followUpCount == 0 && riskPatients.isEmpty)
                    _InsightRow(icon: Icons.check_circle_outline, text: 'No urgent flags — queue looks steady', color: AppColors.green600),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _HomeStat extends StatelessWidget {
  const _HomeStat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        children: [
          Text('$value', style: AppText.mono(size: 16, weight: FontWeight.bold, color: color)),
          Text(label, style: AppText.body(size: 9.5, color: AppColors.ink600, weight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label, style: AppText.body(size: 11.5, weight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.icon, required this.text, this.color = AppColors.tealDark});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.ink900))),
        ],
      ),
    );
  }
}
