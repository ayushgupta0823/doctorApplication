import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

class ConsultationSettingsScreen extends StatefulWidget {
  const ConsultationSettingsScreen({super.key});

  @override
  State<ConsultationSettingsScreen> createState() => _ConsultationSettingsScreenState();
}

class _ConsultationSettingsScreenState extends State<ConsultationSettingsScreen> {
  final _feeInPersonController = TextEditingController(text: '600');
  final _feeOnlineController = TextEditingController(text: '450');
  String _followUpDefault = '7 Days';
  bool _saving = false;

  @override
  void dispose() {
    _feeInPersonController.dispose();
    _feeOnlineController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Consultation settings saved', style: AppText.body(size: 13, color: Colors.white, weight: FontWeight.bold)), backgroundColor: AppColors.green600),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Consultation Settings', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('CONSULTATION FEES', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IN-PERSON (₹)', style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ink600)),
                    const SizedBox(height: 4),
                    TextField(controller: _feeInPersonController, keyboardType: TextInputType.number),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ONLINE (₹)', style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ink600)),
                    const SizedBox(height: 4),
                    TextField(controller: _feeOnlineController, keyboardType: TextInputType.number),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('DEFAULT FOLLOW-UP', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _followUpDefault,
                isExpanded: true,
                items: const ['7 Days', '14 Days', '1 Month', '3 Months'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _followUpDefault = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(label: _saving ? 'Saving...' : 'Save Changes', block: true, loading: _saving, onPressed: _saving ? null : _save),
        ],
      ),
    );
  }
}
