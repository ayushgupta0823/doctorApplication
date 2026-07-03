# AGENTS.md — MediConnectAI Workspace (root) + Flutter Doctor App

This directory is **both** the workspace root (containing all three projects) **and** the Flutter doctor app itself (the Flutter project lives at the root: `pubspec.yaml`, `lib/`, `android/`, `web/`, `windows/`).

## Workspace layout
```
D:\doctorApp\                      ← you are here (Flutter doctor app + workspace root)
├── AGENTS.md                      ← this file
├── healthcare-api/                ← Node/Express backend  (see healthcare-api/AGENTS.md)
├── AI-Clinic-project/             ← React website (reference client)  (see AI-Clinic-project/AGENTS.md)
├── lib/  pubspec.yaml  android/  web/  windows/  test/   ← the Flutter doctor app
├── backend-api-reference.md       ← CANONICAL backend API spec (read first)
├── BackendAiapi.md                ← CANONICAL AI service spec
└── doctor-app-master-prompt.md    ← build spec / acceptance checklist for THIS Flutter app
```

## How the three projects relate
```
┌─────────────────────┐   mobile JWT (phone+OTP)    ┌─────────────────────┐   X-API-Key   ┌──────────────────┐
│  Flutter Doctor App │ ──────────────────────────► │   healthcare-api    │ ────────────► │   AI Service     │
│  (this dir)         │   /api/v1/* (Bearer)        │  (Node/Express)     │  (proxy)      │  (FastAPI/Gemini)│
└─────────────────────┘                             └─────────────────────┘               └──────────────────┘
         │                                                      ▲                                   ▲
         │  direct AI calls (no key) — like the website          │  Clerk JWT                         │  direct (no key)
         └──────────────────────────────────────────────────► ┌─┴─────────────────────┐ ──────────────┘
                                                                  │  AI-Clinic-project    │
                                                                  │  (React website)      │  ← reference client
                                                                  └───────────────────────┘
```
- **Flutter app** → healthcare-api via `/api/v1/*` with a mobile JWT Bearer token (phone+OTP flow).
- **Flutter app** → AI service **direct** at `https://ai.shikhartesting.dev/ai/*` (no `X-API-Key`; mirrors the website). Doctor AI features: `/ai/summarize` (scribe), `/ai/prescription`, `/ai/risk-alerts`, `/ai/drug-interactions` (see `BackendAiapi.md`).
- **Website** → healthcare-api via Clerk JWT; → AI service direct (same base URL).
- **healthcare-api** → AI service via `ai.service.js` proxy (injects `X-API-Key` server-side) — used by `/api/v1/ai/*` routes, but the Flutter app bypasses these and calls the AI service directly.

### Canonical specs (always consult these)
- `backend-api-reference.md` — every endpoint, role, model, error code, stub list.
- `BackendAiapi.md` — every AI endpoint, request/response shapes, guardrails, the `X-API-Key` requirement (note: the deployed `ai.shikhartesting.dev` does NOT enforce it — verified by the website's bare fetches).
- `doctor-app-master-prompt.md` — the Flutter app's acceptance checklist ("no mock left in production paths", every loading/empty/error state, irreversible actions need confirmation, AI content must be distinguishable from doctor-authored).

### Shared role model
Backend `User.role`: `patient | doctor | hospital_admin | lab_technician | pharmacist | super_admin`. The Flutter app is **doctor-facing**, so its login must resolve to a user with `role: 'doctor'`.

---

# Flutter Doctor App (this directory)

**Name:** `mediconnect_doctor_app` · **SDK:** Dart ≥3.3 · **State:** `provider` (single `AppState` ChangeNotifier) · **Theme:** `google_fonts` + custom (`lib/theme/app_theme.dart`).

## Run / Lint
```bash
flutter pub get
flutter run --dart-define=DEV_CLERK_TOKEN=eyJ...   # see "Current state" below
flutter analyze          # static analysis (analysis_options.yaml)
flutter test             # tests in test/
```

## ⚠️ Current state (2026-07-02): connected to the real backend, login still mocked
Phase 2 (below) has been implemented for everything **except login**. `sendOtp()`/`verifyOtp()` in `lib/state/app_state.dart` are still the original `Future.delayed`/local-string-compare simulation — this was a deliberate, explicit decision, not an oversight: doctor-facing backend routes require a **Clerk** session JWT (see `healthcare-api/AGENTS.md`'s auth truth table), and the mobile OTP flow can only ever mint a `patient`-role mobile JWT that those routes reject. Fixing that gap is a backend change that was explicitly ruled out of scope for now.

**So, every real API call in this app authenticates with a hand-supplied dev Clerk token instead of a token the app itself obtained.** See `lib/config/api_config.dart`'s doc comment: grab a real Clerk session JWT for a verified doctor account (e.g. from the AI-Clinic-project website's network tab while signed in as that doctor) and pass it via `--dart-define=DEV_CLERK_TOKEN=...`. Without it, every Clerk-only call 401s and the app falls back to showing its mock/cached data (by design — see `ApiClient`/`_describeError` in `app_state.dart`) rather than crashing or blocking. Clerk session tokens expire in ~60s and are normally auto-refreshed by the Clerk SDK; since that SDK isn't integrated here, expect to refresh this value periodically during a dev session.

**What's actually wired to the real backend now** (`lib/data/api/*`, consumed from `lib/state/app_state.dart`):
- Doctor profile (`GET/PUT /doctors/me/profile`) — real name/NMC number/qualifications replace the old hardcoded "Dr. Rhea Kulkarni" everywhere (home header, prescription PDFs).
- Queue (`GET /appointments/doctor`) → confirm/start/complete/no-show (`PUT /appointments/:id/*`). Local walk-ins (no backend appointment) survive a refresh.
- Consultation lifecycle: SOAP note push on complete (`PUT /consultations/:id/soap`), diagnosis push on ICD-10 pick (`PUT /consultations/:id/diagnosis`), and resume-hydration (`GET /consultations/:id`) when reopening an in-progress consult.
- Prescriptions: create → approve (`POST /prescriptions`, `POST /prescriptions/:id/approve`) — genuinely refuses to sign against the backend for a patient with no `patientRecordId` (e.g. a local walk-in or the offline mock seed) rather than fabricating a signature.
- AI (direct to `https://ai.shikhartesting.dev`, no key, per the established pattern): `/ai/summarize` (scribe → SOAP), `/ai/prescription` (the "+ AI Suggestion" button in the Rx builder).
- Patients tab: `GET /consultations/doctor` joined against `GET /doctors/me/patients` for display names; prescriptions fetched lazily per selected history item (`GET /prescriptions/by-consultation/:id`).
- Notifications: `GET /notifications/me` + `/unread-count`, `PUT /notifications/me/read-all`.

**Deliberately NOT wired in this pass** (flagged rather than half-done):
- `GET /ai/drug-interactions` — confirmed a hardcoded stub server-side (`backend-api-reference.md`/`healthcare-api/AGENTS.md`): always returns `interactions: []`. `AppState.getDrugInteractions()` stays local rule-based logic, which is strictly more useful than the real endpoint right now.
- Real LiveKit video (`POST /consultations/:id/video/token` is not called) — the call screen is still a timer/transcript simulation. Wiring real media needs the `livekit_client` package, device permission flows, and track rendering — a separate effort from the REST wiring done here.
- Push notifications (`firebase_messaging`), medicine reminders, lab report views beyond what's used above — not touched.
- Optimistic queue actions (confirm/start/complete/no-show) do **not** roll back on a sync failure — they log + push an in-app notification and keep the local state, matching this app's offline-first design (see "Offline / resilience" below). A real retry-on-reconnect queue is not implemented.
- `lib/test/widget_test.dart`'s AI-scribe test now exercises a **real** network call to the AI service (no test-layer mock/interceptor swap yet) — it passes today but is not hermetic; consider injecting a fake `Dio` adapter in tests as a follow-up.

`lib/data/mock_data.dart` is retained as the instant-paint seed / offline fallback (shown before the first real fetch resolves, and if it fails).

## Structure (`lib/`)
```
main.dart                runApp → ChangeNotifierProvider<AppState> → RootShell
root_shell.dart          5-tab bottom nav (Home, Queue, Patients, Calendar, More) + auth/onboarding gates
state/app_state.dart     ★ 966-line ChangeNotifier — all app logic (auth, queue, call, AI, Rx, history)
data/mock_data.dart      mock queue, patient history, transcript seed, ICD-10 db, vitals series
models/models.dart       single file: ConsultStatus, QueuePatient, SoapNote, Medicine, Prescription, PatientHistory, etc.
theme/app_theme.dart     AppColors, AppText, AppRadius
screens/
  login_screen.dart           phone/email + OTP (mock)
  onboarding_screen.dart      NMC + signature + permission requests
  biometric_lock_screen.dart  Face ID / fingerprint re-auth
  home_screen.dart            situation dashboard (waiting count, next appt, risk chips, availability toggle)
  queue_screen.dart           consultation queue (pull-to-refresh, status lifecycle, no-show flow)
  patients_screen.dart        my patients / history (search, lazy-load)
  patient_details_screen.dart diagnosis, SOAP, transcript, Rx detail
  appointments_screen.dart    (pushed route)
  calendar_screen.dart        daily roster
  reports_analytics_screen.dart
  profile_screen.dart         editable + read-only (NMC) fields
  consult_room/               video consultation + AI scribe + prescription builder (subdir)
  more/more_menu_screen.dart  settings entry
  settings/                   (subdir)
widgets/                 app_button, app_card, avatar, status_badge, otp_box_input, sparkline_painter, ekg_painter, step_progress_indicator, synced_text_field, page_head, notifications_dialog
utils/prescription_pdf.dart   local PDF gen (pdf + printing packages)
```

## `lib/state/app_state.dart` — what each method maps to (Phase 2 target)
| Mock method | Real backend endpoint | Notes |
|---|---|---|
| `sendOtp` / `verifyOtp` | `POST /auth/mobile/send-otp` + `/verify-otp` | dev OTP `1234` returned as `devOtp` |
| `verifyNmc` | (none — NMC verification is super-admin only `/doctors/:id/nmc-verify`) | doctor self-onboarding uses `/invites/:token/accept` |
| `refreshQueue` | `GET /appointments/doctor` | status filter via query |
| `confirmPatient` | `PUT /appointments/:id/confirm` | |
| `startNewConsult` | `PUT /appointments/:id/start` → returns `consultationId` | |
| `completeConsultation` | `PUT /appointments/:id/complete` + `POST /consultations/:id/complete` | |
| `markNoShow` | `PUT /appointments/:id/no-show` | |
| `beginCall` / video | `POST /consultations/:id/video/token` → LiveKit | add `livekit_client` dep |
| `generateSummary` (AI scribe) | `POST https://ai.shikhartesting.dev/ai/summarize` (direct) | `{notes}` → `{main_concerns, doctor_notes, medications, follow_up}` |
| `updateSoap*` / `approveSoap` | `PUT /consultations/:id/notes` / `/soap` | track `source: 'ai'|'doctor'` (already in model) |
| `getWarningsForMed` / `getDrugInteractions` | `GET /ai/drug-interactions?drugs=` (direct) + patient allergies from `/patients/:id` | |
| `approveAndSign` | `POST /prescriptions` → `POST /prescriptions/:id/approve` → `PUT /appointments/:id/complete` | 3-step, each must succeed before next |
| `searchHistory` | `GET /consultations/doctor` | paginated |
| (notifications) | `GET /notifications/me` + FCM | add `firebase_messaging` |
| (offline cache) | `shared_preferences` queue snapshot | already implemented — keep |

## Offline / resilience already present
`app_state.dart` already persists queue statuses + last-synced timestamp to `shared_preferences` (`_kQueueStatusCacheKey`) and hydrates on startup so a killed-offline app shows real data. `connectivity_plus` toggles `isOffline`. This pattern should extend to the new API layer (cache-then-network). Per master-prompt: queue/roster cached locally with "last updated" timestamp; write actions queue + retry on reconnect.

## Phase 2 — Connecting to the backend (implemented 2026-07-02)
**Decisions actually taken (differ slightly from the original plan below the line):**
1. HTTP client: **`dio`**, no `pretty_dio_logger`. One `ApiClient` (backend, envelope-aware) + one `AiClient` (AI service, plain JSON, no auth).
2. Auth: **deliberately NOT the mobile OTP flow** — see "Current state" above. A hand-supplied dev Clerk JWT (`--dart-define=DEV_CLERK_TOKEN`) stands in for real login until the backend/Clerk-mobile gap is addressed.
3. AI calls: direct to `https://ai.shikhartesting.dev/ai/*`, no `X-API-Key` — as planned, confirmed working.

**Actual file layout** (`lib/data/api/`):
```
api_client.dart          Dio → healthcare-api, Bearer(dev token) interceptor, {success,data,meta} envelope unwrap
api_exception.dart        ApiException — parses both the backend's {error:{code,details}} and the AI service's {detail} shapes
ai_client.dart            separate Dio → https://ai.shikhartesting.dev, no auth
api.dart                  `Api.*` — single import wiring every *Api class onto the two client singletons
doctors_api.dart          getMyProfile / updateMyProfile / getMyHospitals / getMyPatients
appointments_api.dart     listForDoctor / confirm / start / complete / markNoShow
consultations_api.dart    getById / updateSoap / addDiagnosis / complete / listMine
prescriptions_api.dart    create / approve / getByConsultation
notifications_api.dart    list / unreadCount / markAllRead
ai_api.dart               summarize / prescription
```
Only the methods actually called from `AppState` were written (no speculative CRUD surface) — e.g. no `auth_api.dart`/`lab_api.dart`/`refresh` yet, since login stays mocked and the doctor-side lab views aren't wired. `lib/config/api_config.dart` holds the base URLs + dev token. `AppState` was refactored method-by-method to call `Api.*`, keeping optimistic UI + `notifyListeners` + the existing offline cache (`shared_preferences`) — see "Current state" above for exactly what's wired and what isn't, including why optimistic queue actions don't roll back on sync failure.

## Backend auth gap — known, not fixed (by explicit decision)
**The mobile JWT issued by `/auth/mobile/verify-otp` still cannot access any doctor route** — they all use `authenticate` (Clerk-only), not `authAny`; see `healthcare-api/AGENTS.md`'s auth truth table for the full list (it also now covers `/notifications/*` and a few prescription GET routes that were previously undocumented gaps). Fixing this — switching those routes to `authAny` and giving the mobile JWT a path to the `doctor` role — was explicitly ruled out of scope for this pass. The dev-Clerk-token workaround above stands in for it. If/when that backend change happens, `lib/config/api_config.dart` and `AppState`'s auth wiring are the only places that need to change — the rest of the `Api.*` layer is auth-mechanism-agnostic.

## Master-prompt acceptance checklist (summary of `doctor-app-master-prompt.md`)
A screen is "done" only when: (1) reads/writes real data via the listed endpoints — no hardcoded mock in production; (2) every loading/empty/error/success state designed + implemented; (3) irreversible actions (Sign Rx, End Call, No-show) have explicit confirmation and can't double-tap; (4) state survives backgrounding, tab switching, poor network; (5) AI-generated content is visually distinguishable from doctor-authored everywhere (list, detail, PDF). Tabs: Queue, Video, Patients, Roster, Profile (5 max) — current app uses Home/Queue/Patients/Calendar/More; consult room is a pushed route. `activePatient` context persists across tabs. Color is functional (red=risk, amber=pending, green=safe, blue=action). Numeric/clinical data in tabular font. Minimal animation.
