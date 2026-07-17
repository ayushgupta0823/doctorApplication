import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

class ConsultationSettingsScreen extends StatefulWidget {
  const ConsultationSettingsScreen({super.key});

  @override
  State<ConsultationSettingsScreen> createState() => _ConsultationSettingsScreenState();
}

class _ConsultationSettingsScreenState extends State<ConsultationSettingsScreen> {
  final _feeController = TextEditingController();
  String _followUpDefault = '7 Days';
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final fee = context.read<AppState>().doctorProfile?['consultationFeeInPerson'];
    if (fee != null) _feeController.text = '$fee';
    _loadFollowUpDefault();
  }

  Future<void> _loadFollowUpDefault() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _followUpDefault = prefs.getString(AppState.kDefaultFollowUpPrefKey) ?? '7 Days';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _save(AppState app) async {
    setState(() => _saving = true);
    final fee = int.tryParse(_feeController.text.trim());
    final ok = await app.updateDoctorProfile({if (fee != null) 'consultationFeeInPerson': fee});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppState.kDefaultFollowUpPrefKey, _followUpDefault);
    await app.hydrateConsultationPreferences();
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Consultation settings saved', style: AppText.body(size: 13, color: Colors.white, weight: FontWeight.bold)), backgroundColor: AppColors.green600),
      );
    }
    // On failure, AppState already pushed a friendly in-app notification —
    // the follow-up default still saved locally either way.
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Consultation Settings', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('CONSULTATION FEE', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PER CONSULTATION (₹)', style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ink600)),
                    const SizedBox(height: 4),
                    TextField(controller: _feeController, keyboardType: TextInputType.number, style: AppText.body(size: 13)),
                    const SizedBox(height: 6),
                    Text('Shown to patients when they book with you.', style: AppText.body(size: 10.5, color: AppColors.ink400)),
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
                const SizedBox(height: 6),
                Text('Saved on this device — pre-fills the follow-up field when you write a prescription.', style: AppText.body(size: 10.5, color: AppColors.ink400)),
                const SizedBox(height: 24),
                AppButton(label: _saving ? 'Saving...' : 'Save Changes', block: true, loading: _saving, onPressed: _saving ? null : () => _save(app)),
              ],
            ),
    );
  }
}
