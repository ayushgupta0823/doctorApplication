import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/step_progress_indicator.dart';
import 'registration_data.dart';

/// The 4-step "Doctor Registration" wizard: Personal Details -> Credentials
/// -> Practice Details -> Documents. Replaces the old NMC/signature/
/// permissions onboarding screen. All form state lives locally here and is
/// only handed off once, as a single [RegistrationData], via [onSubmitted]
/// on the final "Submit Application" tap — the host screen decides what
/// happens next (showing a success summary before committing it to AppState).
class DoctorRegistrationScreen extends StatefulWidget {
  const DoctorRegistrationScreen({super.key, this.onBackToWelcome, required this.onSubmitted});

  /// Lets the host swap back to the Welcome screen when the doctor presses
  /// back from step 1. Null (and back hidden) if there's nowhere to go back to.
  final VoidCallback? onBackToWelcome;

  final ValueChanged<RegistrationData> onSubmitted;

  @override
  State<DoctorRegistrationScreen> createState() => _DoctorRegistrationScreenState();
}

class _DoctorRegistrationScreenState extends State<DoctorRegistrationScreen> {
  int _step = 0;
  String _error = '';

  static const _stepLabels = ['Personal Details', 'Credentials', 'Practice Details', 'Documents'];
  static const _stepIcons = [
    Icons.person_outline,
    Icons.workspace_premium_outlined,
    Icons.location_on_outlined,
    Icons.description_outlined,
  ];

  // ---- Step 1: personal details ----
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  DateTime? _dob;
  String _gender = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ---- Step 2: credentials ----
  final _nmcCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _specialtySearchCtrl = TextEditingController();
  final _languagesCtrl = TextEditingController();
  final Set<String> _selectedSpecialties = {};
  final List<Map<String, String>> _qualifications = [];

  static const _allSpecialties = [
    'General Physician / Internal Medicine',
    'Pediatrics & Neonatology',
    'Cardiology',
    'Neurology',
    'Neurosurgery',
    'Orthopedics & Joint Replacement',
  ];

  // ---- Step 3: practice details ----
  final _clinicLocationCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _videoFeeCtrl = TextEditingController(text: '500');
  final _inPersonFeeCtrl = TextEditingController(text: '500');
  String? _selectedState;
  String? _selectedCity;

  // All 28 states + 8 union territories of India, each with a handful of
  // real major cities — real-app-style coverage instead of a partial demo
  // list, per the doctor's request to see "all" states/cities like a real app.
  static const _stateCities = {
    'Andhra Pradesh': ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Tirupati', 'Nellore'],
    'Arunachal Pradesh': ['Itanagar', 'Naharlagun', 'Pasighat'],
    'Assam': ['Guwahati', 'Silchar', 'Dibrugarh', 'Jorhat'],
    'Bihar': ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur'],
    'Chhattisgarh': ['Raipur', 'Bhilai', 'Bilaspur', 'Durg'],
    'Goa': ['Panaji', 'Margao', 'Vasco da Gama'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Gandhinagar'],
    'Haryana': ['Gurugram', 'Faridabad', 'Panipat', 'Ambala'],
    'Himachal Pradesh': ['Shimla', 'Manali', 'Dharamshala', 'Solan'],
    'Jharkhand': ['Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro'],
    'Karnataka': ['Bengaluru', 'Mysuru', 'Mangaluru', 'Hubballi', 'Belagavi'],
    'Kerala': ['Kochi', 'Thiruvananthapuram', 'Kozhikode', 'Kollam', 'Thrissur'],
    'Madhya Pradesh': ['Bhopal', 'Indore', 'Jabalpur', 'Gwalior', 'Ujjain'],
    'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Aurangabad', 'Thane'],
    'Manipur': ['Imphal', 'Thoubal'],
    'Meghalaya': ['Shillong', 'Tura'],
    'Mizoram': ['Aizawl', 'Lunglei'],
    'Nagaland': ['Kohima', 'Dimapur'],
    'Odisha': ['Bhubaneswar', 'Cuttack', 'Rourkela', 'Berhampur'],
    'Punjab': ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Mohali'],
    'Rajasthan': ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Ajmer'],
    'Sikkim': ['Gangtok', 'Namchi'],
    'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem'],
    'Telangana': ['Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar'],
    'Tripura': ['Agartala', 'Udaipur (Tripura)'],
    'Uttar Pradesh': ['Lucknow', 'Noida', 'Kanpur', 'Varanasi', 'Agra', 'Ghaziabad'],
    'Uttarakhand': ['Dehradun', 'Haridwar', 'Rishikesh', 'Nainital'],
    'West Bengal': ['Kolkata', 'Howrah', 'Siliguri', 'Durgapur', 'Asansol'],
    'Andaman and Nicobar Islands': ['Port Blair'],
    'Chandigarh': ['Chandigarh'],
    'Dadra and Nagar Haveli and Daman and Diu': ['Daman', 'Silvassa'],
    'Delhi': ['New Delhi', 'Dwarka', 'Rohini', 'Saket', 'Karol Bagh'],
    'Jammu and Kashmir': ['Srinagar', 'Jammu', 'Anantnag'],
    'Ladakh': ['Leh', 'Kargil'],
    'Lakshadweep': ['Kavaratti'],
    'Puducherry': ['Puducherry', 'Karaikal'],
  };

  // ---- Step 4: documents ----
  String? _nmcCertificateFile;
  String? _govIdFile;
  String? _degreeCertificateFile;
  String? _uploadingSlot;
  bool _submitting = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _nmcCtrl.dispose();
    _experienceCtrl.dispose();
    _specialtySearchCtrl.dispose();
    _languagesCtrl.dispose();
    _clinicLocationCtrl.dispose();
    _pincodeCtrl.dispose();
    _videoFeeCtrl.dispose();
    _inPersonFeeCtrl.dispose();
    super.dispose();
  }

  static final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
  static final _phonePattern = RegExp(r'^\+?\d{10,13}$');
  static final _nmcPattern = RegExp(r'^[A-Za-z0-9-]{5,20}$');
  static final _pincodePattern = RegExp(r'^\d{6}$');

  void _goBack() {
    if (_step > 0) {
      setState(() {
        _step -= 1;
        _error = '';
      });
    } else {
      widget.onBackToWelcome?.call();
    }
  }

  void _continue() {
    setState(() => _error = '');
    switch (_step) {
      case 0:
        if (!_validatePersonalDetails()) return;
        break;
      case 1:
        if (!_validateCredentials()) return;
        break;
      case 2:
        if (!_validatePracticeDetails()) return;
        break;
    }
    setState(() => _step += 1);
  }

  bool _validatePersonalDetails() {
    if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your first and last name.');
      return false;
    }
    if (_dob == null) {
      setState(() => _error = 'Please select your date of birth.');
      return false;
    }
    if (_gender.isEmpty) {
      setState(() => _error = 'Please select your gender.');
      return false;
    }
    if (!_phonePattern.hasMatch(_phoneCtrl.text.trim())) {
      setState(() => _error = 'Enter a valid contact phone number.');
      return false;
    }
    if (!_emailPattern.hasMatch(_emailCtrl.text.trim())) {
      setState(() => _error = 'Enter a valid official email address.');
      return false;
    }
    if (_passwordCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return false;
    }
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      setState(() => _error = 'Password and confirm password do not match.');
      return false;
    }
    return true;
  }

  bool _validateCredentials() {
    if (!_nmcPattern.hasMatch(_nmcCtrl.text.trim())) {
      setState(() => _error = 'Enter a valid NMC Registration Number.');
      return false;
    }
    if (int.tryParse(_experienceCtrl.text.trim()) == null) {
      setState(() => _error = 'Enter your years of experience as a number.');
      return false;
    }
    if (_selectedSpecialties.isEmpty) {
      setState(() => _error = 'Select at least one specialty.');
      return false;
    }
    return true;
  }

  bool _validatePracticeDetails() {
    if (_clinicLocationCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your practice address / clinic location.');
      return false;
    }
    if (_selectedState == null || _selectedCity == null) {
      setState(() => _error = 'Select your state and city.');
      return false;
    }
    if (!_pincodePattern.hasMatch(_pincodeCtrl.text.trim())) {
      setState(() => _error = 'Enter a valid 6-digit pincode.');
      return false;
    }
    if (double.tryParse(_videoFeeCtrl.text.trim()) == null || double.tryParse(_inPersonFeeCtrl.text.trim()) == null) {
      setState(() => _error = 'Enter valid consultation fees.');
      return false;
    }
    return true;
  }

  /// Opens the OS's real file picker (via `file_picker`) restricted to the
  /// document types a clinic would actually scan/photograph a credential as.
  /// A null result means the doctor cancelled the dialog — left untouched.
  Future<void> _pickFile(String slot) async {
    setState(() => _uploadingSlot = slot);
    String? fileName;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      fileName = result?.files.single.name;
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't open the file picker — ${e.toString()}");
    }
    if (!mounted) return;
    setState(() {
      _uploadingSlot = null;
      if (fileName == null) return;
      switch (slot) {
        case 'nmc':
          _nmcCertificateFile = fileName;
          break;
        case 'govId':
          _govIdFile = fileName;
          break;
        default:
          _degreeCertificateFile = fileName;
      }
    });
  }

  void _submit() async {
    if (_nmcCertificateFile == null) {
      setState(() => _error = 'Please upload your NMC / State Council Certificate.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    final languages = _languagesCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    widget.onSubmitted(
      RegistrationData(
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        dateOfBirth: _dob,
        gender: _gender,
        contactPhone: _phoneCtrl.text.trim(),
        officialEmail: _emailCtrl.text.trim(),
        nmcRegistrationNumber: _nmcCtrl.text.trim(),
        experienceYears: int.tryParse(_experienceCtrl.text.trim()) ?? 0,
        specialties: _selectedSpecialties.toList(),
        qualifications: _qualifications,
        languages: languages,
        clinicLocation: _clinicLocationCtrl.text.trim(),
        state: _selectedState ?? '',
        city: _selectedCity ?? '',
        pincode: _pincodeCtrl.text.trim(),
        videoFee: double.tryParse(_videoFeeCtrl.text.trim()) ?? 0,
        inPersonFee: double.tryParse(_inPersonFeeCtrl.text.trim()) ?? 0,
        nmcCertificateFile: _nmcCertificateFile,
        govIdFile: _govIdFile,
        degreeCertificateFile: _degreeCertificateFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink900),
          onPressed: _goBack,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogoMark(size: AppLogoSize.small),
            const SizedBox(width: 8),
            Text('MediConnect AI', style: AppText.display(size: 15)),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Doctor Registration', style: AppText.display(size: 19)),
            const SizedBox(height: 4),
            Text(
              'Onboard as a verified medical professional. List your specialties, configure availability, and start seeing patients online.',
              style: AppText.body(size: 12, color: AppColors.ink600).copyWith(height: 1.4),
            ),
            const SizedBox(height: 22),
            StepProgressIndicator(
              currentStep: _step,
              totalSteps: 4,
              currentStepIcon: _stepIcons[_step],
              labels: _stepLabels,
            ),
            const SizedBox(height: 26),
            if (_error.isNotEmpty) ...[
              _ErrorBanner(text: _error),
              const SizedBox(height: 14),
            ],
            AppCard(
              padding: const EdgeInsets.all(20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOut,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _buildPersonalDetails(),
                    1 => _buildCredentials(),
                    2 => _buildPracticeDetails(),
                    _ => _buildDocuments(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- shared bits ----

  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: AppText.body(size: 11.5, weight: FontWeight.w700, color: AppColors.ink600),
          children: required ? [TextSpan(text: ' *', style: AppText.body(size: 11.5, weight: FontWeight.w700, color: AppColors.red600))] : null,
        ),
      ),
    );
  }

  Widget _field(String label, Widget input, {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_label(label, required: required), input],
    );
  }

  /// Two fields side by side on a normal phone width; stacked full-width on
  /// very narrow screens so labels/hints never get crushed.
  Widget _fieldRow(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 14), b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
        );
      },
    );
  }

  /// Three fields side by side (First/Middle/Last Name) on a normal phone
  /// width; stacked full-width in that same left-to-right reading order on
  /// very narrow screens.
  Widget _fieldRow3(Widget a, Widget b, Widget c) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [a, const SizedBox(height: 14), b, const SizedBox(height: 14), c],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 10),
            Expanded(child: b),
            const SizedBox(width: 10),
            Expanded(child: c),
          ],
        );
      },
    );
  }

  Widget _navButtons({required VoidCallback onContinue, String continueLabel = 'Continue', bool loading = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Row(
        children: [
          if (_step > 0 || widget.onBackToWelcome != null)
            Expanded(
              child: AppButton(
                label: 'Previous',
                icon: const Icon(Icons.arrow_back, size: 15),
                variant: AppButtonVariant.ghost,
                block: true,
                onPressed: _goBack,
              ),
            ),
          if (_step > 0 || widget.onBackToWelcome != null) const SizedBox(width: 12),
          // flex: 2 (vs. Previous's implicit 1) — "Submit Application" on the
          // last step doesn't fit in an even half without truncating.
          Expanded(
            flex: 2,
            child: AppButton(
              label: continueLabel,
              icon: loading ? null : const Icon(Icons.arrow_forward, size: 15),
              loading: loading,
              block: true,
              onPressed: onContinue,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Step 1: Personal Details ----

  Widget _buildPersonalDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GoogleContinueButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Google sign-in isn't available in this demo.")),
            );
          },
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Sign in to link this registration to your account — or just fill the form below to apply.',
            textAlign: TextAlign.center,
            style: AppText.body(size: 11, color: AppColors.ink400),
          ),
        ),
        const SizedBox(height: 18),
        const _OrDivider(),
        const SizedBox(height: 18),
        _stepHeader(Icons.person_outline, 'Personal Details'),
        const SizedBox(height: 16),
        _fieldRow3(
          _field('First Name', required: true, TextField(controller: _firstNameCtrl, textInputAction: TextInputAction.next)),
          _field(
            'Middle Name',
            TextField(
              controller: _middleNameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'optional'),
            ),
          ),
          _field('Last Name', required: true, TextField(controller: _lastNameCtrl, textInputAction: TextInputAction.next)),
        ),
        const SizedBox(height: 14),
        _fieldRow(
          _field(
            'Date of Birth',
            required: true,
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime(1990, 1, 1),
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dob = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined, size: 17)),
                child: Text(
                  _dob == null ? 'Select date' : '${_dob!.day.toString().padLeft(2, '0')} ${_monthName(_dob!.month)} ${_dob!.year}',
                  style: AppText.body(size: 13, color: _dob == null ? AppColors.ink400 : AppColors.ink900),
                ),
              ),
            ),
          ),
          _field(
            'Gender',
            required: true,
            DropdownButtonFormField<String>(
              initialValue: _gender.isEmpty ? null : _gender,
              isExpanded: true,
              hint: const Text('Select'),
              items: const ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _gender = v ?? ''),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _field(
          'Contact Phone',
          required: true,
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'e.g. 9876543210', prefixIcon: Icon(Icons.phone_outlined, size: 18)),
          ),
        ),
        const SizedBox(height: 14),
        _field(
          'Official Email',
          required: true,
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'e.g. doctor@clinic.com', prefixIcon: Icon(Icons.mail_outline, size: 18)),
          ),
        ),
        const SizedBox(height: 14),
        _fieldRow(
          _field(
            'Password',
            required: true,
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ),
          _field(
            'Confirm Password',
            required: true,
            TextField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
            ),
          ),
        ),
        _navButtons(onContinue: _continue),
      ],
    );
  }

  String _monthName(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];

  // ---- Step 2: Credentials ----

  Widget _buildCredentials() {
    final query = _specialtySearchCtrl.text.trim().toLowerCase();
    final visibleSpecialties = query.isEmpty
        ? _allSpecialties
        : _allSpecialties.where((s) => s.toLowerCase().contains(query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(Icons.workspace_premium_outlined, 'Credentials'),
        const SizedBox(height: 16),
        _fieldRow(
          _field(
            'NMC Registration Number',
            required: true,
            TextField(
              controller: _nmcCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'e.g. NMC-893021', prefixIcon: Icon(Icons.badge_outlined, size: 18)),
            ),
          ),
          _field(
            'Experience (Years)',
            required: true,
            TextField(
              controller: _experienceCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'e.g. 8'),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('SPECIALTIES (SELECT AT LEAST ONE) *',
            style: AppText.body(size: 10.5, weight: FontWeight.w700, color: AppColors.ink600).copyWith(letterSpacing: .3)),
        const SizedBox(height: 8),
        TextField(
          controller: _specialtySearchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Search specialties...', prefixIcon: Icon(Icons.search, size: 18)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: visibleSpecialties.map((s) {
            final selected = _selectedSpecialties.contains(s);
            return _SpecialtyTile(
              label: s,
              selected: selected,
              onTap: () => setState(() => selected ? _selectedSpecialties.remove(s) : _selectedSpecialties.add(s)),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'ACADEMIC QUALIFICATIONS',
                style: AppText.body(size: 10.5, weight: FontWeight.w700, color: AppColors.ink600).copyWith(letterSpacing: .3),
              ),
            ),
            TextButton.icon(
              onPressed: _showAddDegreeDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Degree'),
              style: TextButton.styleFrom(foregroundColor: AppColors.blue700, textStyle: AppText.body(size: 12, weight: FontWeight.w700)),
            ),
          ],
        ),
        if (_qualifications.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('No qualifications added. Tap "Add Degree" to add qualifications.', style: AppText.body(size: 11.5, color: AppColors.ink400)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              children: _qualifications.asMap().entries.map((entry) {
                final q = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.line)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${q['degree']} — ${q['institution']} (${q['year']})',
                          style: AppText.body(size: 12, weight: FontWeight.w600),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _qualifications.removeAt(entry.key)),
                        child: const Icon(Icons.close, size: 16, color: AppColors.ink400),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 18),
        _field('Languages Spoken (comma separated)',
            TextField(controller: _languagesCtrl, decoration: const InputDecoration(hintText: 'e.g. English, Hindi, Punjabi'))),
        _navButtons(onContinue: _continue),
      ],
    );
  }

  void _showAddDegreeDialog() {
    final degreeCtrl = TextEditingController();
    final institutionCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Degree'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: degreeCtrl, decoration: const InputDecoration(hintText: 'Degree, e.g. MBBS')),
            const SizedBox(height: 10),
            TextField(controller: institutionCtrl, decoration: const InputDecoration(hintText: 'Institution')),
            const SizedBox(height: 10),
            TextField(controller: yearCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Year, e.g. 2016')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (degreeCtrl.text.trim().isEmpty) return;
              setState(() {
                _qualifications.add({
                  'degree': degreeCtrl.text.trim(),
                  'institution': institutionCtrl.text.trim(),
                  'year': yearCtrl.text.trim(),
                });
              });
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ---- Step 3: Practice Details ----

  Widget _buildPracticeDetails() {
    final cities = _selectedState != null ? _stateCities[_selectedState!] ?? [] : <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(Icons.location_on_outlined, 'Practice Details'),
        const SizedBox(height: 16),
        _field(
          'Practice Address / Clinic Location',
          required: true,
          TextField(
            controller: _clinicLocationCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Clinic Name / Plot No / Area', prefixIcon: Icon(Icons.storefront_outlined, size: 18)),
          ),
        ),
        const SizedBox(height: 14),
        _fieldRow(
          _field(
            'State',
            required: true,
            DropdownButtonFormField<String>(
              initialValue: _selectedState,
              isExpanded: true,
              hint: const Text('Select State', overflow: TextOverflow.ellipsis),
              items: _stateCities.keys
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedState = v;
                _selectedCity = null;
              }),
            ),
          ),
          _field(
            'City',
            required: true,
            DropdownButtonFormField<String>(
              initialValue: _selectedCity,
              isExpanded: true,
              hint: Text(_selectedState == null ? 'Select state first' : 'Select City', overflow: TextOverflow.ellipsis),
              items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _selectedState == null ? null : (v) => setState(() => _selectedCity = v),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _field(
          'Pincode',
          required: true,
          TextField(
            controller: _pincodeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(counterText: '', prefixIcon: Icon(Icons.pin_drop_outlined, size: 18)),
          ),
        ),
        const SizedBox(height: 14),
        _fieldRow(
          _field(
            'Online Video Consultation Fee',
            required: true,
            TextField(
              controller: _videoFeeCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(prefixText: '₹ '),
            ),
          ),
          _field(
            'In-person Physical Fee',
            required: true,
            TextField(
              controller: _inPersonFeeCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(prefixText: '₹ '),
            ),
          ),
        ),
        _navButtons(onContinue: _continue),
      ],
    );
  }

  // ---- Step 4: Documents ----

  Widget _buildDocuments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(Icons.description_outlined, 'Documents'),
        const SizedBox(height: 8),
        Text(
          'Upload scanned copies of your credentials for verification by the MediConnect team.',
          style: AppText.body(size: 12, color: AppColors.ink600),
        ),
        const SizedBox(height: 16),
        _UploadRow(
          title: 'NMC / State Council Certificate',
          subtitle: 'Medical registration certificate',
          required: true,
          fileName: _nmcCertificateFile,
          uploading: _uploadingSlot == 'nmc',
          onTap: () => _pickFile('nmc'),
          onClear: () => setState(() => _nmcCertificateFile = null),
        ),
        const SizedBox(height: 12),
        _UploadRow(
          title: 'Government ID Proof (optional)',
          subtitle: 'Aadhaar / Passport / PAN',
          fileName: _govIdFile,
          uploading: _uploadingSlot == 'govId',
          onTap: () => _pickFile('govId'),
          onClear: () => setState(() => _govIdFile = null),
        ),
        const SizedBox(height: 12),
        _UploadRow(
          title: 'Degree Certificate (optional)',
          subtitle: 'MBBS / MD / MS degree proof',
          fileName: _degreeCertificateFile,
          uploading: _uploadingSlot == 'degree',
          onTap: () => _pickFile('degree'),
          onClear: () => setState(() => _degreeCertificateFile = null),
        ),
        _navButtons(
          onContinue: _submit,
          continueLabel: _submitting ? 'Submitting...' : 'Submit Application',
          loading: _submitting,
        ),
      ],
    );
  }

  Widget _stepHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Icon(icon, size: 17, color: AppColors.blue700),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppText.display(size: 16)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.red100, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: AppColors.red600),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.body(size: 12, color: AppColors.red600, weight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('OR', style: AppText.body(size: 11, color: AppColors.ink400, weight: FontWeight.w700)),
        ),
        const Expanded(child: Divider(color: AppColors.line)),
      ],
    );
  }
}

class _GoogleContinueButton extends StatelessWidget {
  const _GoogleContinueButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('G', style: AppText.display(size: 16, color: AppColors.blue600)),
              const SizedBox(width: 8),
              Text('Continue with Google', style: AppText.body(size: 13, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecialtyTile extends StatelessWidget {
  const _SpecialtyTile({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        constraints: const BoxConstraints(minWidth: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue100 : Colors.white,
          border: Border.all(color: selected ? AppColors.blue600 : AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 17,
              color: selected ? AppColors.blue600 : AppColors.ink400,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: AppText.body(size: 12, weight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onClear,
    this.required = false,
    this.fileName,
    this.uploading = false,
  });

  final String title;
  final String subtitle;
  final bool required;
  final String? fileName;
  final bool uploading;
  final VoidCallback onTap;
  final VoidCallback onClear;

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
                RichText(
                  text: TextSpan(
                    text: title,
                    style: AppText.body(size: 13, weight: FontWeight.bold),
                    children: required ? [TextSpan(text: ' *', style: AppText.body(size: 13, weight: FontWeight.bold, color: AppColors.red600))] : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(uploaded ? fileName! : subtitle, style: AppText.body(size: 11, color: uploaded ? AppColors.green600 : AppColors.ink600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (uploading)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else if (uploaded)
            Row(
              children: [
                const Icon(Icons.check_circle, size: 18, color: AppColors.green600),
                const SizedBox(width: 6),
                InkWell(onTap: onClear, child: const Icon(Icons.close, size: 16, color: AppColors.ink400)),
              ],
            )
          else
            InkWell(
              onTap: onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.upload_outlined, size: 16, color: AppColors.blue600),
                  const SizedBox(width: 4),
                  Text('Click to upload', style: AppText.body(size: 12, color: AppColors.blue600, weight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
