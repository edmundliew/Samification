# Connected workflow and pairing — 1 November 2026

## Implemented in source

Approved clinicians can enter the connected workspace through Account. They can list scoped admissions, create a fictional admission, import CSV, review/edit medication display names, confirm an immutable regimen version, inspect history and assign practice/assessment challenges. Each admission detail owns its own working draft.

Admissions, confirmations and assignments carry request identities. In-memory retries reuse the original request ID and payload. Database functions return the existing matching record and reject collisions with changed data. Pending admission and confirmation edits are frozen while a potentially successful request is being retried. Pending operations are not yet a durable outbox across app termination or navigation; that recovery remains required before a pilot.

Clinicians can issue an admission pairing code, display its QR and copy it with a local-only clipboard item expiring after 15 minutes. They can inspect and revoke patient sessions. Patients can use Join to paste a code, create a separate temporary anonymous Auth identity, claim an admission and read their assigned medication references. No email is required for this patient flow. Ending a patient session revokes its database binding before local sign-out. Tokens are held only in memory in this development build.

## Backend boundary

- Migration 001 staff access is already deployed.
- Migrations 002 clinical workflow and 003 patient pairing were **deployed on 1 November 2026**, together in one atomic transaction after explicit owner approval.
- Anonymous sign-ins are enabled after explicit approval. A live API smoke test created one unpaired temporary identity, passed 13 access checks and signed that session out. Auth rate-limit/bot-protection configuration and cleanup of anonymous identities still need review before external testing.
- No administrator membership or clinician scope is seeded by these migrations. Registration or domain verification never grants a role.
- Patient tokens are random UUIDs, stored as SHA-256 hashes, single-use, expire after 15 minutes and require an active scoped issuer. New codes revoke unused older ones. Claims are serialized with admission/token locks; same-user retries return the same active session.
- Patient sessions expire after 24 hours or become unusable on clinician revocation, patient ending, ward deactivation or admission discharge. One temporary identity cannot switch admissions.
- Patients cannot SELECT raw admissions/regimen/import tables. A restricted inbox RPC returns only assigned medication reference fields, excluding original CSV, original source names and raw order details. Other patients and ward scopes stay inaccessible.
- Staff and patient tokens are separate. Patient anonymous identities cannot request staff access, issue pairing codes or revoke another session.

Pairing currently supports QR display and manual paste. In-app camera scanning, Keychain session restoration/refresh, remote game submissions, independent server scoring, central result delivery/review and complete recovery/revocation UI testing remain pending. The local tray game remains usable separately. There is no automatic competency qualification.

## Validation

- **28 Swift tests, zero failures**, including anonymous sign-in payload, pairing-code validation/normalisation, safe patient inbox decoding, shared regimen validation and request-ID retries.
- **26 staff-access PostgreSQL checks**, **53 clinical-workflow checks**, **33 patient-pairing checks**: **112 total** in isolated PGlite 0.5.14 using mocked Supabase identity claims.
- Pairing checks cover replaced/invalid/expired/claimed codes, same-user retry, other-patient isolation, administrator/wrong-ward denial, blocked raw-token/import reads, no email/staff privilege promotion, single-admission binding, clinician revocation, admission closure and patient-initiated session ending.
- Native Xcode build and launch succeeded on iPhone 17e / iOS 27.2. Verified Join form renders and Connect remains disabled without a valid code. Authenticated clinician screens compile but have not been walked through against a live provisioned account.
- These are development checks, not production Auth, clinical or full UI validation. The sender/provider settings remain backend configuration and email setup remains deferred.

## Live activation verification

The prepared SQL bundle matched SHA-256 `9bd15fc2eca532eb207b25bdf6f05a05ea2dd62083f620f75579097d864d1e60` before execution; copying the editor contents back confirmed an exact match. Execution returned success. Six live schema/grant checks passed: nine public tables with RLS; no direct client writes; nine clinical/pairing RPCs protected from unauthenticated execution; private pairing hashes inaccessible; no staff memberships seeded; no clinical admissions seeded.

Thirteen live API checks passed using the real Auth gateway and an unpaired temporary identity. These verified anonymous sign-in, empty access to six protected tables, an empty patient inbox, denial of clinician access requests/admission creation/pairing issuance, rejection of an unknown pairing code, and safe ending of an unpaired session. The temporary Auth session was signed out; its unbound Auth user record remains for normal future cleanup. No patient admission, medication order or staff privilege was created. Tokens were kept only in process memory and were not logged or committed.

End-to-end valid pairing and clinician operations remain untested against live provisioned staff. Initial administrator/clinician provisioning and scopes remain pending, along with the separately deferred staff email delivery setup. This activation does not implement remote assessment submissions or server scoring.
