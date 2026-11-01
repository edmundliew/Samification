# Agreed implementation scope

1. v0.1: offline SwiftUI foundation, matching the reviewed HTML workflow.
2. v0.2: Supabase Auth, protected role memberships, staff access requests/approval/revocation, admission-scoped patient pairing.
3. v0.3: persisted medication catalogue, product strengths and verified image references; source-preserving CSV review, regimen versions and clinician assignments.
4. v0.4: backend scoring from submitted evidence, versioned rules and clinician reports/review.
5. v0.5: revocation/expiry/discharge, network interruption recovery and deduplication, accessibility, security testing and TestFlight preparation.
6. v1.0: pilot evaluation, clinical validation, product revisions and App Store preparation.

## Connected backend boundaries

Project URL: `https://vqexfcvzoryocjnzjozv.supabase.co`. Initial administrator identity is provided privately during secure provisioning, not seeded in a public repository. Publishable keys identify the backend; they do not authorise database migrations or initial admin grants. Never put a database password, secret/service-role key, signing certificate or patient data into GitHub.

Planned records: staff memberships and scopes; access requests; admissions; single-use expiring device pairing tokens; catalogue medications/products/images; original imports; confirmed regimen versions; assignments; immutable attempt snapshots; hints/feedback events; backend score records; clinician reviews; append-only audit events. Drug dose/frequency belongs to the patient's prescription, not the catalogue drug.

Enforce row-level policies for each record type. Patients see only their paired admission. Clinicians see assigned care scopes. User administration does not automatically grant clinical record access. Backend authorises role changes, assignment creation and scoring, checks membership revocation at operation time, and prevents client score forgery. Bootstrap the first administrator through an authorised Supabase administrative session.

Clinical pilot decisions still needed: approved drug/formulation scope; validated scoring protocol/thresholds; participating wards; data retention/location; image provenance/rights and product verification. The game never automatically qualifies a patient for self-administration.
