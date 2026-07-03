import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/avatar.dart';
import 'consult_room/consult_room_screen.dart';

enum _DetailTab { overview, history, reports, prescriptions, notes }

/// Patient Details: everything known about one patient before/after a
/// consultation — chief complaint, AI risk flag, vitals, allergies,
/// chronic conditions, current medications, and tabs into their history,
/// reports, prescriptions and free-text notes.
class PatientDetailsScreen extends StatefulWidget {
  const PatientDetailsScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  _DetailTab _tab = _DetailTab.overview;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final patient = app.findQueueById(widget.patientId);

    if (patient == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => Navigator.pop(context))),
        body: Center(child: Text('Patient not found.', style: AppText.body(size: 13, color: AppColors.ink400))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Patient Details', style: AppText.display(size: 16)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, size: 20), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                InitialsAvatar(name: patient.name, size: 52, fontSize: 17),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.name, style: AppText.display(size: 16)),
                      Text('${patient.age} Y · ${patient.gender == 'F' ? 'Female' : 'Male'}', style: AppText.body(size: 11.5, color: AppColors.ink600)),
                      if (patient.phone.isNotEmpty) Text(patient.phone, style: AppText.mono(size: 10.5, color: AppColors.ink400)),
                    ],
                  ),
                ),
                if (patient.isKnownPatient)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.green100, borderRadius: BorderRadius.circular(100)),
                    child: Text('Known Patient', style: AppText.body(size: 9.5, weight: FontWeight.w700, color: AppColors.green600)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.amber100, borderRadius: BorderRadius.circular(100)),
                    child: Text('Walk-in', style: AppText.body(size: 9.5, weight: FontWeight.w700, color: AppColors.amber600)),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _TabChip(label: 'Overview', active: _tab == _DetailTab.overview, onTap: () => setState(() => _tab = _DetailTab.overview)),
                _TabChip(label: 'History', active: _tab == _DetailTab.history, onTap: () => setState(() => _tab = _DetailTab.history)),
                _TabChip(label: 'Reports', active: _tab == _DetailTab.reports, onTap: () => setState(() => _tab = _DetailTab.reports)),
                _TabChip(label: 'Prescriptions', active: _tab == _DetailTab.prescriptions, onTap: () => setState(() => _tab = _DetailTab.prescriptions)),
                _TabChip(label: 'Notes', active: _tab == _DetailTab.notes, onTap: () => setState(() => _tab = _DetailTab.notes)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: _buildTabBody(context, app, patient),
              ),
            ),
          ),
          if (_tab == _DetailTab.overview)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Start Consultation',
                        variant: AppButtonVariant.success,
                        icon: const Icon(Icons.play_arrow, size: 16),
                        onPressed: () {
                          if (patient.status == ConsultStatus.inProgress) {
                            app.resumeConsult(patient.id);
                          } else {
                            app.startNewConsult(patient.id);
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsultRoomScreen()));
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: 'Message Patient',
                        variant: AppButtonVariant.ghost,
                        icon: const Icon(Icons.chat_bubble_outline, size: 15),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Messaging ${patient.name}...'), backgroundColor: AppColors.blue700),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBody(BuildContext context, AppState app, QueuePatient patient) {
    switch (_tab) {
      case _DetailTab.overview:
        return _OverviewTab(patient: patient);
      case _DetailTab.history:
        final records = app.patientHistory.where((h) => h.name == patient.name).toList();
        return _HistoryTab(records: records);
      case _DetailTab.reports:
        return _ReportsTab(patient: patient);
      case _DetailTab.prescriptions:
        final records = app.patientHistory.where((h) => h.name == patient.name && h.rx != null).toList();
        return _PrescriptionsTab(records: records);
      case _DetailTab.notes:
        return _NotesTab(patient: patient, controller: _noteController);
    }
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.active, required this.onTap});
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

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.patient});
  final QueuePatient patient;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (patient.chiefComplaint.isNotEmpty) ...[
          Text('CHIEF COMPLAINT', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(patient.chiefComplaint, style: AppText.body(size: 13)),
          const SizedBox(height: 16),
        ],
        if (patient.aiRiskAnalysis != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.red100, border: Border.all(color: AppColors.red600, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.air, color: AppColors.red600, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 12, color: AppColors.red600),
                          const SizedBox(width: 4),
                          Text('AI RISK ANALYSIS', style: AppText.mono(size: 9, color: AppColors.red600, weight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(patient.aiRiskAnalysis!.title, style: AppText.display(size: 13.5, color: AppColors.red600)),
                      Text(patient.aiRiskAnalysis!.description, style: AppText.body(size: 11.5, color: AppColors.ink900)),
                      const SizedBox(height: 6),
                      Text('Confidence: ${patient.aiRiskAnalysis!.confidencePercent}%', style: AppText.body(size: 10.5, weight: FontWeight.w700, color: AppColors.red600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (patient.vitalsSnapshot != null) ...[
          Text('VITALS (LAST VISIT)', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _VitalCell(label: 'Temp', value: '${patient.vitalsSnapshot!.tempF}°F')),
              Expanded(child: _VitalCell(label: 'BP', value: '${patient.vitalsSnapshot!.bpSystolic}/${patient.vitalsSnapshot!.bpDiastolic}')),
              Expanded(child: _VitalCell(label: 'SpO2', value: '${patient.vitalsSnapshot!.spo2}%')),
              Expanded(child: _VitalCell(label: 'Pulse', value: '${patient.vitalsSnapshot!.pulse}')),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (patient.riskSummary.allergies.isNotEmpty) ...[
          Text('ALLERGIES', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: patient.riskSummary.allergies.map((a) => _Tag(a, AppColors.red100, AppColors.red600)).toList()),
          const SizedBox(height: 16),
        ],
        if (patient.riskSummary.comorbidities.isNotEmpty) ...[
          Text('CHRONIC CONDITIONS', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(patient.riskSummary.comorbidities.join(', '), style: AppText.body(size: 12.5)),
          const SizedBox(height: 16),
        ],
        if (patient.currentMedications.isNotEmpty) ...[
          Text('CURRENT MEDICATIONS', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(patient.currentMedications.join(', '), style: AppText.body(size: 12.5)),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

class _VitalCell extends StatelessWidget {
  const _VitalCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        children: [
          Text(value, style: AppText.mono(size: 14, weight: FontWeight.bold, color: AppColors.blue900)),
          Text(label, style: AppText.body(size: 9.5, color: AppColors.ink600, weight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: AppText.body(size: 10.5, weight: FontWeight.w700, color: fg)),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.records});
  final List<PatientHistory> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Center(child: Text('No past consultations recorded.', style: AppText.body(size: 12.5, color: AppColors.ink400)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: records.length,
      itemBuilder: (context, i) {
        final r = records[i];
        return AppCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(r.date, style: AppText.body(size: 12, weight: FontWeight.bold, color: AppColors.blue700))),
                  if (r.diagnosis.isNotEmpty) Text(r.diagnosis.first, style: AppText.body(size: 11, color: AppColors.ink600)),
                ],
              ),
              if (r.soap.assessment.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(r.soap.assessment, style: AppText.body(size: 12)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({required this.patient});
  final QueuePatient patient;

  @override
  Widget build(BuildContext context) {
    if (patient.riskSummary.recentLabAbnormalities == 'None' || patient.riskSummary.recentLabAbnormalities.isEmpty) {
      return Center(child: Text('No lab reports on file.', style: AppText.body(size: 12.5, color: AppColors.ink400)));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.science_outlined, color: AppColors.amber600),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Lab Abnormalities', style: AppText.body(size: 12.5, weight: FontWeight.bold)),
                    Text(patient.riskSummary.recentLabAbnormalities, style: AppText.body(size: 12, color: AppColors.ink600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrescriptionsTab extends StatelessWidget {
  const _PrescriptionsTab({required this.records});
  final List<PatientHistory> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Center(child: Text('No prescriptions issued yet.', style: AppText.body(size: 12.5, color: AppColors.ink400)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: records.length,
      itemBuilder: (context, i) {
        final r = records[i];
        return AppCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.date, style: AppText.body(size: 12, weight: FontWeight.bold, color: AppColors.blue700)),
              const SizedBox(height: 6),
              for (final m in r.rx!.medicines) Text('${m.name} · ${m.dosage} · ${m.freq}', style: AppText.body(size: 12)),
            ],
          ),
        );
      },
    );
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab({required this.patient, required this.controller});
  final QueuePatient patient;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final notes = app.notesFor(patient.id);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Add a note about this patient...'))),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.blue600),
                onPressed: () {
                  app.addPatientNote(patient.id, controller.text);
                  controller.clear();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: notes.isEmpty
              ? Center(child: Text('No notes yet.', style: AppText.body(size: 12.5, color: AppColors.ink400)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: notes.length,
                  itemBuilder: (context, i) {
                    final n = notes[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.text, style: AppText.body(size: 12.5)),
                          const SizedBox(height: 4),
                          Text('${n.author} · ${n.timestamp}', style: AppText.body(size: 10, color: AppColors.ink400)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
