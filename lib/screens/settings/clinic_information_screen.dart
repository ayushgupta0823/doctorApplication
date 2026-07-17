import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/avatar.dart';

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
  late final TextEditingController _photoUrlController;
  late final TextEditingController _specialtiesController;
  late final TextEditingController _languagesController;
  late final TextEditingController _experienceController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;

  bool _saving = false;
  bool _seededFromProfile = false;

  List<_Qualification> quals = [];

  @override
  void initState() {
    super.initState();
    gender = 'Female';
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _photoUrlController = TextEditingController();
    _specialtiesController = TextEditingController();
    _languagesController = TextEditingController();
    _experienceController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _pincodeController = TextEditingController();
    _seedFromProfile(context.read<AppState>().doctorProfile);
    _photoUrlController.addListener(() => setState(() {}));
  }

  /// Populates every field from the real backend profile. Called once, the
  /// first time a non-null profile is seen (at `initState` if it's already
  /// loaded, or from `build` once `AppState.loadDoctorProfile` resolves) —
  /// never again after, so it can't clobber an in-progress edit.
  void _seedFromProfile(Map<String, dynamic>? profile) {
    if (profile == null || _seededFromProfile) return;
    _seededFromProfile = true;
    _firstNameController.text = (profile['firstName'] as String?) ?? '';
    _lastNameController.text = (profile['lastName'] as String?) ?? '';
    _photoUrlController.text = (profile['profilePhoto'] as String?) ?? '';
    final g = profile['gender'] as String?;
    gender = g == 'male' ? 'Male' : (g == 'other' ? 'Other' : 'Female');
    final specialties = profile['specialties'];
    _specialtiesController.text = specialties is List ? specialties.whereType<String>().join(', ') : '';
    final languages = profile['languages'] ?? profile['languagesSpoken'];
    _languagesController.text = languages is List ? languages.whereType<String>().join(', ') : '';
    final experience = profile['experienceYears'] ?? profile['yearsOfExperience'];
    _experienceController.text = experience == null ? '' : '$experience';
    final location = profile['location'];
    final addressSource = location is Map ? location : profile;
    _addressController.text = (addressSource['address'] as String?) ?? '';
    _cityController.text = (addressSource['city'] as String?) ?? '';
    _stateController.text = (addressSource['state'] as String?) ?? '';
    _pincodeController.text = (addressSource['pincode']?.toString()) ?? '';
    final rawQuals = profile['qualifications'];
    quals = rawQuals is List && rawQuals.isNotEmpty
        ? rawQuals.whereType<Map>().map((q) {
            return _Qualification(
              degree: (q['degree'] as String?) ?? '',
              year: (q['year'] ?? q['passingYear'])?.toString() ?? '',
              institution: (q['institution'] as String?) ?? '',
            );
          }).toList()
        : [_Qualification(degree: '', year: '', institution: '')];
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _photoUrlController.dispose();
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
    final experience = int.tryParse(_experienceController.text.trim());
    final ok = await app.updateDoctorProfile({
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'profilePhoto': _photoUrlController.text.trim(),
      'gender': gender.toLowerCase(),
      'specialties': _specialtiesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      'languages': _languagesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      if (experience != null) 'experienceYears': experience,
      'location': {
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
      },
      'qualifications': quals.map((q) => {'degree': q.degree, 'year': q.year, 'institution': q.institution}).toList(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    // Failure already surfaced via AppState's in-app notification banner
    // (with a friendly, non-technical message) — only confirm success here.
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clinic information saved', style: AppText.body(size: 13, color: Colors.white, weight: FontWeight.bold)), backgroundColor: AppColors.green600),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!_seededFromProfile && app.doctorProfile != null) {
      // The profile wasn't loaded yet at initState — seed once it arrives,
      // deferred a frame so this doesn't setState mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _seedFromProfile(app.doctorProfile));
      });
    }
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
                Expanded(child: Text('Your NMC registration number (${app.doctorNmcNumber}) is locked and verified.', style: AppText.body(size: 11, color: AppColors.blue700))),
              ],
            ),
          ),
          _section('Personal Details', [
            Center(
              child: InitialsAvatar(name: app.doctorDisplayName, size: 72, fontSize: 22, imageUrl: _photoUrlController.text.trim()),
            ),
            const SizedBox(height: 12),
            _row2(_labeledField('First name', _firstNameController), _labeledField('Last name', _lastNameController)),
            _labeledField('Profile Photo URL', _photoUrlController, keyboardType: TextInputType.url),
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
                  Expanded(
                    child: TextField(
                      controller: _yearC,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      decoration: const InputDecoration(hintText: 'Year'),
                      onChanged: (v) => widget.qual.year = v,
                    ),
                  ),
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
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
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
