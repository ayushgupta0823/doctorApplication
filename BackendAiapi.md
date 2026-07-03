# AI Healthcare Operating System — AI Service

India's first unified AI-powered healthcare backend. This FastAPI service is the AI brain of the **AI Healthcare OS** — powering 10 modules across patients, doctors, labs, pharmacies, and administrators.

**Powered by:** Gemini 2.5 Flash · FastAPI · Pydantic v2 · LiveKit Voice AI

---

## Modules Implemented

| Module | Description | Endpoints |
|--------|-------------|-----------|
| **1 — AI Patient App** | Health assistant, health score | `/ai/chat`, `/ai/chat/report`, `/ai/health-score` |
| **2 — AI Doctor App** | Medical scribe, prescription generator, risk alerts | `/ai/summarize`, `/ai/prescription`, `/ai/risk-alerts` |
| **3 — AI Lab System** | Report analysis, abnormal detection | `/ai/lab-analysis` |
| **4 — AI Pharmacy** | Inventory forecast, expiry alerts, substitutes | `/ai/pharmacy/*` |
| **5 — AI Appointments** | Doctor matching, emergency routing | `/ai/appointment/*` |
| **6 — Payment & Insurance** | Policy analysis, coverage verification | `/ai/insurance/analyze-policy` |
| **7 — Telemedicine** | Voice token for video consultations | `/ai/voice/token` |
| **9 — AI Innovations** | Disease prediction, recovery check-in | `/ai/disease-prediction`, `/ai/recovery/check-in` |
| **9.5 — AI Voice Hospital** | Full voice agent (LiveKit) for all interactions | `agent.py` |

---

## Technology Stack

- **Framework**: FastAPI (async Python)
- **AI Model**: Google Gemini 2.5 Flash (structured output + chat)
- **Voice Stack**: LiveKit + Deepgram STT + Cartesia TTS + Silero VAD
- **Data Schemas**: Pydantic v2
- **Server**: Uvicorn (ASGI)
- **Testing**: Pytest + FastAPI TestClient

---

## Project Structure

```
ai-service/
│
├── app.py                        # Main entrypoint — CORS, routers, exception handlers
├── agent.py                      # LiveKit voice agent (AI Voice Hospital)
├── requirements.txt
├── .env.example
│
├── routes/
│   ├── chat.py                   # POST /ai/chat, POST /ai/chat/report
│   ├── summarize.py              # POST /ai/summarize
│   ├── lab_analysis.py           # POST /ai/lab-analysis
│   ├── prescription.py           # POST /ai/prescription
│   ├── risk_alerts.py            # POST /ai/risk-alerts
│   ├── health_score.py           # POST /ai/health-score
│   ├── pharmacy.py               # POST /ai/pharmacy/*
│   ├── appointment.py            # POST /ai/appointment/*
│   ├── insurance.py              # POST /ai/insurance/analyze-policy
│   ├── disease_prediction.py     # POST /ai/disease-prediction
│   ├── recovery.py               # POST /ai/recovery/check-in
│   └── voice.py                  # POST /ai/voice/token
│
├── services/
│   ├── gemini_service.py         # Gemini API client wrapper
│   ├── openai_service.py         # OpenAI API client wrapper
│   ├── llm_factory.py            # Picks Gemini/OpenAI provider per request
│   ├── chat_history.py           # MongoDB-backed chat/voice history
│   ├── guardrails.py             # Emergency keyword detection + safety sanitisation
│   └── prompts.py                # All clinical system prompts
│
├── models/
│   ├── summary_models.py
│   ├── lab_models.py
│   ├── prescription_models.py
│   ├── pharmacy_models.py
│   ├── appointment_models.py
│   ├── insurance_models.py
│   ├── health_score_models.py
│   └── prediction_models.py      # Disease prediction + recovery check-in
│
├── monitoring/
│   ├── db.py                     # Usage-tracking SQLite storage
│   ├── routes.py                 # GET /usage dashboard + API
│   └── tracker.py                # Per-request usage/cost tracking
│
├── tools/
│   └── tools.py                  # search_web tool used by /ai/chat
│
├── utils/
│   ├── auth.py                   # Admin-token auth for the usage dashboard
│   └── validators.py
│
└── tests/
    └── test_api.py
```

---

## Setup

### 1. Environment Variables
```bash
copy .env.example .env
```

Fill in `.env`:
```env
GEMINI_API_KEY=AIzaSy...
LIVEKIT_API_KEY=your_livekit_key
LIVEKIT_API_SECRET=your_livekit_secret
LIVEKIT_URL=ws://localhost:7880
DEEPGRAM_API_KEY=your_deepgram_key
CARTESIA_API_KEY=your_cartesia_key
SERVICE_API_KEY=your_generated_key   # required on every /ai/* call, see below
ADMIN_TOKEN=your_generated_token     # required for /admin/usage/*
PORT=8000
HOST=0.0.0.0
LOG_LEVEL=INFO
```

> **This service has no per-user authentication of its own.** Every `/ai/*` endpoint requires an `X-API-Key: <SERVICE_API_KEY>` header — it is meant to be called only by your own backend, after that backend has already authenticated the end user, never directly by a browser or mobile app. See [SETUP.md](SETUP.md#service_api_key--required-for-every-ai-request) for details.

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Run the API Server
```bash
python app.py
```
API live at `http://localhost:8000` · Interactive docs at `http://localhost:8000/docs`

### 4. Run the Voice Agent (AI Voice Hospital)
```bash
python agent.py dev
```

### 5. Run Tests
```bash
python -m pytest
```

---

## API Reference

> **Authentication:** every endpoint below requires an `X-API-Key: <SERVICE_API_KEY>` header — this service only accepts calls from your own backend (see [Setup](#1-environment-variables)). Examples below omit it for brevity; add it to every request.

### Role Legend

| Role | Who Uses It |
|------|-------------|
| **Patient** | Individual users via mobile/web app |
| **Doctor** | Physicians via the AI Doctor App |
| **Pharmacist** | Pharmacy staff via the AI Pharmacy module |
| **Lab** | Laboratory staff and systems |
| **Admin** | Hospital administrators |
| **System** | Internal services, telemedicine platform |

---

### Module 1 — AI Patient Application

---

#### `POST /ai/chat`
**Role: Patient**

Multi-turn conversational symptom checker with clinical chain-of-thought reasoning, web search grounding, and location-aware doctor referrals.

```json
// Request
{
  "history": [
    { "role": "user", "content": "I have chest tightness and shortness of breath since morning." }
  ]
}

// Response
{
  "answer": "<thought>...</thought> Chest tightness with shortness of breath can indicate several conditions ranging from anxiety to cardiac causes. Let me ask you more:\n- Is the tightness constant or does it come and go?\n- Do you have any history of heart disease or asthma?",
  "referrals": []
}
```

> **Note:** `referrals` returns a plain list of specialty names (e.g. `["Cardiology", "General Medicine"]`). The application backend resolves these to actual doctors using its own location and availability data.

---

#### `POST /ai/health-score`
**Role: Patient**

Calculates a composite health score out of 100 using biometric and lifestyle data. Uses ICMR population benchmarks.

```json
// Request
{
  "metrics": {
    "age": 42,
    "gender": "male",
    "weight_kg": 82,
    "height_cm": 172,
    "systolic_bp": 138,
    "diastolic_bp": 88,
    "fasting_glucose_mg": 108,
    "hba1c_percent": 5.9,
    "daily_steps": 4200,
    "sleep_hours": 6.0,
    "stress_level": "high",
    "smoking": false,
    "alcohol_units_per_week": 4,
    "known_conditions": ["hypertension"]
  },
  "previous_score": 61
}

// Response
{
  "overall_score": 58,
  "grade": "Fair",
  "parameter_breakdown": [
    { "parameter": "Blood Pressure", "value": "138/88 mmHg", "score": 5, "status": "borderline", "insight": "Stage 1 hypertension range." },
    { "parameter": "Sleep", "value": "6.0 hrs", "score": 6, "status": "borderline", "insight": "Below recommended 7-9 hours." }
  ],
  "top_improvement_actions": [
    "Reduce sodium intake to below 2g/day to help manage blood pressure.",
    "Increase daily steps to 8,000+ — target 30 min brisk walking daily.",
    "Improve sleep hygiene — aim for 7.5 hours with a consistent bedtime."
  ],
  "score_trend": "declining",
  "disclaimer": "This health score is informational and not a clinical diagnosis."
}
```

---

### Module 2 — AI Doctor Application

---

#### `POST /ai/summarize`
**Role: Doctor · System**

AI Medical Scribe — extracts structured SOAP-style notes from raw consultation text.

```json
// Request
{ "notes": "Patient c/o high BP since 2 weeks. On Amlodipine 5mg. BP today 148/92. Advised salt restriction. RFT ordered. Follow up 4 weeks." }

// Response
{
  "main_concerns": "Poorly controlled hypertension.",
  "doctor_notes": "Patient presenting with elevated blood pressure (148/92 mmHg) despite current antihypertensive therapy. Renal function tests ordered to rule out secondary causes.",
  "medications": ["Amlodipine 5mg"],
  "follow_up": "Review in 4 weeks with RFT results."
}
```

---

#### `POST /ai/prescription`
**Role: Doctor**

AI Prescription Generator. Suggests clinically appropriate medicines, checks drug interactions and allergy conflicts, and adjusts dosages for organ impairment. **Doctor approval is always required.**

```json
// Request
{
  "diagnosis": "Community-acquired pneumonia (mild)",
  "patient_profile": {
    "age": 58,
    "weight_kg": 70,
    "gender": "male",
    "allergies": ["penicillin"],
    "current_medications": ["Metformin 500mg", "Amlodipine 5mg"],
    "comorbidities": ["Type 2 Diabetes", "Hypertension"],
    "renal_impairment": false,
    "hepatic_impairment": false
  },
  "additional_notes": "SpO2 96%, CXR shows right lower lobe consolidation."
}

// Response
{
  "suggested_medicines": [
    {
      "name": "Azithromycin",
      "branded_example": "Zithromax / Azee",
      "dosage": "500mg",
      "frequency": "Once daily",
      "duration": "5 days",
      "route": "oral",
      "dietary_instructions": "Can be taken with or without food."
    }
  ],
  "interaction_warnings": [],
  "allergy_flags": ["Penicillin-class antibiotics (amoxicillin, ampicillin) are contraindicated — penicillin allergy on record."],
  "dosage_adjustments": [],
  "doctor_approval_required": true,
  "disclaimer": "This AI-generated prescription suggestion requires explicit doctor review and approval before dispensing."
}
```

---

#### `POST /ai/risk-alerts`
**Role: Doctor**

Pre-consultation risk briefing. Generates a concise risk card for the doctor before the patient enters — surfacing allergies, comorbidity interactions, medication gaps, and recent lab abnormalities.

```json
// Request
{
  "patient_name": "Ramesh Sharma",
  "age": 65,
  "gender": "male",
  "active_conditions": ["Type 2 Diabetes", "CKD Stage 3", "Hypertension"],
  "known_allergies": ["sulfonamides"],
  "current_medications": ["Metformin 500mg", "Losartan 50mg"],
  "recent_lab_abnormalities": ["Serum Creatinine 2.1 mg/dL (High)", "eGFR 38 (Low)"],
  "unfilled_prescriptions": ["Metformin 500mg — last refill 45 days ago"]
}

// Response
{
  "patient_summary": "65-year-old male with poorly controlled diabetes complicated by CKD Stage 3 and hypertension. Renal function has declined — creatinine elevated at 2.1.",
  "risk_tier": "High-Risk",
  "risk_flags": [
    { "category": "medication_gap", "description": "Metformin not refilled in 45 days — high risk of uncontrolled glycaemia.", "severity": "critical" },
    { "category": "lab_critical", "description": "eGFR 38 — Metformin may be contraindicated at this level. Review dosing.", "severity": "critical" },
    { "category": "allergy", "description": "Sulfonamide allergy on record — avoid thiazide diuretics (hydrochlorothiazide).", "severity": "warning" }
  ],
  "clinical_guidelines": [
    "KDIGO 2022: Metformin should be stopped if eGFR falls below 30. Consider dose reduction at eGFR 30-45.",
    "ADA 2024: HbA1c target for CKD patients with diabetes is <8.0% to reduce hypoglycaemia risk."
  ],
  "pre_consultation_checklist": ["Review and adjust Metformin dose.", "Order repeat HbA1c and urine ACR.", "Assess blood pressure control — target <130/80 in CKD + diabetes."]
}
```

---

### Module 3 — AI Laboratory System

---

#### `POST /ai/lab-analysis`
**Role: Patient · Doctor · Lab**

Analyzes an attached lab report **image or PDF** (not raw text — this is a `multipart/form-data` file upload, same style as [`/ai/chat/report`](APIDOC.md#2b-chat-with-an-attached-report-image-or-pdf--full-beginner-walkthrough)), identifies abnormal values, and generates patient-friendly explanations plus which specialist to see. Runs on the stronger model (`gpt-4o` / `gemini-2.5-flash`) rather than the default small/fast one, since reliably comparing a value against its reference range needs the extra accuracy.

```bash
# Request — multipart/form-data, field name "file"
curl -X POST http://localhost:8000/ai/lab-analysis \
  -H "X-API-Key: <SERVICE_API_KEY>" \
  -F "file=@report.pdf;type=application/pdf"
```

```json
// Response
{
  "abnormal_values": [
    { "parameter": "Hemoglobin", "value": "9.5 g/dL", "reference_range": "13.0-17.0 g/dL", "finding": "Low" },
    { "parameter": "Serum Potassium", "value": "6.8 mEq/L", "reference_range": "3.5-5.0 mEq/L", "finding": "Critical High" }
  ],
  "summary": "Your hemoglobin is below normal, suggesting anaemia. Your potassium level is critically elevated — this requires urgent medical attention as it can affect heart rhythm.",
  "recommendation": "Contact your doctor immediately regarding the critically high potassium level. Do not wait for a routine appointment.",
  "recommended_specialists": ["General Physician", "Hematologist"]
}
```
- `recommended_specialists` — specialties to consult based on which values are abnormal (e.g. `Nephrologist` for kidney panel, `Endocrinologist` for thyroid/glucose). Empty `[]` when all values are within normal range — no abnormality means no specialist needed.
- Allowed file types: `image/jpeg`, `image/png`, `image/webp`, `application/pdf`. Max size 15 MB.

---

### Module 4 — AI Pharmacy

---

#### `POST /ai/pharmacy/inventory-forecast`
**Role: Pharmacist · Admin**

Forecasts medicine demand and generates prioritised restock alerts.

```json
// Request
{
  "inventory": [
    { "medicine_name": "Metformin 500mg", "quantity": 120, "avg_daily_usage": 18, "reorder_point": 90, "season": "winter" },
    { "medicine_name": "Amoxicillin 250mg", "quantity": 30, "avg_daily_usage": 12, "reorder_point": 60 }
  ],
  "forecast_days": 30
}

// Response
{
  "restock_alerts": [
    { "medicine_name": "Amoxicillin 250mg", "current_quantity": 30, "days_remaining": 2.5, "recommended_order_quantity": 400, "priority": "critical" },
    { "medicine_name": "Metformin 500mg", "current_quantity": 120, "days_remaining": 6.7, "recommended_order_quantity": 650, "priority": "critical" }
  ],
  "demand_summary": "Two critical stock situations detected. Antibiotic and diabetes medicine supplies will be exhausted within the week.",
  "recommendations": ["Place emergency order for Amoxicillin 250mg immediately.", "Review Metformin procurement cycle — current reorder point is too low."]
}
```

---

#### `POST /ai/pharmacy/expiry-alerts`
**Role: Pharmacist**

Scans inventory for medicines expiring within 90 days and recommends actions.

```json
// Request
{
  "inventory": [
    { "medicine_name": "Ciprofloxacin 500mg", "batch_number": "B2024-09", "quantity": 200, "expiry_date": "2026-07-01" },
    { "medicine_name": "Atorvastatin 10mg", "batch_number": "B2025-01", "quantity": 50, "expiry_date": "2026-12-31" }
  ]
}

// Response
{
  "expiry_alerts": [
    {
      "medicine_name": "Ciprofloxacin 500mg",
      "batch_number": "B2024-09",
      "quantity": 200,
      "expiry_date": "2026-07-01",
      "days_until_expiry": 14,
      "urgency_bucket": "30_days",
      "recommended_action": "Expiring within 30 days — prioritise dispensing or arrange supplier return."
    }
  ],
  "total_at_risk_units": 200,
  "summary": "1 batch expiring within 90 days totalling 200 units at risk. Immediate action required for 1 batch in the 30-day window."
}
```

---

#### `POST /ai/pharmacy/substitute`
**Role: Pharmacist · Doctor**

Recommends therapeutically equivalent substitute medicines when the prescribed drug is out of stock.

```json
// Request
{
  "medicine_name": "Azithromycin 500mg",
  "patient_allergies": ["penicillin"],
  "current_medications": ["Warfarin 5mg"],
  "available_inventory": ["Clarithromycin 500mg", "Doxycycline 100mg", "Amoxicillin 500mg"]
}

// Response
{
  "original_medicine": "Azithromycin 500mg",
  "substitutes": [
    {
      "name": "Clarithromycin 500mg",
      "type": "generic",
      "bioequivalence_note": "Same macrolide class. Similar spectrum of activity and efficacy for respiratory infections.",
      "confidence": "high",
      "interaction_risk": "moderate — may potentiate Warfarin effect; monitor INR closely."
    },
    {
      "name": "Doxycycline 100mg",
      "type": "generic",
      "bioequivalence_note": "Different class (tetracycline) but effective alternative for atypical respiratory pathogens.",
      "confidence": "medium",
      "interaction_risk": "none significant with current medications."
    }
  ],
  "physician_confirmation_required": true,
  "pharmacist_note": "Amoxicillin excluded — patient has penicillin allergy. Clarithromycin is the closest equivalent but requires INR monitoring due to Warfarin interaction."
}
```

---

### Module 5 — AI Appointment System

---

#### `POST /ai/appointment/match-doctor`
**Role: Patient**

AI Doctor Matchmaker — matches the patient to the most appropriate specialist based on symptoms, history, language, insurance, and location.

```json
// Request
{
  "symptoms": "Mujhe ghutne mein bahut dard hai, seedha chalte nahi ban raha",
  "medical_history": ["Hypertension", "previous knee injury 2019"],
  "age": 55,
  "language_preference": "Hindi",
  "insurance_provider": "Star Health",
  "location_city": "Delhi"
}

// Response
{
  "matched_doctors": [
    {
      "doctor_name": "Dr. Vikram Malhotra",
      "specialty": "Orthopedics",
      "hospital": "Apollo Hospital, Saket",
      "confidence_score": 0.94,
      "rationale": "Reported knee pain with mobility limitation in a 55-year-old with prior knee injury strongly indicates an orthopaedic evaluation for osteoarthritis or ligament damage.",
      "estimated_wait_days": 2,
      "languages": ["Hindi", "English"]
    }
  ],
  "primary_specialty": "Orthopedics",
  "triage_rationale": "Chronic knee pain with functional limitation in this age group and history warrants orthopaedic assessment to rule out osteoarthritis, meniscal injury, or degenerative joint disease."
}
```

---

#### `POST /ai/appointment/emergency-route`
**Role: Patient · System**

AI Emergency Guardian — activates emergency response protocol for Red/Emergency tier symptoms. Provides patient instructions, hospital pre-alert, and ambulance dispatch decision.

```json
// Request
{
  "symptoms": "Meri maa ko achanak ek taraf ka haath aur chehra kharaab ho gaya, baat nahi kar pa rahi",
  "patient_name": "Sunita Devi",
  "location_city": "Mumbai",
  "age": 68,
  "vitals": "BP 190/110 (home monitor)"
}

// Response
{
  "emergency_tier": "EMERGENCY",
  "call_ambulance": true,
  "instructions_for_patient": "1. Abhi 108 pe call karein — ambulance mangayein. 2. Patient ko flat letao, kuch khane pine mat do. 3. Sar ko thoda upar rakhein. 4. Darwaza khol do taaki ambulance wale andar aa sakein. 5. Patient ko akela mat chodo.",
  "hospital_pre_alert": "EMERGENCY PRE-ALERT: Patient Sunita Devi, female, age 68, presenting with sudden unilateral facial droop and arm weakness with speech difficulty. BP 190/110. High suspicion of acute ischaemic stroke. Requesting stroke team activation on arrival.",
  "notify_contacts": true,
  "disclaimer": "This is an AI emergency routing system. Call 108 immediately. Do not wait for further AI instructions."
}
```

---

### Module 6 — Insurance

---

#### `POST /ai/insurance/analyze-policy`
**Role: Patient**

AI Insurance Assistant — extracts and explains health insurance policy coverage, sub-limits, exclusions, co-pay, and claim procedure in plain language.

```json
// Request
{
  "policy_text": "...full policy document text pasted here...",
  "procedure_name": "Knee Replacement Surgery"
}

// Response
{
  "sum_insured": "₹5,00,000",
  "is_procedure_covered": true,
  "coverage_details": "Your policy covers hospitalisation for surgical procedures including knee replacement. Room rent is capped at ₹3,000/day for a standard room.",
  "sub_limits": [
    { "category": "Room Rent", "limit": "₹3,000/day (standard room)" },
    { "category": "ICU", "limit": "₹6,000/day" }
  ],
  "exclusions": ["Pre-existing conditions in first 2 years", "Cosmetic surgery", "Dental treatment"],
  "co_pay_percentage": "10% of claim amount",
  "claim_procedure": "1. Inform insurer 48 hours before planned admission. 2. Submit pre-authorisation form at hospital TPA desk. 3. Hospital will coordinate directly with insurer for cashless claim. 4. Retain all original bills and discharge summary.",
  "waiting_periods": ["Pre-existing diseases: 2 years", "Maternity benefit: 3 years"],
  "disclaimer": "This is an AI interpretation of your policy document. Please confirm coverage details with your insurance provider before proceeding."
}
```

---

### Module 7 — Telemedicine

---

#### `POST /ai/voice/token`
**Role: Patient · Doctor · System**

Generates a LiveKit room access token for telemedicine video/audio consultations.

```json
// Request
{
  "room_name": "consult-dr-sharma-20260617",
  "participant_name": "Rajesh Kumar",
  "identity": "patient-uid-8821"
}

// Response
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "server_url": "wss://livekit.yourdomain.com"
}
```

---

### Module 9 — Unique AI Innovations

---

#### `POST /ai/disease-prediction`
**Role: Patient · Doctor**

AI Disease Prediction Engine — assesses individual risk for Type 2 Diabetes, Hypertension, Cardiovascular Disease, Stroke, and CKD using Indian population risk models (ICMR data).

```json
// Request
{
  "age": 45,
  "gender": "male",
  "family_history": ["Type 2 Diabetes", "Hypertension"],
  "lifestyle": {
    "diet_quality": "poor",
    "physical_activity": "sedentary",
    "smoking": true,
    "alcohol_units_per_week": 8,
    "stress_level": "high",
    "sleep_hours": 5.5
  },
  "biomarkers": {
    "bmi": 29.4,
    "systolic_bp": 142,
    "fasting_glucose_mg": 115,
    "hba1c_percent": 6.1,
    "total_cholesterol_mg": 220,
    "ldl_mg": 145,
    "hdl_mg": 38,
    "triglycerides_mg": 195
  },
  "known_conditions": []
}

// Response
{
  "disease_risks": [
    {
      "disease": "Type 2 Diabetes",
      "risk_level": "high",
      "risk_score": 78,
      "key_risk_factors": ["Family history of diabetes", "Fasting glucose 115 mg/dL (pre-diabetic range)", "Sedentary lifestyle", "BMI 29.4 (overweight)", "Poor diet quality"],
      "prevention_roadmap": ["Reduce refined carbohydrate intake — follow a low-GI Indian diet.", "Walk 30 minutes daily — even light activity reduces diabetes risk by 30%.", "Get HbA1c and fasting glucose tested every 6 months.", "Target weight loss of 5-7% body weight to significantly delay onset."]
    },
    {
      "disease": "Cardiovascular Disease",
      "risk_level": "high",
      "risk_score": 72,
      "key_risk_factors": ["Smoking", "LDL 145 mg/dL (elevated)", "HDL 38 mg/dL (low)", "Hypertension (142 mmHg)", "Triglycerides 195 mg/dL"],
      "prevention_roadmap": ["Stop smoking — single most impactful cardiovascular risk reduction step.", "Consult a physician about statin therapy given LDL and overall risk profile.", "Adopt the DASH diet — proven to reduce BP and lipids.", "Reduce alcohol to under 2 units/day."]
    }
  ],
  "overall_risk_summary": "This patient carries a high combined cardiometabolic risk profile. Multiple modifiable risk factors are present across diabetes and cardiovascular domains. Immediate lifestyle intervention is strongly indicated.",
  "recommended_screenings": ["Fasting glucose + HbA1c (now and every 6 months)", "Lipid profile (now and annually)", "ECG baseline", "Blood pressure monitoring monthly"],
  "disclaimer": "This is a preventive risk assessment, not a clinical diagnosis. Consult a physician before making any health decisions."
}
```

---

#### `POST /ai/recovery/check-in`
**Role: Patient · System**

AI Follow-up Recovery System — daily post-surgical check-in that assesses pain, temperature, medication adherence, and wound status. Escalates to the physician if red flags are detected.

```json
// Request
{
  "surgery_type": "Laparoscopic Appendectomy",
  "days_post_surgery": 3,
  "pain_level": 7,
  "temperature_celsius": 38.8,
  "medication_taken": true,
  "wound_description": "Incision site looks slightly red and there is some yellowish discharge",
  "other_symptoms": "Feeling feverish since this morning",
  "patient_age": 34
}

// Response
{
  "recovery_status": "escalate",
  "escalation_needed": true,
  "patient_instructions": "Aapke symptoms concerning hain. Abhi apne doctor ko call karein ya nearest clinic jayein. Wound ko touch mat karein. Paani se wound saaf mat karein. Prescribed painkillers le sakte hain par fever ke liye doctor ki salah zaroor lein.",
  "physician_daily_report": "POST-OP DAY 3 — Laparoscopic Appendectomy\nPain Score: 7/10 (elevated for post-op day 3)\nTemperature: 38.8°C (febrile — above 38.5°C threshold)\nMedication Adherence: Yes\nWound Assessment: Patient reports erythema and purulent discharge at incision site.\nOther: Patient reports subjective fever since morning.\nCLINICAL ASSESSMENT: Fever + wound discharge on post-op day 3 raises concern for surgical site infection (SSI). Recommend urgent wound review, wound swab for culture, and consideration of empirical antibiotic therapy pending culture results.",
  "red_flag_symptoms": ["Temperature 38.8°C — above 38.5°C escalation threshold", "Purulent (yellowish) wound discharge — possible surgical site infection", "Pain level 7/10 — elevated for post-op day 3"],
  "disclaimer": "This AI recovery assessment is not a substitute for clinical evaluation. Contact your surgeon immediately."
}
```

---

### Module 9.5 — AI Voice Hospital (`agent.py`)

The LiveKit voice agent enables the entire platform to be accessed through natural voice commands — critical for elderly patients, low-literacy populations, and accessibility-first healthcare delivery.

**Capabilities via voice:**
- Describe symptoms and receive triage guidance
- Book or check appointments
- Confirm medicine reminders
- Ask general health questions
- Trigger emergency protocol (108/112 routing)

**Languages supported:** Hindi · English · Hinglish (code-switching)

**Run the agent:**
```bash
python agent.py dev
```

---

## Clinical Safety Guardrails

All endpoints enforce a strict three-layer safety architecture:

1. **Pre-LLM Emergency Filter** — keywords like "chest pain", "stroke", "seizure", "severe bleeding" bypass the LLM entirely and return an immediate emergency response.
2. **System Prompt Restrictions** — all LLM calls are constrained by prompts that prohibit diagnosis, prescribing, dosage recommendations, and treatment plans.
3. **Post-generation Sanitisation** — generated output is scanned and stripped of disallowed clinical claims before returning to the client.

**Roles that are ALWAYS advisory, never authoritative:**
- Prescriptions require doctor approval (`doctor_approval_required: true` always)
- Substitutes require pharmacist + optional physician confirmation
- Disease predictions are prevention roadmaps, not diagnoses
- Insurance analysis is for guidance only — confirm with insurer

---

## Revenue Model Context

| Plan | Price | Scope |
|------|-------|-------|
| Small Clinic | ₹2,999/month | Up to 2 doctors, basic AI features |
| Hospital | ₹15,000/month | Multi-doctor, full AI suite |
| Enterprise | ₹50,000+/month | Multi-branch, custom integrations |
