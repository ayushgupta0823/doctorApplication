import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

class _HealthTip {
  const _HealthTip({required this.title, required this.category, required this.body});
  final String title;
  final String category;
  final String body;
}

const _tips = [
  _HealthTip(
    title: 'Managing Seasonal Allergies',
    category: 'Respiratory',
    body: 'Advise patients to check daily pollen forecasts and keep windows closed on high-count days. '
        'Rinsing sinuses with saline after outdoor exposure and showering before bed reduces overnight allergen load. '
        'Non-sedating antihistamines are generally preferred as first-line for daytime symptom control.',
  ),
  _HealthTip(
    title: 'Home Blood Pressure Monitoring',
    category: 'Cardiovascular',
    body: 'Recommend patients rest for 5 minutes before measuring, keep both feet flat on the floor, and support the '
        'arm at heart level. Two readings, one minute apart, morning and evening, give a more reliable trend than a '
        'single clinic reading. A log of at least a week helps distinguish white-coat effect from true hypertension.',
  ),
  _HealthTip(
    title: 'Correct Inhaler Technique',
    category: 'Respiratory',
    body: 'A large share of poor asthma control traces back to technique, not medication choice. For MDIs: shake, '
        'exhale fully, seal lips around the mouthpiece, actuate while inhaling slowly, then hold the breath for '
        '10 seconds. A spacer improves lung deposition and is worth recommending for most patients, especially children.',
  ),
  _HealthTip(
    title: 'Diabetic Foot Care Basics',
    category: 'Endocrine',
    body: 'Daily visual foot checks catch problems before they become ulcers. Advise well-fitted, cushioned footwear, '
        'never walking barefoot, and prompt attention to any cut, blister, or discoloration — even painless ones, '
        'given reduced sensation from neuropathy.',
  ),
  _HealthTip(
    title: 'Sleep Hygiene for Insomnia',
    category: 'General Wellness',
    body: 'A consistent wake time (even after a poor night) anchors the circadian rhythm more effectively than a '
        'consistent bedtime. Limiting screens for an hour before bed, keeping the bedroom cool and dark, and avoiding '
        'caffeine after early afternoon are the highest-yield, lowest-cost interventions before considering medication.',
  ),
  _HealthTip(
    title: 'Antibiotic Course Completion',
    category: 'Infectious Disease',
    body: 'Reinforce to patients that stopping antibiotics early — even once symptoms resolve — contributes to '
        'resistant strains and relapse. Setting phone reminders for each dose improves completion rates more than '
        'verbal instruction alone.',
  ),
];

/// Reference material a doctor can quickly share or recall talking points
/// from — genuinely useful static content rather than a "coming soon"
/// placeholder, since patient-education material doesn't need a backend.
class HealthTipsScreen extends StatelessWidget {
  const HealthTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Health Tips', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _tips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final tip = _tips[i];
          return AppCard(
            padding: const EdgeInsets.all(14),
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _HealthTipDetail(tip: tip))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tip.category.toUpperCase(), style: AppText.mono(size: 9.5, color: AppColors.blue700, weight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(tip.title, style: AppText.body(size: 13.5, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.ink400),
                ],
              ),
            ),
          ).animate(delay: (i * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
        },
      ),
    );
  }
}

class _HealthTipDetail extends StatelessWidget {
  const _HealthTipDetail({required this.tip});
  final _HealthTip tip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text(tip.category, style: AppText.display(size: 14)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(tip.title, style: AppText.display(size: 18)),
          const SizedBox(height: 12),
          Text(tip.body, style: AppText.body(size: 13.5, color: AppColors.ink600).copyWith(height: 1.5)),
        ].animate(interval: 60.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
      ),
    );
  }
}
