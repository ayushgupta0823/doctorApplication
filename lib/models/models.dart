/// Status of a queue / roster entry. Mirrors the string statuses used
/// in the original JS mock (`scheduled`, `confirmed`, `waiting`,
/// `in_progress`, `completed`, `no-show`, `cancelled`).
enum ConsultStatus {
  scheduled,
  confirmed,
  waiting,
  inProgress,
  completed,
  noShow,
  cancelled;

  String get label {
    switch (this) {
      case ConsultStatus.scheduled:
        return 'scheduled';
      case ConsultStatus.confirmed:
        return 'confirmed';
      case ConsultStatus.waiting:
        return 'waiting';
      case ConsultStatus.inProgress:
        return 'in progress';
      case ConsultStatus.completed:
        return 'completed';
      case ConsultStatus.noShow:
        return 'no-show';
      case ConsultStatus.cancelled:
        return 'cancelled';
    }
  }
}

enum QueuePriority {
  high,
  medium,
  normal;

  String get label {
    switch (this) {
      case QueuePriority.high:
        return 'High Priority';
      case QueuePriority.medium:
        return 'Medium Priority';
      case QueuePriority.normal:
        return 'Normal';
    }
  }
}

/// A single-visit vitals snapshot, shown on the Patient Details screen
/// ("Vitals (Last Visit)"). Distinct from [VitalsSeries], which is a
/// trend history used for the AI Scribe sparklines.
class VitalsSnapshot {
  const VitalsSnapshot({
    required this.tempF,
    required this.bpSystolic,
    required this.bpDiastolic,
    required this.spo2,
    required this.pulse,
  });

  final double tempF;
  final int bpSystolic;
  final int bpDiastolic;
  final int spo2;
  final int pulse;
}

/// AI-generated risk flag shown prominently on the Patient Details and
/// Consultation screens. Always doctor-reviewable, never auto-applied.
class AiRiskAnalysis {
  const AiRiskAnalysis({
    required this.title,
    required this.description,
    required this.confidencePercent,
  });

  final String title;
  final String description;
  final int confidencePercent;
}

class QueuePatient {
  QueuePatient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.mode,
    required this.time,
    required this.status,
    required this.riskSummary,
    required this.vitals,
    this.priority = QueuePriority.normal,
    this.phone = '',
    this.isKnownPatient = true,
    this.chiefComplaint = '',
    this.currentMedications = const [],
    this.vitalsSnapshot,
    this.aiRiskAnalysis,
    this.isWalkIn = false,
    this.patientRecordId,
    this.consultationId,
  });

  /// The backing `Appointment._id` from the backend — what the rest of the
  /// app treats as "the patient row for today" (one queue entry per
  /// appointment, same simplification the original mock data used).
  final String id;
  final String name;
  final int age;
  final String gender;
  final String mode;
  final String time;
  ConsultStatus status;
  final RiskSummary riskSummary;
  final VitalsSeries vitals;
  final QueuePriority priority;
  final String phone;
  final bool isKnownPatient;
  final String chiefComplaint;
  final List<String> currentMedications;
  final VitalsSnapshot? vitalsSnapshot;
  final AiRiskAnalysis? aiRiskAnalysis;
  final bool isWalkIn;

  /// The real `Patient._id` (from `appointment.patientId._id`) — distinct
  /// from [id] above. Null for locally-added walk-ins with no backend
  /// appointment yet.
  final String? patientRecordId;

  /// Set once `PUT /appointments/:id/start` returns a consultation — every
  /// subsequent consult-room call (soap, diagnosis, complete, prescription)
  /// targets this id, not [id].
  String? consultationId;

  bool get isUrgent => priority == QueuePriority.high;

  QueuePatient copy() => QueuePatient(
        id: id,
        name: name,
        age: age,
        gender: gender,
        mode: mode,
        time: time,
        status: status,
        riskSummary: riskSummary,
        vitals: vitals,
        priority: priority,
        phone: phone,
        isKnownPatient: isKnownPatient,
        chiefComplaint: chiefComplaint,
        currentMedications: currentMedications,
        vitalsSnapshot: vitalsSnapshot,
        aiRiskAnalysis: aiRiskAnalysis,
        isWalkIn: isWalkIn,
        patientRecordId: patientRecordId,
        consultationId: consultationId,
      );
}

class NoShowAlert {
  NoShowAlert({required this.name, this.next});
  final String name;
  final String? next;
}

class RiskSummary {
  const RiskSummary({
    required this.tags,
    required this.allergies,
    required this.comorbidities,
    required this.recentLabAbnormalities,
  });

  final List<String> tags;
  final List<String> allergies;
  final List<String> comorbidities;
  final String recentLabAbnormalities;
}

class VitalsSeries {
  const VitalsSeries({
    required this.bp,
    required this.bpDates,
    required this.hr,
    required this.hrDates,
  });

  final List<int> bp;
  final List<String> bpDates;
  final List<int> hr;
  final List<String> hrDates;
}

class IcdCode {
  const IcdCode({required this.code, required this.desc});
  final String code;
  final String desc;
}

class TranscriptLine {
  const TranscriptLine({required this.speaker, required this.text});
  final String speaker; // 'doctor' | 'patient'
  final String text;
}

class SoapNote {
  SoapNote({
    this.subjective = '',
    this.objective = '',
    this.assessment = '',
    this.plan = '',
    this.subjectiveSource = 'ai',
    this.objectiveSource = 'ai',
    this.assessmentSource = 'ai',
    this.planSource = 'ai',
  });

  String subjective;
  String objective;
  String assessment;
  String plan;
  String subjectiveSource; // 'ai' | 'doctor'
  String objectiveSource;  // 'ai' | 'doctor'
  String assessmentSource; // 'ai' | 'doctor'
  String planSource;       // 'ai' | 'doctor'

  bool get hasContent =>
      subjective.isNotEmpty ||
      objective.isNotEmpty ||
      assessment.isNotEmpty ||
      plan.isNotEmpty;
}

class Medicine {
  Medicine({
    this.name = '',
    this.dosage = '',
    this.freq = '',
    this.duration = '',
    this.aiSuggested = false,
  });
  String name;
  String dosage;
  String freq;
  String duration;
  bool aiSuggested;
}

class Prescription {
  const Prescription({
    required this.status,
    required this.medicines,
    required this.pdf,
  });

  final String status;
  final List<Medicine> medicines;
  final bool pdf;
}

class PatientHistory {
  PatientHistory({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.mode,
    required this.date,
    required this.diagnosis,
    required this.soap,
    required this.transcript,
    this.rx,
  });

  final String id;
  final String name;
  final int age;
  final String gender;
  final String mode;
  final String date;
  final List<String> diagnosis;
  final SoapNote soap;
  final List<TranscriptLine> transcript;

  /// Mutable: prescriptions are fetched lazily (one network call per
  /// consultation, only when the doctor opens that history item) rather
  /// than eagerly for the whole list.
  Prescription? rx;
}

class RosterEntry {
  const RosterEntry({
    required this.time,
    required this.name,
    required this.mode,
    required this.status,
  });

  final String time;
  final String name;
  final String mode;
  final ConsultStatus status;
}

class PatientNote {
  const PatientNote({required this.text, required this.timestamp, this.author = 'Dr. Rhea Kulkarni'});
  final String text;
  final String timestamp;
  final String author;
}

class LabTestOrder {
  LabTestOrder({required this.name, this.status = 'Ordered'});
  final String name;
  String status; // Ordered, In Progress, Completed
}
