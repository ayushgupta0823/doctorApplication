import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/api/api.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';

/// Real lab data in two parts, both backed by genuine (non-stub) backend
/// routes: platform-wide critical alerts (`GET /lab/critical-alerts`), and
/// per-patient shared reports (`GET /lab/reports/patient/:id`) for anyone
/// on today's queue with a real patient record — walk-ins with no backend
/// record are excluded rather than shown with fabricated data.
class LabOrdersScreen extends StatefulWidget {
  const LabOrdersScreen({super.key});

  @override
  State<LabOrdersScreen> createState() => _LabOrdersScreenState();
}

class _LabOrdersScreenState extends State<LabOrdersScreen> {
  bool _loadingAlerts = true;
  String? _alertsError;
  List<Map<String, dynamic>> _alerts = [];

  QueuePatient? _selectedPatient;
  bool _loadingReports = false;
  String? _reportsError;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _loadingAlerts = true;
      _alertsError = null;
    });
    try {
      final alerts = await Api.lab.getCriticalAlerts();
      if (!mounted) return;
      setState(() => _alerts = alerts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _alertsError = context.read<AppState>().describeError(e));
    } finally {
      if (mounted) setState(() => _loadingAlerts = false);
    }
  }

  Future<void> _selectPatient(QueuePatient p) async {
    setState(() {
      _selectedPatient = p;
      _loadingReports = true;
      _reportsError = null;
      _reports = [];
    });
    try {
      final reports = await Api.lab.getReportsForPatient(p.patientRecordId!);
      if (!mounted) return;
      setState(() => _reports = reports);
    } catch (e) {
      if (!mounted) return;
      setState(() => _reportsError = context.read<AppState>().describeError(e));
    } finally {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final knownPatients = app.queue.where((p) => p.patientRecordId != null).toList();

    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Lab Orders', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('CRITICAL ALERTS', style: AppText.mono(size: 10, color: AppColors.red600, weight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_loadingAlerts)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_alertsError != null)
              AppCard(
                padding: EdgeInsets.zero,
                child: Center(
                  child: EmptyState(
                    icon: Icons.error_outline,
                    iconColor: AppColors.red600,
                    iconBackground: AppColors.red100,
                    message: 'Could not load critical alerts — $_alertsError',
                  ),
                ),
              )
            else if (_alerts.isEmpty)
              AppCard(
                padding: EdgeInsets.zero,
                child: Center(
                  child: EmptyState(icon: Icons.verified_outlined, message: 'No critical biomarker alerts right now.'),
                ),
              )
            else
              ..._alerts.asMap().entries.map((entry) => AppCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.red600),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${entry.value['biomarker'] ?? entry.value['title'] ?? 'Critical result'}',
                            style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.red600),
                          ),
                        ),
                      ],
                    ),
                  ).animate(delay: (entry.key * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut)),
            const SizedBox(height: 22),
            Text('VIEW A PATIENT\'S SHARED REPORTS', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (knownPatients.isEmpty)
              AppCard(
                padding: EdgeInsets.zero,
                child: Center(
                  child: EmptyState(icon: Icons.people_outline, message: 'No patients with a linked record in today\'s queue.'),
                ),
              )
            else
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: knownPatients.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final p = knownPatients[i];
                    final active = p.id == _selectedPatient?.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => _selectPatient(p),
                      child: Container(
                        width: 68,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: active ? AppColors.blue100 : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: active ? AppColors.blue600 : Colors.transparent),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InitialsAvatar(name: p.name, size: 34, fontSize: 11),
                            const SizedBox(height: 4),
                            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 9.5, weight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 14),
            if (_selectedPatient != null) ...[
              if (_loadingReports)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (_reportsError != null)
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Center(
                    child: EmptyState(
                      icon: Icons.error_outline,
                      iconColor: AppColors.red600,
                      iconBackground: AppColors.red100,
                      message: 'Could not load reports — $_reportsError',
                    ),
                  ),
                )
              else if (_reports.isEmpty)
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Center(
                    child: EmptyState(
                      icon: Icons.biotech_outlined,
                      message: '${_selectedPatient!.name} hasn\'t shared any lab reports with you.',
                    ),
                  ),
                )
              else
                ..._reports.asMap().entries.map((entry) => AppCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.biotech_outlined, size: 18, color: AppColors.blue700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${entry.value['testName'] ?? entry.value['title'] ?? 'Lab report'}', style: AppText.body(size: 12.5, weight: FontWeight.w700)),
                                Text('${entry.value['status'] ?? ''}', style: AppText.body(size: 11, color: AppColors.ink600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: (entry.key * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut)),
            ],
          ],
        ),
      ),
    );
  }
}
