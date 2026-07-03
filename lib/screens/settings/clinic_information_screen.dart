import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

class _Qualification {
  _Qualification({required this.degree, required this.year, required this.institution});
  String degree;
  String year;
  String institution;
}

/// Clinic Information: personal details, specialties, practice location,
/// and qualifications — the bulk of what used to be a flat edit-form on
/// the Profile screen, now its own destination reached from the settings
/// list.
class ClinicInformationScreen extends StatefulWidget {
  const ClinicInformationScreen({super.key});

  @override
  State<ClinicInformationScreen> createState() => _ClinicInformationScreenState();
}

class _ClinicInformationScreenState extends State<ClinicInformationScreen> {
  late String gender;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _specialtiesController;
  late final TextEditingController _languagesController;
  late final TextEditingController _experienceController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;

  bool _saving = false;

  final List<_Qualification> quals = [
    _Qualification(degree: 'MBBS', year: '1999', institution: 'Seth GS Medical College'),
    _Qualification(degree: 'MD (General Medicine)', year: '2003', institution: 'KEM Hospital'),
  ];

  @override
  void initState() {
    super.initState();
    gender = 'Female';
    _firstNameController = TextEditingController(text: 'Rhea');
    _lastNameController = TextEditingController(text: 'Kulkarni');
    _specialtiesController = TextEditingController(text: 'General Medicine, Diabetology');
    _languagesController = TextEditingController(text: 'English, Hindi, Marathi');
    _experienceController = TextEditingController(text: '9');
    _addressController = TextEditingController(text: '14 Lotus Enclave, MG Road');
    _cityController = TextEditingController(text: 'Pune');
    _stateController = TextEditingController(text: 'Maharashtra');
    _pincodeController = TextEditingController(text: '411001');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _specialtiesController.dispose();
    _languagesController.dispose();
    _experienceController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _addQualification() => setState(() => quals.add(_Qualification(degree: '', year: '', institution: '')));
  void _removeQualification(int index) => setState(() => quals.removeAt(index));

  Future<void> _save(AppState app) async {
    setState(() => _saving = true);
    app.logAuditEvent('Saving clinic information via PATCH /doctors/me');
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clinic information saved', style: AppText.body(size: 13, color: Colors.white, weight: FontWeight.bold)), backgroundColor: AppColors.green600),
      );
    }
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
        title: Text('Clinic Information', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.blue100, border: Border.all(color: AppColors.blue500.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppColors.blue700),
                const SizedBox(width: 6),
                Expanded(child: Text('Your NMC registration number (${app.nmcNumber.isNotEmpty ? app.nmcNumber : 'NMC-2016-MH-08421'}) is locked and verified.', style: AppText.body(size: 11, color: AppColors.blue700))),
              ],
            ),
          ),
          _section('Personal Details', [
            _row2(_labeledField('First name', _firstNameController), _labeledField('Last name', _lastNameController)),
            _labeledDropdown('Gender', gender, const ['Female', 'Male', 'Other'], (v) => setState(() => gender = v)),
          ]),
          _section('Clinical Specializations', [
            _labeledField('Specialties', _specialtiesController),
            _labeledField('Languages Spoken', _languagesController),
            _labeledField('Experience (years)', _experienceController, keyboardType: TextInputType.number),
          ]),
          _section('Practice Location', [
            _labeledField('Street address', _addressController),
            _row2(_labeledField('City', _cityController), _labeledField('State', _stateController)),
            SizedBox(width: 160, child: _labeledField('Pincode', _pincodeController, keyboardType: TextInputType.number)),
          ]),
          Text('Qualifications', style: AppText.display(size: 13.5)),
          const SizedBox(height: 10),
          for (var i = 0; i < quals.length; i++) _QualRow(qual: quals[i], onDelete: () => _removeQualification(i)),
          AppButton(label: 'Add Qualification', variant: AppButtonVariant.ghost, icon: const Icon(Icons.add), block: true, onPressed: _addQualification),
          const SizedBox(height: 20),
          AppButton(label: _saving ? 'Saving...' : 'Save Changes', block: true, loading: _saving, onPressed: _saving ? null : () => _save(app)),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppText.display(size: 13.5)), const SizedBox(height: 10), ...children]),
    );
  }

  Widget _row2(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

  Widget _labeledField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ink600).copyWith(letterSpacing: .3)),
          const SizedBox(height: 4),
          TextField(controller: controller, keyboardType: keyboardType, style: AppText.body(size: 13)),
        ],
      ),
    );
  }

  Widget _labeledDropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ink600).copyWith(letterSpacing: .3)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                style: AppText.body(size: 13, color: AppColors.ink900),
                items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QualRow extends StatefulWidget {
  const _QualRow({required this.qual, required this.onDelete});
  final _Qualification qual;
  final VoidCallback onDelete;

  @override
  State<_QualRow> createState() => _QualRowState();
}

class _QualRowState extends State<_QualRow> {
  late final TextEditingController _degreeC;
  late final TextEditingController _yearC;
  late final TextEditingController _instC;

  @override
  void initState() {
    super.initState();
    _degreeC = TextEditingController(text: widget.qual.degree);
    _yearC = TextEditingController(text: widget.qual.year);
    _instC = TextEditingController(text: widget.qual.institution);
  }

  @override
  void dispose() {
    _degreeC.dispose();
    _yearC.dispose();
    _instC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Stack(
        children: [
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: TextField(controller: _degreeC, decoration: const InputDecoration(hintText: 'Degree'), onChanged: (v) => widget.qual.degree = v)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _yearC, decoration: const InputDecoration(hintText: 'Year'), onChanged: (v) => widget.qual.year = v)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: _instC, decoration: const InputDecoration(hintText: 'Institution'), onChanged: (v) => widget.qual.institution = v),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: AppColors.red100,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onDelete,
                child: const SizedBox(width: 26, height: 26, child: Icon(Icons.delete_outline, size: 15, color: AppColors.red600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
