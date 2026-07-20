import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

const _employmentTypes = ['full_time', 'part_time', 'visiting', 'on_call'];
const _employmentLabels = {'full_time': 'Full-Time', 'part_time': 'Part-Time', 'visiting': 'Visiting', 'on_call': 'On-Call'};
const _weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
const _weekdayLabels = {'monday': 'Mon', 'tuesday': 'Tue', 'wednesday': 'Wed', 'thursday': 'Thu', 'friday': 'Fri', 'saturday': 'Sat', 'sunday': 'Sun'};

const _requiredDocs = [
  ('degree_certificate', 'Degree Certificate', 'MBBS / MD / MS proof'),
  ('nmc_registration', 'NMC / State Council Registration', 'Medical registration certificate'),
  ('govt_id', 'Government ID', 'Aadhaar / Passport / PAN'),
  ('passport_photo', 'Passport Photo', 'Recent passport-size photo'),
];

/// The doctor-side application form for a hospital invite — one scrolling
/// page (rather than the solo-apply flow's multi-step wizard) since this
/// form is materially shorter: personal info, credentials, the hospital
/// arrangement, and the same 4 required documents, matching
/// `DoctorApplication`'s fields 1:1. Autosaves via `saveDraft` per field
/// group, matching the website's per-step autosave.
class InviteApplicationScreen extends StatefulWidget {
  const InviteApplicationScreen({super.key, required this.token, required this.invite});

  final String token;
  final Map<String, dynamic> invite;

  @override
  State<InviteApplicationScreen> createState() => _InviteApplicationScreenState();
}

class _InviteApplicationScreenState extends State<InviteApplicationScreen> {
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nmcCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();
  final _specialtiesCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '20');
  String _employmentType = 'full_time';
  final Set<String> _availableDays = {};

  final Map<String, String> _docFileNames = {}; // docType -> display name once uploaded
  String? _uploadingDocType;
  bool _saving = false;
  bool _submitting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final application = widget.invite['application'];
    if (application is Map) {
      _firstNameCtrl.text = (application['firstName'] as String?) ?? '';
      _middleNameCtrl.text = (application['middleName'] as String?) ?? '';
      _lastNameCtrl.text = (application['lastName'] as String?) ?? '';
      _phoneCtrl.text = (application['phone'] as String?) ?? '';
      _nmcCtrl.text = (application['nmcRegistrationNumber'] as String?) ?? '';
      _degreeCtrl.text = (application['degree'] as String?) ?? '';
      final specialties = application['specialties'];
      _specialtiesCtrl.text = specialties is List ? specialties.whereType<String>().join(', ') : '';
      final experience = application['experience'];
      _experienceCtrl.text = experience == null ? '' : '$experience';
      _departmentCtrl.text = (application['department'] as String?) ?? '';
      final employmentType = application['employmentType'] as String?;
      if (employmentType != null && _employmentTypes.contains(employmentType)) _employmentType = employmentType;
      final fee = application['consultationFee'];
      _feeCtrl.text = fee == null ? '' : '$fee';
      final duration = application['consultationDuration'];
      if (duration != null) _durationCtrl.text = '$duration';
      final days = application['availableDays'];
      if (days is List) _availableDays.addAll(days.whereType<String>());
      final documents = application['documents'];
      if (documents is List) {
        for (final d in documents.whereType<Map>()) {
          final type = d['type'] as String?;
          final fileName = d['fileName'] as String?;
          if (type != null) _docFileNames[type] = fileName ?? 'Uploaded';
        }
      }
    } else {
      _phoneCtrl.text = '';
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _nmcCtrl.dispose();
    _degreeCtrl.dispose();
    _specialtiesCtrl.dispose();
    _experienceCtrl.dispose();
    _departmentCtrl.dispose();
    _feeCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _draftBody() {
    final specialties = _specialtiesCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return {
      'firstName': _firstNameCtrl.text.trim(),
      'middleName': _middleNameCtrl.text.trim(),
      'lastName': _lastNameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'nmcRegistrationNumber': _nmcCtrl.text.trim(),
      'degree': _degreeCtrl.text.trim(),
      'specialties': specialties,
      'experience': int.tryParse(_experienceCtrl.text.trim()),
      'department': _departmentCtrl.text.trim(),
      'employmentType': _employmentType,
      'consultationFee': double.tryParse(_feeCtrl.text.trim()),
      'availableDays': _availableDays.toList(),
      'consultationDuration': int.tryParse(_durationCtrl.text.trim()),
    };
  }

  Future<bool> _saveDraft() async {
    setState(() => _saving = true);
    final err = await context.read<AppState>().saveInviteDraft(widget.token, _draftBody());
    if (!mounted) return false;
    setState(() {
      _saving = false;
      _error = err ?? '';
    });
    return err == null;
  }

  Future<void> _pickAndUploadDoc(String docType) async {
    setState(() => _uploadingDocType = docType);
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
      final path = result?.files.single.path;
      if (path == null) {
        setState(() => _uploadingDocType = null);
        return;
      }
      // The upload endpoint requires the draft to already exist server-side.
      await _saveDraft();
      if (!mounted) return;
      final err = await context.read<AppState>().uploadInviteDocument(widget.token, File(path), docType);
      if (!mounted) return;
      setState(() {
        _uploadingDocType = null;
        if (err != null) {
          _error = err;
        } else {
          _docFileNames[docType] = path.split(RegExp(r'[\\/]')).last;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _uploadingDocType = null);
    }
  }

  Future<void> _submit() async {
    if (!await _saveDraft()) return;
    if (!mounted) return;
    setState(() {
      _submitting = true;
      _error = '';
    });
    final err = await context.read<AppState>().submitInviteApplication(widget.token);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (err != null) _error = err;
    });
    // On success, AppState already moved AuthStage to pendingReview — RootShell
    // swaps this whole screen stack out on its own, nothing else to do here.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        title: Text('Hospital Application', style: AppText.display(size: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Applying to ${widget.invite['hospitalName'] ?? 'the hospital'}', style: AppText.body(size: 12.5, color: AppColors.ink600)),
              const SizedBox(height: 16),
              _section('Personal Details', [
                _row2(_field('First name', _firstNameCtrl), _field('Last name', _lastNameCtrl)),
                _field('Middle name (optional)', _middleNameCtrl),
                _field('Phone', _phoneCtrl, keyboardType: TextInputType.phone),
              ]),
              _section('Credentials', [
                _field('NMC / State Council Registration No.', _nmcCtrl),
                _field('Degree (e.g. MBBS, MD)', _degreeCtrl),
                _field('Specialties (comma-separated)', _specialtiesCtrl),
                _field('Experience (years)', _experienceCtrl, keyboardType: TextInputType.number),
              ]),
              _section('Hospital Arrangement', [
                _field('Department', _departmentCtrl),
                _label('Employment Type'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _employmentTypes
                      .map((t) => _Chip(label: _employmentLabels[t]!, selected: _employmentType == t, onTap: () => setState(() => _employmentType = t)))
                      .toList(),
                ),
                const SizedBox(height: 12),
                _row2(_field('Consultation Fee (₹)', _feeCtrl, keyboardType: TextInputType.number), _field('Slot Duration (min)', _durationCtrl, keyboardType: TextInputType.number)),
                _label('Available Days'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _weekdays
                      .map((d) => _Chip(
                            label: _weekdayLabels[d]!,
                            selected: _availableDays.contains(d),
                            onTap: () => setState(() => _availableDays.contains(d) ? _availableDays.remove(d) : _availableDays.add(d)),
                          ))
                      .toList(),
                ),
              ]),
              _section('Documents', [
                for (final (type, title, subtitle) in _requiredDocs) ...[
                  _DocRow(
                    title: title,
                    subtitle: subtitle,
                    fileName: _docFileNames[type],
                    uploading: _uploadingDocType == type,
                    onTap: () => _pickAndUploadDoc(type),
                  ),
                  const SizedBox(height: 10),
                ],
              ]),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_error, style: AppText.body(size: 12.5, color: AppColors.red600, weight: FontWeight.w600)),
              ],
              const SizedBox(height: 12),
              AppButton(label: _saving ? 'Saving...' : 'Save Draft', variant: AppButtonVariant.ghost, block: true, loading: _saving, onPressed: _saving ? null : _saveDraft),
              const SizedBox(height: 10),
              AppButton(label: _submitting ? 'Submitting...' : 'Submit Application', block: true, loading: _submitting, onPressed: _submitting ? null : _submit),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppText.display(size: 14)), const SizedBox(height: 12), ...children]),
      ),
    );
  }

  Widget _row2(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text.toUpperCase(), style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ink600).copyWith(letterSpacing: .3)));

  Widget _field(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(controller: controller, keyboardType: keyboardType, style: AppText.body(size: 13)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue600 : Colors.white,
          border: Border.all(color: selected ? AppColors.blue600 : AppColors.line),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(label, style: AppText.body(size: 12, weight: FontWeight.w600, color: selected ? Colors.white : AppColors.ink600)),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.title, required this.subtitle, required this.onTap, this.fileName, this.uploading = false});
  final String title;
  final String subtitle;
  final String? fileName;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final uploaded = fileName != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: uploaded ? AppColors.green100.withValues(alpha: 0.5) : Colors.white,
        border: Border.all(color: uploaded ? AppColors.green600.withValues(alpha: 0.3) : AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(size: 13, weight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(uploaded ? fileName! : subtitle, style: AppText.body(size: 11, color: uploaded ? AppColors.green600 : AppColors.ink600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (uploading)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else if (uploaded)
            const Icon(Icons.check_circle, size: 18, color: AppColors.green600)
          else
            AppButton(label: 'Upload', small: true, variant: AppButtonVariant.subtle, onPressed: onTap),
        ],
      ),
    );
  }
}
