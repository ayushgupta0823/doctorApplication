# Master Prompt — MediConnectAI Doctor App (Fully Working Build Spec)

> Use this as a single reference prompt to brief a designer, developer, or an AI build tool.
> Goal: a production-grade, fully functional **doctor-facing** mobile app that pairs with the existing patient app. Every section below must be implemented — not just visually mocked — with real state, validation, and error handling.

---

## 0. Product Framing (give this context first)

"Build the doctor-side companion app for MediConnectAI, a telemedicine platform. The patient app already exists. This app is used by solo practitioners and clinic doctors to manage their daily patient queue, conduct video consultations with AI-assisted note-taking, issue digitally signed prescriptions, and review patient history — all from a phone, often between consults or in a waiting room. Optimize every screen for speed, one-handed use, and clinical trust, not for browsing or discovery."

**Primary user**: A doctor, time-constrained, medico-legally accountable for every note and prescription they approve.
**Core promise**: Never lose clinical context, never let AI output masquerade as doctor-verified fact, never let a Sign action happen by accident.

---

## 1. Information Architecture

- Bottom tab navigation, 5 tabs max: **Queue, Video, Patients, Roster, Profile**
- One canonical `activePatient` context object that persists across Queue → Video → Prescription → Patients, so switching tabs never loses which patient you're working on
- Deep-linkable screens (a push notification must be able to open directly to the relevant patient's Video screen)
- Any unsaved draft (SOAP note, in-progress prescription) must persist in local state/storage across tab switches — never silently discarded

---

## 2. Authentication & Onboarding

- [ ] Mobile number / email + OTP login
- [ ] NMC (or equivalent medical council) registration number capture + verification status
- [ ] Digital signature setup step — required before the doctor can approve any prescription
- [ ] Notification permission request, explained in plain language ("Get notified when a patient joins your queue")
- [ ] Camera & microphone permission request, explained before first video call, not buried in OS settings
- [ ] "Online for consults" availability toggle, visible and changeable from the app at any time
- [ ] Session handling: auto-logout after inactivity, biometric re-auth (Face ID / fingerprint) option for quick re-entry

---

## 3. Home / Situation Dashboard (new — not in original spec, but required)

A landing screen shown right after login, before the Queue tab, acting as a daily control center:

- [ ] Live count: patients currently waiting
- [ ] Next scheduled appointment with countdown
- [ ] Any risk-flagged patient in today's list surfaced with a warning chip
- [ ] Quick stats strip: total / completed / pending / in-progress (same data as Roster, summarized)
- [ ] One-tap shortcut into "Start next consultation"
- [ ] Availability toggle repeated here for convenience

---

## 4. Consultation Queue — fully working requirements

- [ ] Real appointment data from `/appointments/doctor`, not mock — must refresh on pull-to-refresh and on socket/push event
- [ ] Status lifecycle strictly enforced in UI: `scheduled → confirmed → in_progress → completed`, with `no_show` and `cancelled` as terminal branches
- [ ] Actions call real endpoints and optimistically update UI, then reconcile on response:
  - Approve → `PATCH /appointments/:id/confirm`
  - Start → `POST /appointments/:id/start` → must return and store `consultationId` before navigating to Video tab
  - No-show → `PATCH /appointments/:id/no-show`
- [ ] No-show banner: "See Next Patient" must actually select the next `scheduled`/`confirmed` patient by time, not just the next array item
- [ ] Sorting: waiting/urgent patients bubble to top; tie-break by scheduled time
- [ ] Empty state: distinct copy for "no patients today" vs "all done for today"
- [ ] Loading skeletons, not blank screens, while queue fetches

---

## 5. Video Consultation Room

- [ ] Real WebRTC integration (LiveKit or equivalent) — token fetch, room connect/disconnect, reconnect-on-drop logic
- [ ] Graceful degradation: on poor network, show a "reconnecting…" state instead of freezing or crashing the call
- [ ] Mic / camera / screen-share controls must reflect true device state, not just UI toggle state
- [ ] Call must survive app backgrounding on mobile (don't kill the call if the doctor checks another app briefly)
- [ ] Visible **recording/AI-scribe consent indicator** — both doctor and patient side must show that transcription is active; this is a legal requirement, not optional polish
- [ ] Call timer, live badge, and end-call flow must correctly release media devices and close the room on disconnect

---

## 6. AI Scribe & Clinical Tools

- [ ] Live transcript must stream in real time from the AI scribe service, speaker-attributed, and persist to the Consultation document (`transcript[]`) as it arrives — not only at call end
- [ ] "Generate AI Summary" calls a real backend/LLM endpoint, not a canned response; handle latency >2s with a proper loading state and handle failure with a retry option
- [ ] SOAP fields must be clearly marked **AI-generated vs doctor-edited** — track this at the field level (e.g., `soapNotes.subjective.source: 'ai' | 'doctor'`) since it matters medico-legally
- [ ] ICD-10 lookup must hit a real code database/API in production (not the 4-entry mock) — debounce input, handle no-match state
- [ ] Risk Summary sidebar (allergies, comorbidities, recent lab abnormalities) pulled from real patient record — allergies must be visually impossible to miss (not a quiet gray tag)
- [ ] Vitals sparklines pull real historical readings; handle patients with fewer than 3 data points (don't render a broken chart)

---

## 7. Prescription Builder — the highest-stakes screen, treat accordingly

- [ ] Medicine rows: name, dosage, frequency/instructions, duration — all required before a row counts as "valid"
- [ ] **Drug interaction and allergy checking must run live as the doctor types**, using `interactionWarnings` and the patient's known allergy list — surfaced inline next to the medicine row, not buried in a modal
- [ ] AI-suggested medicines (`aiSuggested: true`) must be visually distinguished from doctor-typed ones
- [ ] Validation before signing: at least one named medicine; block signing with a clear inline error otherwise (never a silent no-op)
- [ ] Approve & Sign flow, in exact order, each step must actually complete before the next starts:
  1. `POST /prescriptions` (draft)
  2. `PATCH /prescriptions/:id/approve` → generates real PDF, returns `pdfUrl`
  3. `PATCH /appointments/:id/complete`
  4. Show QR (ABDM-style) + working PDF download/open link
- [ ] This action needs a **confirmation step** ("Sign this prescription for [Patient Name]? This cannot be undone.") — irreversible clinical actions should never be one accidental tap
- [ ] Network/API failure at any step in the sign flow must show a specific, actionable error (`prescriptionSendError`) and must not falsely show "signed" if the PDF generation failed

---

## 8. My Patients / History

- [ ] Real completed-consultation history, paginated/lazy-loaded, not a static list
- [ ] Search and filter by patient name, date range, or diagnosis
- [ ] Detail view renders diagnosis, SOAP, transcript, and prescription for the selected record, with a genuine empty state when a session has no notes
- [ ] PDF download must open a real signed URL, in-app WebView or system browser, with expiry handled gracefully (don't show a dead link silently)

---

## 9. Daily Roster

- [ ] Chronological list for **today only**, sorted by `scheduledAt`
- [ ] Action buttons route correctly by status: Open → Queue with patient pre-selected; Resume → Video tab with correct `activePatient` and `consultationId` restored
- [ ] Summary stat cards must recompute live as statuses change during the day, not just on page load

---

## 10. Profile & Credentials

- [ ] Editable fields persist via `PATCH /doctors/me` with proper success/failure toast
- [ ] Read-only fields (NMC number, verification badge) are visually locked — different styling from editable fields, not just non-interactive
- [ ] Repeatable qualification rows: add/remove must not lose sibling row data
- [ ] Availability/fees changes should reflect immediately in what patients see (if patient app reads doctor fee live)

---

## 11. Notifications (required for "fully working")

- [ ] Push notification when a new patient joins the queue or a scheduled patient checks in
- [ ] Push notification for an incoming video call request
- [ ] In-app banner/badge on the Queue tab icon showing live waiting count
- [ ] Notification tap must deep-link to the correct screen and patient context

---

## 12. Offline / Network Resilience

- [ ] Queue and Roster data cached locally, shown with a "last updated" timestamp when offline
- [ ] In-call transcript buffers locally and syncs when connection returns, rather than dropping lines
- [ ] Any write action (confirm, no-show, sign prescription) queues and retries on reconnect rather than failing silently
- [ ] Clear, non-technical error copy for connectivity issues — never expose raw error codes to the doctor

---

## 13. Security, Trust & Compliance

- [ ] Auth token on every request; auto-refresh before expiry, force re-login on failure
- [ ] Digital signature applied server-side at approval time — never store or transmit an unlocked signature client-side
- [ ] Full audit trail: every consult, note edit, and prescription signing timestamped and attributable to the doctor's account
- [ ] AI-generated content clearly labeled everywhere it appears (list view, detail view, PDF export) — this is both a UX and compliance requirement
- [ ] ABDM/FHIR-compliant document references once integrated (currently mocked — flag this clearly to devs so it isn't shipped as final)

---

## 14. Visual & Interaction Design Principles

- [ ] Data density can be higher than a consumer app — doctors are comfortable with dense, structured UI (think EHR software, not a shopping app)
- [ ] Color is functional, not decorative: red = risk/urgent/danger, amber = pending/attention, green = safe/complete, blue = primary action/navigation
- [ ] Numeric/clinical data (vitals, timestamps, codes) in a monospaced or tabular font for scan-speed and unambiguous reading
- [ ] Minimal animation — nothing that delays a doctor mid-consult; motion only for meaningful state changes (call connecting, AI generating)
- [ ] Confirmation dialogs reserved for irreversible actions only (Sign Rx, End Call, Mark No-show) — don't over-confirm routine taps
- [ ] Error and empty states written in a clinical, specific tone: state what happened and what to do next, never a vague "Something went wrong"

---

## 15. Accessibility & Performance

- [ ] Full one-handed reachability for primary actions (bottom-anchored controls during a call)
- [ ] Sufficient contrast and tap-target size for use in bright clinic lighting or while walking
- [ ] Screen reader labels on all icon-only buttons (mic, camera, end call)
- [ ] App must remain responsive during an active video call — no janky re-renders while transcript is streaming

---

## 16. Definition of "Fully Working" (acceptance checklist)

A screen is not done until:
1. It reads and writes real data through the listed API endpoints (no hardcoded mock left in production paths)
2. Every loading, empty, error, and success state has been designed and implemented — not just the happy path
3. Every irreversible action has explicit confirmation and cannot be triggered by a double-tap or accidental gesture
4. State survives app backgrounding, tab switching, and poor network without data loss
5. AI-generated content is distinguishable from doctor-authored content everywhere it's displayed or exported
