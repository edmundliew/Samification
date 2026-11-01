# Core workflow checkpoint — 1 November 2026

## Native app

- Patient selection and adding fictional patients. Each case has its own draft, regimen history, challenges and reviews; no patient names or other identifiers are needed for the demo.
- CSV imports retain the original text. Clinicians can change the display name while preserving the original source name. Confirming appends an immutable version; pending older challenges for that patient are superseded and completed evidence stays unchanged.
- Assignments use the confirmed snapshot. Prior exposure is calculated for that patient and regimen at challenge start.
- Atomic local saves retain the working tray, first attempt, all retries, hints, events, shared status and clinician rationale. iOS writes use complete file protection. Restore validates patient/regimen references and recomputes saved scores. This is local fictional demo storage, not an authenticated clinical audit database.
- Corrupt or unsupported saved files are preserved instead of being replaced silently. A visible persistence error identifies unsaved work. An explicit Help action archives the old workspace before restarting the demo.
- Catalogue browsing shows the four supplied package references and strength, separate from prescription dose/frequency. Images remain unverified demo assets.
- Shared assignments link directly to clinician evidence review. Help explains the saved multi-patient workflow.

## Connected backend preparation

Migration `202611010002_clinical_workflow.sql` is **prepared, not deployed**. It creates admissions, immutable regimen versions with original CSV, assignments and clinical audit events. Narrow RPCs validate confirmed whole-tablet daily regimens, serialize version creation, deduplicate identical assignment requests, supersede pending assignments and close admissions on discharge. Patients have no clinical-table access yet; pairing requires a later migration. Administrators have no implicit clinical access.

The Swift API client encodes the confirmed medication snapshot and original source, and keeps assignment identity stable on retries. Clinical screens still use the saved local workflow. Connecting the clinician UI to authenticated backend records, pairing patients, independently scoring evidence on the server, clinician result delivery and catalogue administration remain subsequent work.

## Verification

- Full Xcode Swift Package run: **23 tests, zero failures**.
- PostgreSQL staff access suite: **26 checks passed**.
- PostgreSQL clinical workflow suite: **43 checks passed**, including wrong-ward reads/writes, anonymous denial, administrator separation, suspension, invalid medication payloads, duplicate assignments, retained historical CSV, superseding and discharge.
- Native iPhone 17e / iOS 27.2 build and launch succeeded. Confirmed patient-one assignment, separate empty patient-two list, stop/relaunch retaining selected patient, and restoration of the same patient-one assignment UUID. Exercised incorrect submission, hint, sharing and clinician assignment status “Results received”.
- Project generation, SwiftUI syntax parse and project plist validation pass.
- Complete correct-answer UI walkthrough, final clinician review entry, iPad/touch/drag testing and TestFlight signing are not yet complete. Automated core tests cover correct submissions and saved reviews.

No email service, paid plan, administrator grant or remote clinical migration was changed for this checkpoint. The existing deployed staff-access migration remains unchanged.

## Later connected UI checkpoint

Connected clinician and patient screens have since been added. The 23/69 totals above describe this earlier checkpoint. See `docs/CONNECTED_WORKFLOW.md` for current 28 Swift tests, 112 PostgreSQL checks, pairing behavior and live activation limits.
