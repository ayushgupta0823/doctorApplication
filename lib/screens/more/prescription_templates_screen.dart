import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

const kPrescriptionTemplatesKey = 'more.prescription_templates';

class PrescriptionTemplate {
  PrescriptionTemplate({required this.id, required this.medicine});
  final String id;
  final Medicine medicine;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': medicine.name,
        'dosage': medicine.dosage,
        'freq': medicine.freq,
        'duration': medicine.duration,
        'dosageForm': medicine.dosageForm,
      };

  static PrescriptionTemplate fromJson(Map<String, dynamic> j) => PrescriptionTemplate(
        id: j['id'] as String,
        medicine: Medicine(
          name: (j['name'] as String?) ?? '',
          dosage: (j['dosage'] as String?) ?? '',
          freq: (j['freq'] as String?) ?? '',
          duration: (j['duration'] as String?) ?? '',
          dosageForm: (j['dosageForm'] as String?) ?? 'tablet',
        ),
      );
}

Future<List<PrescriptionTemplate>> loadPrescriptionTemplates() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kPrescriptionTemplatesKey);
  if (raw == null) return [];
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(PrescriptionTemplate.fromJson).toList();
}

Future<void> _persistTemplates(List<PrescriptionTemplate> templates) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kPrescriptionTemplatesKey, jsonEncode(templates.map((t) => t.toJson()).toList()));
}

/// Reusable medicine presets a doctor writes often (e.g. "Migraine — First
/// Line") — saved on-device via `shared_preferences` (there's no backend
/// endpoint for this) and insertable straight into the Rx builder from the
/// Prescription tab during a consultation.
class PrescriptionTemplatesScreen extends StatefulWidget {
  const PrescriptionTemplatesScreen({super.key});

  @override
  State<PrescriptionTemplatesScreen> createState() => _PrescriptionTemplatesScreenState();
}

class _PrescriptionTemplatesScreenState extends State<PrescriptionTemplatesScreen> {
  List<PrescriptionTemplate> _templates = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final templates = await loadPrescriptionTemplates();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _loaded = true;
    });
  }

  Future<void> _openEditor({PrescriptionTemplate? existing}) async {
    final result = await showModalBottomSheet<Medicine>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TemplateEditorSheet(initial: existing?.medicine),
    );
    if (result == null || result.name.trim().isEmpty) return;
    setState(() {
      if (existing != null) {
        _templates = _templates.map((t) => t.id == existing.id ? PrescriptionTemplate(id: t.id, medicine: result) : t).toList();
      } else {
        _templates.add(PrescriptionTemplate(id: '${DateTime.now().microsecondsSinceEpoch}', medicine: result));
      }
    });
    _persistTemplates(_templates);
  }

  void _delete(PrescriptionTemplate t) {
    setState(() => _templates.removeWhere((x) => x.id == t.id));
    _persistTemplates(_templates);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Prescription Templates', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Save medicine presets here, then insert them into any prescription from the Prescription tab during a consultation.',
                  style: AppText.body(size: 12, color: AppColors.ink600),
                ),
                const SizedBox(height: 16),
                if (_templates.isEmpty)
                  Center(child: EmptyState(icon: Icons.article_outlined, message: 'No templates yet — add one below.'))
                else
                  ..._templates.asMap().entries.map((entry) => AppCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.value.medicine.name, style: AppText.body(size: 13, weight: FontWeight.w700)),
                                  Text('${entry.value.medicine.dosage} · ${entry.value.medicine.freq} · ${entry.value.medicine.duration}', style: AppText.body(size: 11, color: AppColors.ink600)),
                                ],
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.blue700), onPressed: () => _openEditor(existing: entry.value)),
                            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red600), onPressed: () => _delete(entry.value)),
                          ],
                        ),
                      ).animate(delay: (entry.key * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut)),
                const SizedBox(height: 8),
                AppButton(label: '+ Add Template', variant: AppButtonVariant.ghost, block: true, onPressed: () => _openEditor()),
              ],
            ),
    );
  }
}

class _TemplateEditorSheet extends StatefulWidget {
  const _TemplateEditorSheet({this.initial});
  final Medicine? initial;

  @override
  State<_TemplateEditorSheet> createState() => _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends State<_TemplateEditorSheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _dosage = TextEditingController(text: widget.initial?.dosage ?? '');
  late final _freq = TextEditingController(text: widget.initial?.freq ?? '');
  late final _duration = TextEditingController(text: widget.initial?.duration ?? '');

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _freq.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.initial == null ? 'New Template' : 'Edit Template', style: AppText.display(size: 15)),
          const SizedBox(height: 14),
          TextField(controller: _name, decoration: const InputDecoration(hintText: 'Medicine name')),
          const SizedBox(height: 10),
          TextField(controller: _dosage, decoration: const InputDecoration(hintText: 'Dosage (e.g. 500mg)')),
          const SizedBox(height: 10),
          TextField(controller: _freq, decoration: const InputDecoration(hintText: 'Frequency (e.g. Twice daily)')),
          const SizedBox(height: 10),
          TextField(controller: _duration, decoration: const InputDecoration(hintText: 'Duration (e.g. 5 days)')),
          const SizedBox(height: 16),
          AppButton(
            label: 'Save Template',
            block: true,
            onPressed: () => Navigator.pop(
              context,
              Medicine(name: _name.text.trim(), dosage: _dosage.text.trim(), freq: _freq.text.trim(), duration: _duration.text.trim()),
            ),
          ),
        ],
      ),
    );
  }
}
