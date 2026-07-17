import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/avatar.dart';
import '../widgets/status_badge.dart';

enum _ApptFilter { upcoming, completed, cancelled, all }

/// Appointments: today's schedule viewed by status, distinct from the
/// Queue tab (which is about acting on who's waiting right now).
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  _ApptFilter _filter = _ApptFilter.upcoming;

  bool _matches(QueuePatient p) {
    switch (_filter) {
      case _ApptFilter.upcoming:
        return [ConsultStatus.scheduled, ConsultStatus.confirmed, ConsultStatus.waiting, ConsultStatus.inProgress].contains(p.status);
      case _ApptFilter.completed:
        return p.status == ConsultStatus.completed;
      case _ApptFilter.cancelled:
        return p.status == ConsultStatus.noShow || p.status == ConsultStatus.cancelled;
      case _ApptFilter.all:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = app.queue.where(_matches).toList();

    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Appointments', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _FilterChip(label: 'Upcoming', active: _filter == _ApptFilter.upcoming, onTap: () => setState(() => _filter = _ApptFilter.upcoming)),
                const SizedBox(width: 6),
                _FilterChip(label: 'Completed', active: _filter == _ApptFilter.completed, onTap: () => setState(() => _filter = _ApptFilter.completed)),
                const SizedBox(width: 6),
                _FilterChip(label: 'Cancelled', active: _filter == _ApptFilter.cancelled, onTap: () => setState(() => _filter = _ApptFilter.cancelled)),
                const SizedBox(width: 6),
                _FilterChip(label: 'All', active: _filter == _ApptFilter.all, onTap: () => setState(() => _filter = _ApptFilter.all)),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text('No appointments in this view.', style: AppText.body(size: 13, color: AppColors.ink400)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final p = list[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Row(
                          children: [
                            InitialsAvatar(name: p.name, size: 40, fontSize: 13),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: AppText.body(size: 13.5, weight: FontWeight.bold)),
                                  Text('${p.mode} · ${p.time}', style: AppText.body(size: 11.5, color: AppColors.ink600)),
                                ],
                              ),
                            ),
                            StatusBadge(status: p.status),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.blue600,
        onPressed: () => _showAddWalkIn(context, app),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddWalkIn(BuildContext context, AppState app) {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    String gender = 'F';
    String mode = 'Consultation';
    String error = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add Walk-in Patient', style: AppText.display(size: 15)),
                  const SizedBox(height: 14),
                  TextField(controller: nameController, decoration: const InputDecoration(hintText: 'Patient name')),
                  const SizedBox(height: 10),
                  TextField(controller: ageController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Age')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'F', label: Text('Female')),
                            ButtonSegment(value: 'M', label: Text('Male')),
                          ],
                          selected: {gender},
                          onSelectionChanged: (s) => setSheetState(() => gender = s.first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'Consultation', child: Text('In-person Consultation')),
                      DropdownMenuItem(value: 'Video Consultation', child: Text('Video Consultation')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => mode = v);
                    },
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(error, style: AppText.body(size: 11.5, color: AppColors.red600)),
                  ],
                  const SizedBox(height: 14),
                  AppButton(
                    label: 'Add to Queue',
                    block: true,
                    onPressed: () {
                      final name = nameController.text.trim();
                      final age = int.tryParse(ageController.text.trim()) ?? 0;
                      if (name.isEmpty) {
                        setSheetState(() => error = 'Enter the patient\'s name.');
                        return;
                      }
                      if (age <= 0 || age > 120) {
                        setSheetState(() => error = 'Enter a valid age (1-120).');
                        return;
                      }
                      app.addWalkInPatient(name: name, age: age, gender: gender, mode: mode);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: active ? AppColors.blue600 : AppColors.white,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), border: Border.all(color: active ? AppColors.blue600 : AppColors.line)),
            alignment: Alignment.center,
            child: Text(label, style: AppText.body(size: 11, weight: FontWeight.w700, color: active ? Colors.white : AppColors.ink600)),
          ),
        ),
      ),
    );
  }
}
