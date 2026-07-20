import 'package:flutter/material.dart';
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
  // Gender, specialties, languages, experience and qualifications are
  // verification-backed credentials — displayed read-only (matching the
  // website's Profile.jsx, where Professional Details can only be changed by
  // contacting support), so these are plain strings, not form state.
  String gender = '';
  String specialtiesDisplay = '';
  String languagesDisplay = '';
  String experienceDisplay = '';
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _photoUrlController;
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
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _photoUrlController = TextEditingController();
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
    specialtiesDisplay = specialties is List ? specialties.whereType<String>().join(', ') : '';
    final languages = profile['languages'] ?? profile['languagesSpoken'];
    languagesDisplay = languages is List ? languages.whereType<String>().join(', ') : '';
    final experience = profile['experienceYears'] ?? profile['yearsOfExperience'];
    experienceDisplay = experience == null ? '' : '$experience years';
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
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _save(AppState app) async {
    setState(() => _saving = true);
    // Gender, specialties, languages, experience and qualifications are
    // read-only here and never submitted.
    final ok = await app.updateDoctorProfile({
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'profilePhoto': _photoUrlController.text.trim(),
      'location': {
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
      },
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
            _readonlyRow('Gender', gender),
          ]),
          _section('Professional Details', [
            _readonlyRow('Specialties', specialtiesDisplay),
            _readonlyRow('Languages Spoken', languagesDisplay),
            _readonlyRow('Experience', experienceDisplay),
          ], note: 'Verified — contact support to change'),
          _section('Practice Location', [
            _labeledField('Street address', _addressController),
            _row2(_labeledField('City', _cityController), _labeledField('State', _stateController)),
            SizedBox(width: 160, child: _labeledField('Pincode', _pincodeController, keyboardType: TextInputType.number)),
          ]),
          _section('Qualifications', [
            for (final q in quals) _QualRow(qual: q),
          ], note: 'Verified — contact support to change'),
          const SizedBox(height: 8),
          AppButton(label: _saving ? 'Saving...' : 'Save Changes', block: true, loading: _saving, onPressed: _saving ? null : () => _save(app)),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children, {String? note}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.display(size: 13.5)),
          if (note != null) Text(note, style: AppText.body(size: 10.5, color: AppColors.ink400)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
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

  /// Verified/credential data — shown for reference only, never editable here.
  Widget _readonlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppText.body(size: 12.5, color: AppColors.ink600))),
          Expanded(
            child: Text(value.isEmpty ? '—' : value, textAlign: TextAlign.right, style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink900)),
          ),
        ],
      ),
    );
  }
}

/// Read-only display of a single verified qualification (degree/year/institution).
class _QualRow extends StatelessWidget {
  const _QualRow({required this.qual});
  final _Qualification qual;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(qual.degree.isEmpty ? '—' : qual.degree, style: AppText.body(size: 13, weight: FontWeight.w600)),
                Text(qual.institution, style: AppText.body(size: 11.5, color: AppColors.ink600)),
              ],
            ),
          ),
          if (qual.year.isNotEmpty) Text(qual.year, style: AppText.mono(size: 12, color: AppColors.ink600)),
        ],
      ),
    );
  }
}
