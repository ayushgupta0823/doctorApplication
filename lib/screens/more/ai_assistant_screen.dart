import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/api/api.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';

/// A doctor-facing AI assistant scoped to what the AI service actually
/// offers: there's no general conversational endpoint for doctors
/// (`/ai/chat` is patient-role only), so this surfaces the real
/// `/ai/summarize` clinical-scribe endpoint against a chosen patient's
/// context and a free-text question, rather than faking an open chatbot.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  QueuePatient? _patient;
  final _questionController = TextEditingController();
  bool _asking = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _error = 'Type a question first.');
      return;
    }
    setState(() {
      _asking = true;
      _error = null;
      _result = null;
    });
    final context = _patient == null
        ? question
        : 'Patient: ${_patient!.name}, ${_patient!.age}y ${_patient!.gender}. '
            'Chief complaint: ${_patient!.chiefComplaint.isEmpty ? "not recorded" : _patient!.chiefComplaint}. '
            'Known allergies: ${_patient!.riskSummary.allergies.isEmpty ? "none known" : _patient!.riskSummary.allergies.join(", ")}. '
            'Comorbidities: ${_patient!.riskSummary.comorbidities.isEmpty ? "none reported" : _patient!.riskSummary.comorbidities.join(", ")}.\n\n'
            'Doctor\'s question: $question';
    try {
      final result = await Api.ai.summarize(context);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = this.context.read<AppState>().describeError(e));
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final patients = app.queue.where((p) => p.status != ConsultStatus.completed && p.status != ConsultStatus.noShow && p.status != ConsultStatus.cancelled).toList();

    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('AI Assistant', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Ask about a patient on today\'s panel (optional — leave unselected for a general question).', style: AppText.body(size: 12, color: AppColors.ink600)),
          const SizedBox(height: 10),
          if (patients.isNotEmpty)
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: patients.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final p = patients[i];
                  final active = p.id == _patient?.id;
                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => setState(() => _patient = active ? null : p),
                    child: Container(
                      width: 68,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: active ? AppColors.teal100 : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: active ? AppColors.teal500 : Colors.transparent),
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
          TextField(
            controller: _questionController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'e.g. "What follow-up should I recommend for this presentation?"'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: AppText.body(size: 11.5, color: AppColors.red600)),
          ],
          const SizedBox(height: 12),
          AppButton(label: _asking ? 'Asking…' : 'Ask AI Assistant', loading: _asking, icon: const Icon(Icons.auto_awesome, size: 16), block: true, onPressed: _asking ? null : _ask),
          if (_result != null) ...[
            const SizedBox(height: 18),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: AppColors.tealDark),
                      const SizedBox(width: 6),
                      Text('AI-GENERATED — VERIFY BEFORE ACTING', style: AppText.mono(size: 9, weight: FontWeight.bold, color: AppColors.tealDark)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if ((_result!['main_concerns'] as String?)?.isNotEmpty ?? false) _ResultSection('Key points', _result!['main_concerns'] as String),
                  if ((_result!['doctor_notes'] as String?)?.isNotEmpty ?? false) _ResultSection('Notes', _result!['doctor_notes'] as String),
                  if ((_result!['follow_up'] as String?)?.isNotEmpty ?? false) _ResultSection('Suggested follow-up', _result!['follow_up'] as String),
                ],
              ),
            ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
          ],
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.mono(size: 9.5, weight: FontWeight.w700, color: AppColors.ink600)),
          const SizedBox(height: 3),
          Text(value, style: AppText.body(size: 12.5)),
        ],
      ),
    );
  }
}
