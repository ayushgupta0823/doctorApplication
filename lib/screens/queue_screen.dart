import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_tabs.dart';
import '../widgets/avatar.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';
import 'appointments_screen.dart';
import 'consult_room/consult_room_screen.dart';
import 'patient_details_screen.dart';

enum _QueueFilter { all, waiting, inConsultation, done }

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> with WidgetsBindingObserver {
  _QueueFilter _filter = _QueueFilter.all;
  bool _searching = false;
  final _searchController = TextEditingController();
  Timer? _pollTimer;

  // No live push for appointment updates yet (that's real-time-socket work,
  // not built here) — so poll as a safety net, matching the website's fix
  // for the same "new booking doesn't show up" gap, and refetch whenever the
  // app comes back to the foreground.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) context.read<AppState>().refreshQueue();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppState>().refreshQueue();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(QueuePatient p) {
    switch (_filter) {
      case _QueueFilter.all:
        return true;
      case _QueueFilter.waiting:
        return [ConsultStatus.scheduled, ConsultStatus.confirmed, ConsultStatus.waiting].contains(p.status);
      case _QueueFilter.inConsultation:
        return p.status == ConsultStatus.inProgress;
      case _QueueFilter.done:
        return [ConsultStatus.completed, ConsultStatus.noShow, ConsultStatus.cancelled].contains(p.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final query = _searchController.text.trim().toLowerCase();

    final waitingCount = app.queue.where((p) => [ConsultStatus.scheduled, ConsultStatus.confirmed, ConsultStatus.waiting].contains(p.status)).length;
    final inConsultCount = app.queue.where((p) => p.status == ConsultStatus.inProgress).length;
    final doneCount = app.queue.where((p) => [ConsultStatus.completed, ConsultStatus.noShow, ConsultStatus.cancelled].contains(p.status)).length;

    final filtered = app.queue.where(_matchesFilter).where((p) => query.isEmpty || p.name.toLowerCase().contains(query)).toList();

    Widget body;
    if (app.isLoadingQueue) {
      body = const _QueueSkeletons();
    } else if (app.queue.isEmpty) {
      body = _buildEmptyState(icon: Icons.calendar_today_outlined, title: 'No Appointments Today', subtitle: 'You have no scheduled appointments on your roster today.');
    } else if (filtered.isEmpty) {
      body = _buildEmptyState(icon: Icons.search_off, title: 'No Matches', subtitle: 'No patients match this filter or search.');
    } else {
      body = ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (app.isOffline) _OfflineBanner(lastUpdated: app.lastUpdatedQueue),
          if (app.noShowAlert != null) _NoShowBanner(alert: app.noShowAlert!),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (var i = 0; i < filtered.length; i++)
                  _QueueCard(patient: filtered[i]).animate(delay: (i * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.blue50,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _searching
                        ? TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: const InputDecoration(hintText: 'Search patients...'),
                            onChanged: (_) => setState(() {}),
                          )
                        : Text('Patient Queue', style: AppText.display(size: 20, color: AppColors.blue900)),
                  ),
                  IconButton(
                    icon: Icon(_searching ? Icons.close : Icons.search, color: AppColors.ink900),
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _searchController.clear();
                    }),
                  ),
                ],
              ),
            ),
            AppTabBar(
              style: AppTabStyle.pill,
              selected: _filter,
              onChanged: (v) => setState(() => _filter = v as _QueueFilter),
              tabs: [
                AppTab(label: 'All (${app.queue.length})', value: _QueueFilter.all),
                AppTab(label: 'Waiting ($waitingCount)', value: _QueueFilter.waiting),
                AppTab(label: 'In Consultation ($inConsultCount)', value: _QueueFilter.inConsultation),
                AppTab(label: 'Done ($doneCount)', value: _QueueFilter.done),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(color: AppColors.blue600, backgroundColor: AppColors.white, onRefresh: app.refreshQueue, child: body),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: AppButton(
                  label: '+ Add Walk-in Patient',
                  block: true,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AppointmentsScreen())),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 48),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Container(width: 56, height: 56, decoration: const BoxDecoration(color: AppColors.blue100, shape: BoxShape.circle), child: Icon(icon, size: 24, color: AppColors.blue700)),
                const SizedBox(height: 16),
                Text(title, style: AppText.display(size: 15.5)),
                const SizedBox(height: 6),
                Text(subtitle, textAlign: TextAlign.center, style: AppText.body(size: 12.5, color: AppColors.ink600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class _QueueSkeletons extends StatelessWidget {
  const _QueueSkeletons();

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: List.generate(3, (i) => const _SkeletonCard()),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 40, height: 40, shape: BoxShape.circle),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 120, height: 14),
                const SizedBox(height: 6),
                const SkeletonBox(width: 80, height: 10),
                const SizedBox(height: 10),
                const SkeletonBox(width: 60, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.lastUpdated});
  final DateTime lastUpdated;

  @override
  Widget build(BuildContext context) {
    final hh = lastUpdated.hour.toString().padLeft(2, '0');
    final mm = lastUpdated.minute.toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.ink900.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.ink400.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 16, color: AppColors.ink600),
          const SizedBox(width: 8),
          Expanded(child: Text("You're offline — showing appointments as of $hh:$mm.", style: AppText.body(size: 11.5, color: AppColors.ink600, weight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _NoShowBanner extends StatelessWidget {
  const _NoShowBanner({required this.alert});
  final NoShowAlert alert;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber100,
        border: Border.all(color: AppColors.amberBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.amberDark, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppText.body(size: 12.5, color: AppColors.amberDark),
                    children: [
                      TextSpan(text: alert.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' marked as no-show.\nNext up: '),
                      TextSpan(text: alert.next ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: AppButton(label: 'See Next Patient', small: true, block: true, onPressed: app.seeNextPatient)),
              const SizedBox(width: 8),
              Expanded(child: AppButton(label: 'Dismiss', small: true, block: true, variant: AppButtonVariant.ghost, onPressed: app.dismissNoShow)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.patient});
  final QueuePatient patient;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final canNoShow = [ConsultStatus.scheduled, ConsultStatus.confirmed, ConsultStatus.waiting, ConsultStatus.inProgress].contains(patient.status);
    final isActive = patient.status == ConsultStatus.inProgress;
    final isUrgent = patient.priority == QueuePriority.high;

    final card = AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: patient.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(patient.name, overflow: TextOverflow.ellipsis, style: AppText.display(size: 14.5))),
                    StatusBadge(status: patient.status),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (patient.priority != QueuePriority.normal) ...[
                      _PriorityChip(priority: patient.priority),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text('${patient.age} yrs · ${patient.gender} · ${patient.mode}', style: AppText.body(size: 11.5, color: AppColors.ink600), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(patient.time, style: AppText.mono(size: 11.5, weight: FontWeight.w600, color: AppColors.blue700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppButton(
                      label: 'View Details',
                      small: true,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientDetailsScreen(patientId: patient.id))),
                    ),
                    if (patient.status == ConsultStatus.scheduled)
                      AppButton(label: 'Approve', small: true, icon: const Icon(Icons.check), onPressed: () => app.confirmPatient(patient.id)),
                    if (patient.status == ConsultStatus.confirmed || patient.status == ConsultStatus.waiting)
                      AppButton(
                        label: 'Start Consultation',
                        small: true,
                        variant: AppButtonVariant.success,
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () {
                          app.startNewConsult(patient.id);
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsultRoomScreen()));
                        },
                      ),
                    if (patient.status == ConsultStatus.inProgress)
                      AppButton(
                        label: 'Resume Consultation',
                        small: true,
                        variant: AppButtonVariant.success,
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () {
                          app.resumeConsult(patient.id);
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsultRoomScreen()));
                        },
                      ),
                    if (canNoShow)
                      AppButton(label: 'No-show', small: true, variant: AppButtonVariant.danger, icon: const Icon(Icons.close), onPressed: () => _confirmNoShow(context, app, patient)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Active (in-progress) and urgent patients get a soft tinted glow so
    // they stand out from the rest of the queue at a glance, instead of
    // relying on the status badge/priority chip alone.
    final accent = isActive ? AppColors.orange600 : (isUrgent ? AppColors.red600 : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: accent == null
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 6)),
              ],
            ),
      child: card,
    );
  }

  Future<void> _confirmNoShow(BuildContext context, AppState app, QueuePatient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as no-show?'),
        content: Text('${patient.name} will be marked as a no-show for this appointment. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Mark No-show', style: AppText.body(weight: FontWeight.bold, color: AppColors.red600))),
        ],
      ),
    );
    if (confirmed == true) {
      app.markNoShow(patient.id);
    }
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});
  final QueuePriority priority;

  @override
  Widget build(BuildContext context) {
    final isHigh = priority == QueuePriority.high;
    final bg = isHigh ? AppColors.red100 : AppColors.amber100;
    final fg = isHigh ? AppColors.red600 : AppColors.amber600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isHigh ? Icons.priority_high_rounded : Icons.arrow_upward_rounded, size: 9, color: fg),
          const SizedBox(width: 2),
          Text(priority.label, style: AppText.mono(size: 8, color: fg, weight: FontWeight.bold)),
        ],
      ),
    );
  }
}
