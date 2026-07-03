import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

/// Generic placeholder screen for menu entries that don't have a bespoke
/// design in this pass (Documents, Lab Orders, Pharmacy, etc.) — a real,
/// navigable screen rather than a dead button, honestly labeled as not
/// yet backed by real data/content.
class SimpleInfoScreen extends StatelessWidget {
  const SimpleInfoScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    this.items = const [],
  });

  final String title;
  final IconData icon;
  final String description;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text(title, style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.blue100, shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: AppColors.blue700),
            ),
          ),
          const SizedBox(height: 16),
          Text(description, textAlign: TextAlign.center, style: AppText.body(size: 12.5, color: AppColors.ink600)),
          const SizedBox(height: 20),
          if (items.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nothing here yet.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 12.5, color: AppColors.ink400),
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: items
                    .map((item) => Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.lineSoft))),
                          child: Row(
                            children: [
                              Expanded(child: Text(item, style: AppText.body(size: 13))),
                              const Icon(Icons.chevron_right, size: 16, color: AppColors.ink400),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
