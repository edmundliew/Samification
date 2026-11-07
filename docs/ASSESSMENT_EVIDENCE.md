# Connected assessment evidence — 7 November 2026

Implementation is on `development/v0.2-staff-access`. Migration 004 was applied to the live Supabase project on 7 November 2026 following explicit approval; all seven live deployment checks passed. This is a development build, not a TestFlight release or clinically validated assessment.

## Patient workflow

Join an admission using its clinician-issued code, expand an assigned regimen and open the medication challenge. Start is saved before submissions. Tap pills into the selected compartment or drag into any compartment; tap tray pills to remove them. Clear all changes the working tray. Check sends only medication IDs, compartment counts, a request ID and the expected action sequence. It sends no client-generated score.

The server evaluates the immutable regimen linked to that assignment. Incorrect feedback is red; correct feedback is green. A hint is available only after an incorrect submission. Opening a reference and requesting a hint are recorded server actions. Finish requires the same canonical tray as the last submission and locks further actions. Incorrect final trays may be finished so clinicians can review unsuccessful attempts too.

## Three evidence categories

1. **Dose accuracy:** expected medication/period administrations with exactly the prescribed whole-tablet quantity, divided by all expected administrations.
2. **Schedule accuracy:** expected medication/period administrations containing at least one tablet, divided by all expected administrations. Extra placements in other compartments are separately counted and prevent an exact match even if both percentages reach 100%.
3. **Assistance and retries:** first-attempt correctness; submissions; retries (`max(0, submissions − 1)`); first correct attempt or none; hint and reference requests before each submission; earlier started challenges for the same admission/regimen, including practice.

Each submission retains its full tray, integer score numerators and denominators, omissions, extra/missing tablets, unexpected placements, individual discrepancies and rules identifier `TRAY-0.1-PROPOSED`. Percentages are presentation values computed from those saved integers. No composite competency score or automatic eligibility decision is produced.

An attempt is a server-accepted submission, not a tablet tap. Retry count includes every subsequent accepted submission, even after a correct attempt. Earlier exposure means an earlier challenge was started; it does not prove content was seen. The existing JSON field `feedbackBefore` counts **prior accepted submissions**, not confirmed feedback views. Hint/reference events count accepted requests; delivery, reading, understanding, physical tablet handling and actual adherence are not established. Food directions are displayed, not scored.

## Audit and access

- `challenge_runs` binds the assignment, admission and paired patient identity, with server start/finish times and prior-exposure flag.
- `challenge_actions` is append-only for application roles. Every accepted action stores request UUID, sequence, authenticated actor, server timestamp, kind, payload and server result.
- `challenge_reviews` records clinician-authored decisions and notes separately from evidence. Available decisions are education required, supervised assessment and reviewed. None grants self-administration permission.
- Application roles cannot insert, update or delete these tables directly. Scoped approved clinicians can read evidence for admissions in their ward; administrator status alone grants no evidence access.
- Patients use narrow action/history RPCs. Every call checks current anonymous pairing, admission/scope activity and ownership. Superseded or completed challenges reject new actions. A re-paired identity cannot take over another identity's started challenge; the clinician must assign a fresh challenge.
- Identical request IDs return the original result. Changed reuse fails. Expected previous sequence rejects stale requests and protects against duplicate submissions after reconnection. Admission-first locking serializes competing actions, supersession and discharge.
- A network-uncertain action freezes editing until the same request is retried. Definitive rejection requires refresh. Pending actions live in memory; after termination the app reloads server history and restores the last submitted tray. Unsubmitted edits are not retained. Patient credentials remain in memory and expire; durable Keychain session restoration is pending.
- Recorded server timestamps show request acceptance order, not time spent thinking or reading. No speed-based competency score is used.

## Clinician workflow

Admission → Review challenge evidence → choose a started challenge. The screen shows practice/assessment, the three categories, full submission history, individual discrepancies and an audit timeline. Historical medication names come from the regimen assigned to that challenge. Completed challenges accept separately attributed reviews; existing reviews cannot be edited by application roles.

## Validation and rollout

- 32 Swift tests, including canonical wire encoding, retry identity preservation and six independently specified scoring fixtures.
- 225 disposable PostgreSQL checks: 26 staff access + 53 clinical workflow + 33 pairing + 113 evidence/scoring. They exercise patient/staff boundaries, malformed trays, duplicate/changed/stale requests, hint gating, incorrect completion, immutable records, revocation, supersession and shared Swift/PostgreSQL scoring fixtures.
- Native iPhone simulator build succeeds in Xcode. Command-line native compilation remains restricted by the host macro sandbox; core Swift tests run successfully.
- Migration 004 is now deployed. Existing 001–003 are already deployed; do not reapply them. No first administrator, staff clinical scope or real patient records are provisioned by 004.
- Still required: live valid paired clinician/patient walkthrough, iPad/device interaction and accessibility validation, signing and TestFlight. Email sender configuration remains deferred.
