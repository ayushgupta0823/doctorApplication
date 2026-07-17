/// Everything collected across the 4-step Doctor Registration wizard,
/// handed from [DoctorRegistrationScreen] to [RegistrationSuccessScreen] for
/// display, and from there into `AppState.completeRegistration`. Kept as a
/// plain data holder so the wizard doesn't need to reach into [AppState]
/// directly — it hands off the finished form once, at submission.
class RegistrationData {
  const RegistrationData({
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.contactPhone,
    required this.officialEmail,
    required this.nmcRegistrationNumber,
    required this.experienceYears,
    required this.specialties,
    required this.qualifications,
    required this.languages,
    required this.clinicLocation,
    required this.state,
    required this.city,
    required this.pincode,
    required this.videoFee,
    required this.inPersonFee,
    required this.nmcCertificateFile,
    required this.govIdFile,
    required this.degreeCertificateFile,
  });

  final String firstName;
  final String middleName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String gender;
  final String contactPhone;
  final String officialEmail;
  final String nmcRegistrationNumber;
  final int experienceYears;
  final List<String> specialties;
  final List<Map<String, String>> qualifications;
  final List<String> languages;
  final String clinicLocation;
  final String state;
  final String city;
  final String pincode;
  final double videoFee;
  final double inPersonFee;
  final String? nmcCertificateFile;
  final String? govIdFile;
  final String? degreeCertificateFile;

  String get fullName => [firstName, middleName, lastName].where((s) => s.trim().isNotEmpty).join(' ');
}
