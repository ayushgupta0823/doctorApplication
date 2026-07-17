import 'ai_api.dart';
import 'ai_client.dart';
import 'api_client.dart';
import 'appointments_api.dart';
import 'consultations_api.dart';
import 'doctors_api.dart';
import 'lab_api.dart';
import 'messages_api.dart';
import 'notifications_api.dart';
import 'prescriptions_api.dart';

export 'api_exception.dart';

/// Single import point wiring every resource API onto the shared
/// [ApiClient]/[AiClient] singletons. `AppState` depends on this rather than
/// constructing each `*Api` class itself.
class Api {
  Api._();

  static final doctors = DoctorsApi(ApiClient.instance);
  static final appointments = AppointmentsApi(ApiClient.instance);
  static final consultations = ConsultationsApi(ApiClient.instance);
  static final prescriptions = PrescriptionsApi(ApiClient.instance);
  static final notifications = NotificationsApi(ApiClient.instance);
  static final ai = AiApi(AiClient.instance);
  static final lab = LabApi(ApiClient.instance);
  static final messages = MessagesApi(ApiClient.instance);
}
