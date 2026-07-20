# MediConnect AI — Backend API Reference

> **Base URL:** `http://localhost:5000/api/v1`  
> **OpenAPI Docs:** `http://localhost:5000/api-docs`  
> **Health Check:** `GET /health`  
> **Stack:** Node.js 20 · Express 5 · MongoDB (Atlas) · Redis · Socket.IO

---

## Table of Contents

1. [Authentication Overview](#authentication-overview)
2. [Role Hierarchy](#role-hierarchy)
3. [Auth APIs](#1-auth-apis---apiv1auth)
4. [Mobile Auth APIs](#2-mobile-auth-apis---apiv1authmobile)
5. [Patient APIs](#3-patient-apis---apiv1patients)
6. [Doctor APIs](#4-doctor-apis---apiv1doctors)
7. [Hospital APIs](#5-hospital-apis---apiv1hospitals)
8. [Appointment APIs](#6-appointment-apis---apiv1appointments)
9. [Consultation APIs](#7-consultation-apis---apiv1consultations)
10. [Prescription APIs](#8-prescription-apis---apiv1prescriptions)
11. [Lab Report APIs](#9-lab-report-apis---apiv1lab)
12. [Notification APIs](#10-notification-apis---apiv1notifications)
13. [Payment APIs](#11-payment-apis---apiv1payments)
14. [Admin APIs](#12-admin-apis---apiv1admin)
15. [AI APIs](#13-ai-apis---apiv1ai)
16. [Invite APIs](#14-invite-apis---apiv1invites)
17. [Webhook APIs](#15-webhook-apis---apiv1webhooks)
18. [Socket.IO](#16-socketio)
19. [Data Models](#17-data-models)
20. [Error Responses](#18-error-responses)
21. [Not Yet Implemented](#19-not-yet-implemented-stubs)
22. [Services & Integrations](#quick-reference-services--integrations)

---

## Authentication Overview

All protected endpoints require a `Bearer` token in the `Authorization` header:

```
Authorization: Bearer <token>
```

There are **two token types** depending on the client:

| Client | Token Source | Middleware |
|--------|-------------|-----------|
| Web / Super-Admin | Clerk session JWT | `authenticate` |
| Mobile App | Custom mobile JWT (issued by `/auth/mobile/verify-otp`) | `authAny` |

The `auth.js` middleware:
1. Verifies the JWT (Clerk or mobile)
2. Looks up the user in MongoDB via `clerkId`
3. Auto-provisions a new `User` record if not found (`/auth/sync` flow)
4. Attaches `req.user = { userId, clerkId, role, phone, email }` to the request

> **Important:** `req.user.userId` is the MongoDB `ObjectId` — **not** the Clerk string ID.

### `optionalAuth` Caveat

Used on `POST /hospitals/apply`, `POST /doctors/apply`, `GET /doctors/search`, `GET /doctors/:doctorId`, and `GET /invites/:token`. Tries a mobile JWT first, then Clerk, but only finds **existing** users — does NOT auto-provision, and never rejects the request even with no/invalid token. If a user has not yet called `/auth/sync` (or has no matching User), `req.user` will be `undefined` and the route still proceeds unauthenticated.

---

## Role Hierarchy

| Role | Assigned By | Description |
|------|-------------|-------------|
| `patient` | Default on `/auth/sync` | Can book appointments, manage health records |
| `doctor` | Hospital admin invite via `/invites/{token}/accept` | Manage consultations, prescriptions |
| `hospital_admin` | Super-admin verifies hospital application | Manages hospital, invites doctors/lab techs |
| `lab_technician` | Hospital admin invite (diagnostic centre type) | Enters lab results, views pending reports |
| `super_admin` | Seeded via script using `SUPER_ADMIN_CLERK_ID` | Full platform access — bypasses **all** role checks |

---

## 1. Auth APIs — `/api/v1/auth`

> Rate limited with `authLimiter` (stricter than the general API limiter).

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/auth/sync` | ✅ | any | Sync Clerk user to MongoDB after first login |
| `GET` | `/auth/me` | ✅ | any | Get current authenticated user info |
| `PUT` | `/auth/fcm-token` | ✅ | any | Register or update FCM push notification token |
| `DELETE` | `/auth/fcm-token` | ✅ | any | Remove FCM token on logout |

### POST /auth/sync
```json
// Request Body
{
  "role": "patient",        // "patient" | "doctor" | "hospital_admin"
  "phone": "+919876543210",
  "email": "user@example.com"
}
```

### PUT /auth/fcm-token
```json
// Request Body
{
  "token": "fcm_device_token_string",
  "device": "android"       // optional
}
```

---

## 2. Mobile Auth APIs — `/api/v1/auth/mobile`

> Phone + OTP authentication, usable by both the patient and doctor Flutter apps. No Clerk required.

| Method | Endpoint | Auth | Description |
|--------|----------|:---:|-------------|
| `POST` | `/auth/mobile/send-otp` | ❌ | Send OTP to phone number. Dev mode returns `devOtp` in response body |
| `POST` | `/auth/mobile/verify-otp` | ❌ | Verify OTP → returns JWT `accessToken` + `refreshToken` |
| `POST` | `/auth/mobile/refresh` | ❌ | Refresh access token using a valid refresh token |
| `POST` | `/auth/mobile/google` | ❌ | Login / register with Firebase Google ID Token |

### POST /auth/mobile/send-otp
```json
{ "phone": "+919876543210" }
```

### POST /auth/mobile/verify-otp
```json
// Request Body — there is no "role" field; role is never client-supplied.
{
  "phone": "+919876543210",
  "otp": "123456",
  "firstName": "Jane",     // only used if this phone has no existing User
  "lastName": "Doe"
}

// Response 200
{
  "success": true,
  "data": {
    "accessToken": "<jwt>",
    "refreshToken": "<jwt>",
    "user": { ... },
    "isNewUser": false,
    "hasProfile": true
  }
}
```
> Role resolution: an existing `User` keeps whatever role Mongo already has for them (`patient` or `doctor` both fall through to token issuance here — any other role, e.g. `hospital_admin`/`super_admin`, gets `403 ROLE_NOT_ALLOWED`). A **brand-new** phone number is always created as `role: 'patient'` — OTP itself can never mint a doctor account. Doctor role only ever comes from `POST /doctors/apply` approval or the hospital-invite application flow (§14) being approved; a doctor logs in with the *same* OTP endpoint once one of those has happened. `hasProfile` is always `true` for an existing doctor (a Doctor profile necessarily exists by the time the role is set) and reflects real profile-completeness for patients.

### POST /auth/mobile/google
```json
{ "idToken": "<firebase_google_id_token>" }
```

---

## 3. Patient APIs — `/api/v1/patients`

> Most routes require `patient` role (Clerk or mobile JWT). Admin routes require `super_admin`.

### Profile

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/patients` | ✅ | patient | Create patient profile (mobile registration flow) |
| `GET` | `/patients/me` | ✅ | patient | Get own patient profile |
| `PUT` | `/patients/me` | ✅ | patient | Update own profile |
| `DELETE` | `/patients/me` | ✅ | patient | Soft-delete account |
| `PUT` | `/patients/me/location` | ✅ | patient | Update current GPS location |
| `PUT` | `/patients/me/vitals` | ✅ | patient | Update vital signs |
| `PUT` | `/patients/me/allergies` | ✅ | patient | Replace full allergies list |

### POST /patients — Request Body
```json
{
  "firstName": "Jane",
  "lastName": "Doe",
  "dateOfBirth": "1990-01-15",
  "gender": "female",           // male | female | other | prefer_not_to_say
  "bloodGroup": "O+",           // A+ | A- | B+ | B- | AB+ | AB- | O+ | O-
  "location": {
    "lat": 28.6139,
    "lng": 77.2090,
    "address": "123 Main St",
    "city": "New Delhi",
    "state": "Delhi",
    "pincode": "110001"
  }
}
```

### Health Records

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/patients/me/health-record` | ✅ | patient | Get complete health record (vitals, allergies, medications) |
| `GET` | `/patients/me/health-twin` | ✅ | patient | AI health twin status / avatar *(stub — not yet implemented)* |
| `GET` | `/patients/me/health-score-history` | ✅ | patient | Get historical health score timeline |

### Consent (DPDP Act Compliance)

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `PUT` | `/patients/me/consent` | ✅ | patient | Update data consent choices |
| `GET` | `/patients/me/consents` | ✅ | patient | Get list of active consents |

### Family Members

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/patients/me/family` | ✅ | patient | List all linked family members |
| `POST` | `/patients/me/family` | ✅ | patient | Add a family member |
| `GET` | `/patients/me/family/:memberId` | ✅ | patient | Get specific family member profile |
| `PUT` | `/patients/me/family/:memberId` | ✅ | patient | Update family member details |
| `DELETE` | `/patients/me/family/:memberId` | ✅ | patient | Remove family member |
| `PUT` | `/patients/me/family/:memberId/consent/doctor/:doctorId` | ✅ | patient | Grant doctor access to family member records |

### Emergency Contacts

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/patients/me/emergency-contacts` | ✅ | patient | List emergency contacts |
| `POST` | `/patients/me/emergency-contacts` | ✅ | patient | Add emergency contact |
| `PUT` | `/patients/me/emergency-contacts/:id` | ✅ | patient | Update emergency contact |
| `DELETE` | `/patients/me/emergency-contacts/:id` | ✅ | patient | Remove emergency contact |

### Wearables

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/patients/me/wearables/connect` | ✅ | patient | Connect a wearable platform (Fitbit, Apple Health, etc.) |
| `DELETE` | `/patients/me/wearables/:platform` | ✅ | patient | Disconnect wearable platform |
| `POST` | `/patients/me/wearables/sync` | ✅ | patient | Sync wearable data |

### ABDM / ABHA Integration

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/patients/me/abdm/link` | ✅ | patient | Link ABHA ID *(stub — not yet implemented)* |
| `GET` | `/patients/me/abdm/profile` | ✅ | patient | Get ABHA profile from ABDM |

### Admin Access

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/patients` | ✅ | super_admin | List all patients on the platform |
| `GET` | `/patients/:patientId` | ✅ | super_admin, doctor | Get specific patient profile |
| `PUT` | `/patients/:patientId/block` | ✅ | super_admin | Block patient account |
| `DELETE` | `/patients/:patientId` | ✅ | super_admin | Hard delete patient |

---

## 4. Doctor APIs — `/api/v1/doctors`

### Public (No Auth Required)

| Method | Endpoint | Auth | Description |
|--------|----------|:---:|-------------|
| `GET` | `/doctors/search` | optional | Search doctors by `specialty`, `city`, `name` |
| `GET` | `/doctors/:doctorId` | optional | Get public doctor profile |
| `GET` | `/doctors/:doctorId/availability` | ❌ | Get doctor weekly availability schedule |
| `GET` | `/doctors/:doctorId/slots?date=YYYY-MM-DD` | ❌ | Get bookable time slots for a specific date |
| `GET` | `/doctors/:doctorId/reviews` | ❌ | Get doctor reviews and ratings |
| `POST` | `/doctors/apply` | optional | Self-apply as a doctor (guest-friendly) |

### Doctor Self-Management

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/doctors/me/profile` | ✅ | doctor | Get own doctor profile |
| `PUT` | `/doctors/me/profile` | ✅ | doctor | Update own doctor profile |
| `GET` | `/doctors/me/hospitals` | ✅ | doctor | List hospital affiliations |
| `GET` | `/doctors/me/availability` | ✅ | doctor | Get own availability settings |
| `PUT` | `/doctors/me/availability` | ✅ | doctor | Set weekly availability schedule |
| `PUT` | `/doctors/me/availability/override` | ✅ | doctor | Override availability for specific dates |
| `GET` | `/doctors/me/appointments` | ✅ | doctor | Get own appointment list |
| `GET` | `/doctors/me/patients` | ✅ | doctor | List all own patients |
| `GET` | `/doctors/me/patients/:patientId` | ✅ | doctor | Get specific patient's clinical history |
| `GET` | `/doctors/me/analytics` | ✅ | doctor | Personal analytics dashboard |
| `GET` | `/doctors/me/reviews` | ✅ | doctor | List own patient reviews |
| `POST` | `/doctors/me/reviews/:reviewId/reply` | ✅ | doctor | Reply to a patient review |
| `GET` | `/doctors/me/payouts` | ✅ | doctor | List own payout history |
| `POST` | `/doctors/me/payouts` | ✅ | doctor | Request a payout |
| `POST` | `/doctors/me/esign/setup` | ✅ | doctor | Set up e-signature |

> **Note:** every row in this section (and the equivalent doctor-side rows under Appointments, Prescriptions, AI, and Notifications) now accepts either a Clerk session JWT *or* our own mobile JWT (`authAny`) — both are mobile-app-usable. Only the **Super Admin** rows below, and hospital-admin-only endpoints elsewhere in this doc, remain Clerk-web-only (`authenticate`).

### Super Admin

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/doctors` | ✅ | super_admin | List all doctors on the platform |
| `PUT` | `/doctors/:doctorId/verify` | ✅ | super_admin | Verify doctor (NMC check passed) |
| `PUT` | `/doctors/:doctorId/block` | ✅ | super_admin | Block doctor account |
| `POST` | `/doctors/:doctorId/nmc-verify` | ✅ | super_admin | Trigger NMC council verification |
| `DELETE` | `/doctors/:doctorId` | ✅ | super_admin | Remove doctor |

---

## 5. Hospital APIs — `/api/v1/hospitals`

### Public

| Method | Endpoint | Auth | Description |
|--------|----------|:---:|-------------|
| `GET` | `/hospitals/search` | ❌ | Search verified active hospitals by `city`, `name`, `type` |
| `POST` | `/hospitals/apply` | optional | Submit hospital onboarding application (upserts pending if resubmitting) |
| `POST` | `/hospitals/upload-document` | optional | Upload document to S3. Returns `{ url: "https://s3-url..." }` |
| `GET` | `/hospitals/:hospitalId` | ❌ | Get public hospital profile (documents served via S3 presigned URLs, 1h expiry) |
| `GET` | `/hospitals/:hospitalId/doctors` | ❌ | Get doctors list for a specific hospital |

### POST /hospitals/apply — Request Body
```json
{
  "name": "City General Hospital",
  "type": "hospital",          // hospital | clinic | diagnostic_centre | pharmacy
  "pocName": "Dr. Admin",
  "pocPhone": "+919876543210",
  "email": "admin@hospital.com",
  "address": { "city": "Mumbai", "state": "Maharashtra", "pincode": "400001" },
  "documents": {
    "regCert": "https://mediconnectai.s3.ap-south-1.amazonaws.com/hospital-documents/...",
    "gst": "https://mediconnectai.s3.ap-south-1.amazonaws.com/hospital-documents/..."
  }
}
```

### Applicant Polling

| Method | Endpoint | Auth | Description |
|--------|----------|:---:|-------------|
| `GET` | `/hospitals/me/application-status` | ✅ | Poll own org application status before role is granted |

### Hospital Admin

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/hospitals/me/profile` | ✅ | hospital_admin, pharmacist | Get own hospital profile |
| `PUT` | `/hospitals/me/profile` | ✅ | hospital_admin, pharmacist | Update own hospital profile |
| `PUT` | `/hospitals/me/operating-hours` | ✅ | hospital_admin | Update operating hours |
| `POST` | `/hospitals/me/photos` | ✅ | hospital_admin | Upload hospital photos (max 10, multipart) |
| `DELETE` | `/hospitals/me/photos/:photoId` | ✅ | hospital_admin | Remove a hospital photo |
| `GET` | `/hospitals/me/analytics` | ✅ | hospital_admin | General analytics dashboard |
| `GET` | `/hospitals/me/analytics/doctors` | ✅ | hospital_admin | Doctor-specific analytics |
| `GET` | `/hospitals/me/analytics/revenue` | ✅ | hospital_admin | Revenue analytics *(stub — returns placeholder message)* |
| `GET` | `/hospitals/me/subscription` | ✅ | hospital_admin | Get current subscription status |
| `POST` | `/hospitals/me/subscription/upgrade` | ✅ | hospital_admin | Upgrade subscription plan |
| `POST` | `/hospitals/me/subscription/cancel` | ✅ | hospital_admin | Cancel subscription |

### Doctor Management by Hospital Admin

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/hospitals/me/doctors` | ✅ | hospital_admin | List all linked doctors |
| `POST` | `/hospitals/me/doctors/invite` | ✅ | hospital_admin | Invite doctor via email (Clerk invite + Brevo email) |
| `POST` | `/hospitals/me/doctors/add` | ✅ | hospital_admin | Directly add doctor by userId (no invite flow) |
| `DELETE` | `/hospitals/me/doctors/:doctorId` | ✅ | hospital_admin | Remove doctor from hospital |

### Invite Application Review (Hospital Admin)

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/hospitals/me/invites` | ✅ | hospital_admin | List all pending invites and applications |
| `GET` | `/hospitals/me/invites/:inviteId/application` | ✅ | hospital_admin | Get a specific submitted application |
| `POST` | `/hospitals/me/invites/:inviteId/approve` | ✅ | hospital_admin | Approve application → grants `doctor` role |
| `POST` | `/hospitals/me/invites/:inviteId/reject` | ✅ | hospital_admin | Reject application |

### Lab Technician Management

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/hospitals/me/lab-technicians` | ✅ | hospital_admin | List all lab technicians at own hospital |
| `POST` | `/hospitals/me/lab-technicians/invite` | ✅ | hospital_admin | Invite lab technician via email |
| `DELETE` | `/hospitals/me/lab-technicians/:technicianId` | ✅ | hospital_admin | Remove lab technician from hospital |
| `GET` | `/hospitals/me/lab-technician-profile` | ✅ | lab_technician | Get own lab technician profile |

### Super Admin

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/hospitals` | ✅ | super_admin | List ALL hospitals (including pending and blocked) |
| `POST` | `/hospitals` | ✅ | super_admin | Create a hospital directly |
| `PUT` | `/hospitals/:id/verify` | ✅ | super_admin | Verify hospital → `isVerified=true`, `isActive=true`, promotes admin role, sends email |
| `PUT` | `/hospitals/:id/block` | ✅ | super_admin | Block hospital → `isActive=false` |
| `PUT` | `/hospitals/:id/reject` | ✅ | super_admin | Reject hospital → `isDeleted=true` |
| `PUT` | `/hospitals/:id/subscription` | ✅ | super_admin | Override subscription plan manually |
| `PUT` | `/hospitals/:id/features` | ✅ | super_admin | Update hospital-specific feature flags |

---

## 6. Appointment APIs — `/api/v1/appointments`

### Public

| Method | Endpoint | Auth | Description |
|--------|----------|:---:|-------------|
| `GET` | `/appointments/slots?doctorId=&date=` | ❌ | Get available time slots for a doctor on a given date |

### Patient

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/appointments` | ✅ | patient | Book a new appointment |
| `GET` | `/appointments/me` | ✅ | patient | Get own appointments list |
| `GET` | `/appointments/me/:appointmentId` | ✅ | patient | Get specific own appointment |
| `PUT` | `/appointments/me/:appointmentId/cancel` | ✅ | patient | Cancel own appointment |
| `PUT` | `/appointments/me/:appointmentId/reschedule` | ✅ | patient | Reschedule own appointment |
| `POST` | `/appointments/:appointmentId/checkin` | ✅ | patient | Check in for an appointment |
| `POST` | `/appointments/waitlist` | ✅ | patient | Join appointment waitlist |
| `DELETE` | `/appointments/waitlist/:appointmentId` | ✅ | patient | Leave appointment waitlist |
| `POST` | `/appointments/me/:appointmentId/request-refund` | ✅ | patient | Request a refund for a cancelled/refundable appointment |

### POST /appointments — Request Body
```json
{
  "doctorId": "<ObjectId>",
  "hospitalId": "<ObjectId>",
  "mode": "video",                // video | in_person
  "scheduledAt": "2026-07-10T10:30:00Z",
  "symptoms": "Fever and headache",
  "familyMemberId": "<ObjectId>"  // optional — book on behalf of family member
}
```

### Doctor

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/appointments/doctor` | ✅ | doctor | Get all own appointments |
| `GET` | `/appointments/doctor/revenue` | ✅ | doctor | Own revenue summary (used by Earnings) |
| `POST` | `/appointments/walkin` | ✅ | doctor | Book a walk-in appointment for a patient physically present |
| `PUT` | `/appointments/:appointmentId/confirm` | ✅ | doctor | Confirm appointment → status: `confirmed` |
| `PUT` | `/appointments/:appointmentId/start` | ✅ | doctor | Start session → status: `in_progress` |
| `PUT` | `/appointments/:appointmentId/complete` | ✅ | doctor | Mark completed → status: `completed` |
| `PUT` | `/appointments/:appointmentId/no-show` | ✅ | doctor | Mark patient as no-show |
| `PUT` | `/appointments/:appointmentId/cancel` | ✅ | doctor, hospital_admin | Cancel appointment |

### Appointment Status Flow
```
scheduled → confirmed → in_progress → completed
                                    ↘ no_show
         ↘ cancelled  (patient or doctor/hospital)
```

### Shared / Admin

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/appointments/:appointmentId` | ✅ | doctor, patient, hospital_admin | Get appointment by ID |
| `GET` | `/appointments` | ✅ | super_admin, hospital_admin | List all platform appointments |
| `PUT` | `/appointments/:appointmentId/force-cancel` | ✅ | super_admin | Force cancel any appointment |
| `POST` | `/appointments/admin-book` | ✅ | hospital_admin | Book an appointment on behalf of an existing patient, assigning one of the hospital's own doctors |

---

## 7. Consultation APIs — `/api/v1/consultations`

> Consultations are linked 1:1 to appointments. Holds video session data, SOAP notes, transcript, and clinical summaries.

### Video Session (LiveKit)

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/consultations/:id/video/token` | ✅ | doctor, patient | Get LiveKit JWT to join video room |
| `POST` | `/consultations/:id/recording/start` | ✅ | doctor | Start recording (LiveKit Egress) |
| `POST` | `/consultations/:id/recording/stop` | ✅ | doctor | Stop recording |
| `PUT` | `/consultations/:id/consent` | ✅ | patient | Submit patient consent for recording |

#### Video Token Response
```json
{
  "success": true,
  "data": {
    "token": "<livekit_jwt>",
    "livekitUrl": "wss://livekit.example.com",
    "roomName": "consult-<consultationId>",
    "consultationId": "<consultationId>",
    "recordingEnabled": true
  }
}
```
> Token TTL: **3600s** · Room format: `consult-{consultationId}`  
> If `LIVEKIT_API_KEY`/`LIVEKIT_API_SECRET` are unset, falls back to `POST {AI_SERVICE_URL}/voice/token` (env-configurable; defaults to `http://ai-service:8000`, **not** a hardcoded `ai.shikhartesting.dev` URL) and uses that response's `server_url` in place of `livekitUrl`.

### Clinical Entries (Doctor)

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `PUT` | `/consultations/:id/diagnosis` | ✅ | doctor | Add / update diagnosis |
| `PUT` | `/consultations/:id/notes` | ✅ | doctor | Update SOAP clinical notes |
| `PUT` | `/consultations/:id/soap` | ✅ | doctor | Approve AI-generated SOAP note |
| `PUT` | `/consultations/:id/follow-up` | ✅ | doctor | Set follow-up *(stub — not yet implemented)* |
| `POST` | `/consultations/:id/referral` | ✅ | doctor | Generate referral letter |

### Summary & Completion

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/consultations/:id/summary` | ✅ | doctor, patient | Get clinical summary |
| `POST` | `/consultations/:id/summary/deliver` | ✅ | doctor | Deliver summary to patient *(stub — not yet implemented)* |
| `POST` | `/consultations/:id/complete` | ✅ | doctor | Mark consultation as completed |

### History

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/consultations/me` | ✅ | patient | Patient's own consultation history |
| `GET` | `/consultations/doctor` | ✅ | doctor | Doctor's own consultation history |
| `GET` | `/consultations/:id/transcript` | ✅ | doctor | Get audio transcript |
| `GET` | `/consultations/:id` | ✅ | doctor, patient | Get single consultation details |

### Async Chat (In-Consultation Messaging)

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/consultations/:id/messages` | ✅ | doctor, patient | Send a chat message |
| `GET` | `/consultations/:id/messages` | ✅ | doctor, patient | Get all chat messages |

---

## 8. Prescription APIs — `/api/v1/prescriptions`

### Doctor (CRUD)

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/prescriptions` | ✅ | doctor | Create a prescription draft |
| `GET` | `/prescriptions/by-consultation/:consultationId` | ✅ | doctor, patient | Get prescriptions by consultation |
| `GET` | `/prescriptions/:prescriptionId` | ✅ | doctor, patient | Get prescription details |
| `PUT` | `/prescriptions/:prescriptionId` | ✅ | doctor | Update prescription draft |
| `POST` | `/prescriptions/:prescriptionId/approve` | ✅ | doctor | Approve & digitally sign → generates PDF → sends email to patient |
| `GET` | `/prescriptions/:prescriptionId/pdf` | ✅ | doctor, patient | Download prescription PDF |
| `DELETE` | `/prescriptions/:prescriptionId` | ✅ | doctor | Cancel / delete prescription |

### Prescription Status Flow
```
draft → approved
```

### Patient — Own Prescriptions

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/prescriptions/me/list` | ✅ | patient | List own prescriptions |

### Medicine Reminders

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/prescriptions/:prescriptionId/reminders` | ✅ | patient | Create reminders for a prescription *(stub)* |
| `GET` | `/prescriptions/reminders/me` | ✅ | patient | Get own active medicine reminders |
| `PUT` | `/prescriptions/reminders/:reminderId` | ✅ | patient | Update specific reminder schedule |
| `DELETE` | `/prescriptions/reminders/:reminderId` | ✅ | patient | Delete specific reminder |
| `POST` | `/prescriptions/reminders/:reminderId/acknowledge` | ✅ | patient | Log dose taken *(stub)* |
| `GET` | `/prescriptions/reminders/me/adherence` | ✅ | patient, doctor | Get medicine adherence report |

### Medicine Database Search

| Method | Endpoint | Auth | Description |
|--------|----------|:---:|-------------|
| `GET` | `/prescriptions/medicines/search?q=` | ✅ | Search medicines database proxy |
| `GET` | `/prescriptions/medicines/:drugId` | ✅ | Get specific drug information |

---

## 9. Lab Report APIs — `/api/v1/lab`

### Patient — Upload & Manage

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/lab/reports` | ✅ | patient | Upload lab report files to S3 (max 5 files, multipart/form-data) |
| `GET` | `/lab/reports/me` | ✅ | patient | Get own lab reports list |
| `GET` | `/lab/reports/me/:reportId` | ✅ | patient | Get specific own lab report |
| `DELETE` | `/lab/reports/me/:reportId` | ✅ | patient | Delete own lab report |
| `POST` | `/lab/reports/:reportId/share` | ✅ | patient | Share lab report with a specific doctor |

### Doctor Views

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/lab/reports/patient/:patientId` | ✅ | doctor | Get all shared lab reports for a patient |
| `GET` | `/lab/reports/:reportId` | ✅ | doctor, lab_technician | Get full lab report details |

### Lab Technician

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/lab/reports/pending` | ✅ | lab_technician | Get pending reports queue for own hospital |
| `POST` | `/lab/reports/:reportId/results` | ✅ | lab_technician | Enter manual lab results (biomarker values) |
| `PUT` | `/lab/reports/:reportId/status` | ✅ | lab_technician | Update report status (pending → completed) |

### Analytics & Critical Alerts

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `GET` | `/lab/trends/:patientId` | ✅ | patient, doctor | Get biomarker trend history |
| `GET` | `/lab/critical-alerts` | ✅ | doctor, hospital_admin | Get list of critical biomarker alerts |
| `PUT` | `/lab/critical-alerts/:reportId/acknowledge` | ✅ | doctor, hospital_admin | Acknowledge a critical alert |

---

## 10. Notification APIs — `/api/v1/notifications`

> Requires any valid authenticated user.

| Method | Endpoint | Auth | Description |
|--------|----------|:---:|-------------|
| `GET` | `/notifications/me` | ✅ | Get own notifications list |
| `GET` | `/notifications/me/unread-count` | ✅ | Get count of unread notifications |
| `PUT` | `/notifications/me/read` | ✅ | Mark specific notifications as read. Body: `{ ids: ["<id>", ...] }` |
| `PUT` | `/notifications/me/read-all` | ✅ | Mark all own notifications as read |
| `DELETE` | `/notifications/me/:notificationId` | ✅ | Delete a specific notification |

---

## 11. Payment APIs — `/api/v1/payments`

> Powered by Razorpay. Non-functional without `RAZORPAY_KEY_ID` configured.

### Consultation Payments (Patient)

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/payments/order` | ✅ | patient | Create Razorpay consultation payment order |
| `POST` | `/payments/verify` | ✅ | patient | Verify Razorpay signature and finalize payment |
| `GET` | `/payments/me` | ✅ | patient | Get own transaction history |
| `GET` | `/payments/:paymentId` | ✅ | any | Get specific transaction details |
| `POST` | `/payments/:paymentId/refund` | ✅ | doctor, hospital_admin | Initiate refund |

### Subscription Payments (Hospital Admin)

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/payments/subscription/create` | ✅ | hospital_admin | Create Razorpay subscription order |
| `POST` | `/payments/subscription/upgrade` | ✅ | hospital_admin | Upgrade subscription plan |
| `POST` | `/payments/subscription/cancel` | ✅ | hospital_admin | Cancel subscription |
| `GET` | `/payments/subscription/invoices` | ✅ | hospital_admin | Get historical subscription invoices |

---

## 12. Admin APIs — `/api/v1/admin`

> **All routes require `super_admin` role** — applied globally to the router.

### Platform Statistics

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/stats` | Overview platform stats (total users, hospitals, appointments, revenue) |
| `GET` | `/admin/stats/daily` | Daily activity statistics |

### Hospital Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/hospitals` | List all registered hospitals |
| `GET` | `/admin/hospitals/:hospitalId` | Get detailed hospital information |
| `PUT` | `/admin/hospitals/:hospitalId/verify` | Approve / verify hospital account |
| `PUT` | `/admin/hospitals/:hospitalId/block` | Block / deactivate hospital account |
| `PUT` | `/admin/hospitals/:hospitalId/subscription` | Manually override hospital subscription |
| `PUT` | `/admin/hospitals/:hospitalId/features` | Update hospital-specific feature flags |

### Doctor Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/doctors` | List all doctors |
| `PUT` | `/admin/doctors/:doctorId/verify` | Verify doctor profile |
| `PUT` | `/admin/doctors/:doctorId/block` | Block doctor account |

### Patient Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/patients` | List all registered patients |
| `PUT` | `/admin/patients/:patientId/block` | Block patient account |

### Platform Operations

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/audit-logs` | Fetch DPDP compliance audit logs |
| `GET` | `/admin/payments` | List all system transactions |
| `POST` | `/admin/notifications/broadcast` | Broadcast global notification to users |
| `GET` | `/admin/feature-flags` | Get list of system-wide feature flags |

---

## 13. AI APIs — `/api/v1/ai`

> All AI routes are **proxied to the external AI microservice** at `AI_SERVICE_URL`. Rate limited with `aiLimiter`.

### Patient

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/ai/symptom-check` | ✅ | patient | Symptom checker — returns specialty suggestion and triage severity |
| `POST` | `/ai/health-assistant` | ✅ | patient | Conversational health assistant |
| `POST` | `/ai/disease-risk` | ✅ | patient | Predict chronic disease risks from health data |
| `POST` | `/ai/chat` | ✅ | patient | Conversational AI clinical assistant |
| `POST` | `/ai/chat/report` | ✅ | patient | AI chat with attached report file (multipart, max 25 MB) |
| `GET` | `/ai/chat/conversations` | ✅ | patient | List own AI chat conversation history |
| `DELETE` | `/ai/chat/conversations/:id` | ✅ | patient | Delete an AI chat conversation |
| `GET` | `/ai/chat/history/:id` | ✅ | patient | Get full message history for a conversation |
| `POST` | `/ai/lab-analysis` | ✅ | patient | Upload lab report for AI analysis (multipart, max 25 MB) |
| `POST` | `/ai/voice/token` | ✅ | patient | Get LiveKit token for MedAI voice assistant |

### Doctor

| Method | Endpoint | Auth | Role | Description |
|--------|----------|:---:|------|-------------|
| `POST` | `/ai/prescription-assist` | ✅ | doctor | AI-assisted prescription drafting |
| `GET` | `/ai/drug-interactions?drugs=` | ✅ | doctor | Check drug interaction warnings |

### Shared

| Method | Endpoint | Auth | Description |
|--------|----------|:---:|-------------|
| `POST` | `/ai/lab-interpret` | ✅ | AI interpretation of an uploaded lab report |

---

## 14. Invite APIs — `/api/v1/invites`

> Hospital admins send email invites to doctors / lab technicians. Recipients use these to complete onboarding.

| Method | Endpoint | Auth | Description |
|--------|----------|:---:|-------------|
| `GET` | `/invites/:token` | optional | Get invite context (public — renders accept page before sign-in) |
| `POST` | `/invites/:token/accept` | ✅ | Accept invite. **Lab technician invites only** — mints `lab_technician` role immediately. A `doctor`-type invite hitting this endpoint gets `400 USE_APPLICATION_FLOW`; doctors must go through the application flow below instead. |

> All endpoints in this section now accept either a Clerk session JWT or our own mobile JWT (`authAny`) — needed so the Flutter doctor app can complete invite-accept onboarding without a Clerk-web session.
>
> A hospital admin can alternatively skip invites entirely via `POST /hospitals/me/doctors/add` (see §5 "Doctor Management by Hospital Admin") to add a doctor directly with no invite/application step — not part of this flow, but the other onboarding path a hospital admin may use.

### Doctor Application Flow (via Invite)

| Method | Endpoint | Auth | Description |
|--------|----------|:---:|-------------|
| `POST` | `/invites/:token/application` | ✅ | Start or update a doctor application form |
| `POST` | `/invites/:token/application/documents` | ✅ | Upload a document for the application (multipart, single file) |
| `DELETE` | `/invites/:token/application/documents/:docId` | ✅ | Remove an uploaded application document |
| `POST` | `/invites/:token/application/submit` | ✅ | Submit application for hospital admin review |

### GET /invites/:token — Response
```json
{
  "success": true,
  "data": {
    "token": "<uuid>",
    "type": "doctor",          // doctor | lab_technician
    "hospitalName": "City Hospital",
    "email": "invited@example.com",
    "expiresAt": "2026-07-10T00:00:00Z"
  }
}
```

---

## 15. Webhook APIs — `/api/v1/webhooks`

> No auth middleware. Webhooks are verified via HMAC signatures in their respective controllers.

| Method | Endpoint | Verified By | Description |
|--------|----------|-------------|-------------|
| `POST` | `/webhooks/razorpay` | `X-Razorpay-Signature` | Razorpay payment events (`payment.captured`, `payment.failed`, `refund.processed`) |
| `POST` | `/webhooks/esign` | eSign provider header | eSign document status callback |
| `POST` | `/webhooks/livekit` | LiveKit SDK | Room and egress (recording) events |
| `POST` | `/webhooks/clerk` | `svix-signature` | Clerk user lifecycle (`user.created`, `user.deleted`) |
| `POST` | `/webhooks/ai/transcript` | `X-AI-Service-Key` | Receive consultation audio transcript from AI service |
| `POST` | `/webhooks/ai/soap-note` | `X-AI-Service-Key` | Receive generated SOAP note draft |
| `POST` | `/webhooks/ai/patient-summary` | `X-AI-Service-Key` | Receive patient health summary |
| `POST` | `/webhooks/ai/lab-interpretation` | `X-AI-Service-Key` | Receive lab report AI interpretation |
| `POST` | `/webhooks/ai/symptom-result` | `X-AI-Service-Key` | Receive symptom checker triage results |
| `POST` | `/webhooks/ai/prescription-draft` | `X-AI-Service-Key` | Receive suggested prescription draft |
| `POST` | `/webhooks/ai/risk-scores` | `X-AI-Service-Key` | Receive chronic disease risk scores |
| `POST` | `/webhooks/exotel` | Exotel | Exotel voice call status callback |

---

## 16. Socket.IO

> **Namespace:** `/consultation`  
> **Connection URL:** `ws://localhost:5000/consultation`

```javascript
// Client connection example
const socket = io('http://localhost:5000/consultation', {
  auth: { token: '<bearer_token>' }
})
```

> **Auth:** pass either our own mobile JWT (Flutter apps) or a Clerk session JWT (web) as `token` — the middleware tries the mobile secret first, then falls back to Clerk (mirrors the REST `authAny` precedence). There is a second namespace, `/notifications`, with the same auth scheme (see `emitNotification`/`notification:new` below) — used for the header/bell live notification feed, separate from in-consultation events.
>
> The event names below are read directly from `src/sockets/consultation.socket.js` — a previous version of this doc listed generic placeholder names (`join-room`, `send-message`, `soap-note-generated`, `typing`, `transcript-updated`) that never existed in code. Build against the table below, not those.

### Client → Server Events

| Event | Payload | Description |
|-------|---------|-------------|
| `consultation:join` | `{ consultationId }` | Join a consultation room. Server checks the caller is the consultation's doctor/patient (or `super_admin`) before allowing the join. |
| `consultation:leave` | `{ consultationId }` | Leave a consultation room. |
| `message:send` | `{ consultationId, text }` | Send an async chat message; persisted onto `Consultation.messages`. |
| `transcript:start` | `{ consultationId }` | Doctor (or `super_admin`) opens a Deepgram dual-channel STT session for this call. |
| `transcript:audio` | `{ consultationId, role, chunk }` | Raw audio chunk for one speaker (`role`: `'doctor'` \| `'patient'`), routed to that speaker's Deepgram connection. |
| `transcript:stop` | `{ consultationId }` | Doctor (or `super_admin`) ends the call: flushes Deepgram, persists `transcript.rawText`/`speakerDiarization`, triggers AI SOAP-note generation (non-fatal on failure). |
| `consent:decision` | `{ consultationId, consented }` | Patient's recording-consent decision. |

### Server → Client Events

| Event | Payload | Description |
|-------|---------|-------------|
| `participant:joined` | `{ userId, role }` | A participant joined the room (broadcast to the rest of the room). |
| `participant:left` | `{ userId }` | A participant left the room. |
| `message:received` | `{ message }` | Broadcast of a persisted chat message (the full stored message subdocument). |
| `transcript:chunk` | `{ speaker, text, isFinal }` | Live interim/final transcript chunk from Deepgram, for one speaker. |
| `consent:recorded` | `{ consented }` | Broadcast once the patient's consent decision is saved. |
| `error` | `{ message }` | Generic error ack (e.g. consultation not found, not authorized). |
| `notification:new` *(on the `/notifications` namespace, not `/consultation`)* | notification document | Pushed to a user's private room (keyed by `userId`) whenever `notification.service` persists a new notification. |

There is no `soap-note-generated` or `transcript-updated` event — SOAP-note generation is triggered server-side after `transcript:stop` and delivered via the regular `GET /consultations/:id/summary` REST endpoint once ready, not pushed over the socket.

---

## 17. Data Models

### User
| Field | Type | Notes |
|-------|------|-------|
| `clerkId` | String | Clerk user ID |
| `role` | Enum | patient \| doctor \| hospital_admin \| lab_technician \| super_admin |
| `phone` | String | |
| `email` | String | |
| `fcmTokens` | Array | Firebase push tokens |
| `isActive` | Boolean | Default: true |
| `isBlocked` | Boolean | Default: false |

### Patient
| Field | Type | Notes |
|-------|------|-------|
| `userId` | ObjectId | Ref: User |
| `firstName`, `lastName` | String | PHI-encrypted at rest |
| `dateOfBirth`, `gender`, `bloodGroup` | Mixed | |
| `abhaId` | String | ABDM identifier |
| `location` | Object | lat, lng, address, city, state, pincode |
| `vitals` | Object | BP, HR, SpO2, temperature, etc. |
| `allergies` | Array | |
| `familyMembers`, `emergencyContacts` | Array | |
| `healthScore` | Number | |

### Doctor
| Field | Type | Notes |
|-------|------|-------|
| `userId` | ObjectId | Ref: User |
| `hospitalId` | ObjectId, nullable | Ref: Hospital — `null` means solo practitioner, not an array |
| `specialties` | Array | |
| `nmcRegistrationNumber` | String | Unique. NMC council registration — **not** `nmcNumber` |
| `isVerified`, `nmcVerified` | Boolean | |
| `consultationFeeInPerson`, `consultationFeeOnline` | Number | Two separate fee fields, not a single `consultationFee` |
| `consultationType` | Enum | `in_person` \| `online` \| `both` |
| `averageRating` | Number | Aggregate — **not** `rating` |
| `isAcceptingPatients` | Boolean | |

### Hospital
| Field | Type | Notes |
|-------|------|-------|
| `adminUserId` | ObjectId | Ref: User |
| `name`, `type` | String | type: hospital \| clinic \| diagnostic_centre \| pharmacy |
| `isVerified`, `isActive`, `isDeleted` | Boolean | |
| `documents` | Object | `{ regCert: s3url, gst: s3url }` |
| `subscription` | Object | plan, status, expiresAt |
| `features` | Object | Feature flags per hospital |

### Appointment
| Field | Type | Notes |
|-------|------|-------|
| `doctorId`, `patientId`, `hospitalId` | ObjectId | |
| `status` | Enum | scheduled → confirmed → in_progress → completed \| no_show \| cancelled |
| `mode` | Enum | video \| in_person |
| `scheduledAt` | Date | |
| `paymentId` | ObjectId | Ref: Payment |

### Consultation
| Field | Type | Notes |
|-------|------|-------|
| `appointmentId` | ObjectId | |
| `videoSession` | Object | `{ roomName, egressId, recordingS3Url, recordingStartedAt, recordingEndedAt }` — the recording URL lives at `videoSession.recordingS3Url`, **not** a top-level `recordingUrl` |
| `recordingConsent` | Object | Patient consent state for recording |
| `soapNote` | Object | `{ S, O, A, P, isApproved }` |
| `transcript` | Object | `{ rawText, speakerDiarization, transcriptUrl }` — a structured object, **not** a plain String |
| `transcriptExpiresAt` | Date | Retention cutoff (2 months); a cronjob clears transcript fields after this |
| `diagnosis`, `messages` | Array | |

### Prescription
| Field | Type | Notes |
|-------|------|-------|
| `doctorId`, `patientId`, `consultationId` | ObjectId | |
| `medicines` | Array | `{ name, dosage, frequency, duration, notes }` |
| `status` | Enum | draft → approved |
| `pdfUrl` | String | S3 URL generated on approval |

### LabReport
| Field | Type | Notes |
|-------|------|-------|
| `patientId`, `hospitalId` | ObjectId | |
| `files` | Array | S3 URLs |
| `aiInterpretation` | String | |
| `biomarkers` | Object | Key-value pairs |
| `status` | Enum | pending → completed |
| `criticalAlerts` | Array | |

### AuditLog (DPDP Compliance)
| Field | Type | Notes |
|-------|------|-------|
| `userId` | ObjectId | Who performed the action |
| `action` | String | e.g. `view_patient_record`, `create_patient_record` |
| `entity` | String | e.g. `Patient`, `Prescription` |
| `entityId` | ObjectId | |
| `ip` | String | |
| `timestamp` | Date | |

---

## 18. Error Responses

All errors follow a standard envelope format:

```json
{
  "success": false,
  "message": "Human-readable error message",
  "error": {
    "code": "ERROR_CODE",
    "details": []
  }
}
```

| HTTP Status | Code | Typical Cause |
|-------------|------|---------------|
| `400` | `VALIDATION_ERROR` | Invalid request body (Zod schema failure) |
| `401` | `UNAUTHORIZED` | Missing, expired, or invalid Bearer token |
| `403` | `FORBIDDEN` | Authenticated but insufficient role |
| `404` | `NOT_FOUND` | Resource does not exist |
| `409` | `CONFLICT` | Duplicate resource (e.g. profile already exists) |
| `410` | `GONE` | Invite expired or already used |
| `429` | `RATE_LIMITED` | Too many requests |
| `500` | `INTERNAL_ERROR` | Unexpected server error |

---

## 19. Not Yet Implemented (Stubs)

These endpoints are registered in route files but return stub/placeholder responses:

| Endpoint | Status |
|----------|--------|
| `PUT /consultations/:id/follow-up` | Route registered, controller logic stubbed |
| `POST /consultations/:id/summary/deliver` | Route registered, not implemented |
| `POST /prescriptions/:id/reminders` | Route registered, logic stubbed |
| `POST /prescriptions/reminders/:id/acknowledge` | Route registered, logic stubbed |
| `GET /patients/me/health-twin` | Returns 200 with placeholder data |
| `POST /patients/me/abdm/link` | ABHA linking not implemented |
| `GET /hospitals/me/analytics/revenue` | Returns stub message |
| All `/ai/*` routes | Functional only if `AI_SERVICE_URL` env var is set |

---

## Quick Reference: Services & Integrations

| Service | Purpose | Required Env Vars | Status |
|---------|---------|-------------------|--------|
| **Clerk** | Web auth / JWT | `CLERK_SECRET_KEY`, `CLERK_PUBLISHABLE_KEY` | ✅ Configured |
| **MongoDB Atlas** | Primary database | `MONGODB_URI` | ✅ Configured |
| **Redis** | Rate limiting, queues | `REDIS_URL` | ✅ Local |
| **AWS S3** | File storage | `AWS_ACCESS_KEY_ID`, `S3_BUCKET_NAME` | ✅ Configured |
| **Brevo** | Transactional email | `BREVO_API_KEY`, `BREVO_SENDER_EMAIL` | ✅ Configured |
| **LiveKit** | Video consultations | `LIVEKIT_API_KEY`, `LIVEKIT_URL` | ⚠️ Uses fallback |
| **Firebase** | FCM push notifications | `FIREBASE_PRIVATE_KEY`, `FIREBASE_PROJECT_ID` | ❌ Key missing |
| **Razorpay** | Payments & subscriptions | `RAZORPAY_KEY_ID`, `RAZORPAY_SECRET` | ❌ Not configured |
| **Twilio** | SMS reminders | `TWILIO_ACCOUNT_SID` | ❌ Not configured |
| **Exotel** | Voice calls | `EXOTEL_API_KEY` | ❌ Not configured |
| **OpenAI / AI Service** | Whisper, GPT-4o, AI proxy | `AI_SERVICE_URL` | ⚠️ External service |

---

*Last updated: 2026-07-02 · Source: `healthcare-api/src/routes/` (16 route files, 16 controllers)*
