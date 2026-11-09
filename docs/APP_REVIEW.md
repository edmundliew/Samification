# App Review preparation — 9 November 2026

Status: NOT uploaded or submitted. Reviewer Auth identity was created by the owner and is visible in Supabase (UUID 000feccd-c980-4f58-ba32-fb2dd63233fa). Its scoped clinician grant and fictional sample fixtures were applied after explicit owner approval. The result showed only active clinician access to App Review Ward (fictional only). App Store Connect browser sign-in is confirmed. The owner accepted Apple’s updated Developer Program License Agreement; the pending-agreement notice is no longer shown.

## Dedicated review identity

Prepared login: `app-review@samification.example` (a reserved, non-deliverable dummy identifier, not a mailbox). Password must be unique, entered privately by the owner and provided to Apple only in App Store Connect’s review credentials. Never put passwords or Auth tokens in Git, logs or public metadata. The review account must remain active through review. It has no administrator access.

Applied after owner approval: `supabase/admin/provision-app-review.sql`. Creates an isolated fictional review ward and grants only that ward's clinician role, with an owner-approved audit reason. It seeds one fictional admission, a four-medication confirmed regimen and a practice assignment using existing controlled RPCs. No synthetic completed assessment or clinical eligibility decision is seeded. It required action-time approval and an already-created Auth identity. It must never use a ward containing real patient records.

## Draft reviewer instructions (verify before submission)

1. Open Staff sign-in and use the dedicated review credentials in App Review Information.
2. Open Patients → APPLE-REVIEW-001 · Fictional patient.
3. Inspect the confirmed regimen, assign a challenge, and generate a fresh pairing code.
4. On a second device open Play Samification and enter the code. Codes expire after 15 minutes; generate at review time, never provide an old code in notes.
5. Open the assigned challenge, use the medication reference, tap or drag medication images into time compartments, check the tray, try hints after an error, then share results.
6. Return to the clinician admission to inspect evidence and record a review. The app does not automatically qualify patients for self-administration.
7. For a single-device walkthrough, return to the welcome page and select Try demo. This is explicitly fictional local data and includes clinician/patient previews; it is not an authentication bypass into connected records.

Valid native staff login and Keychain session restoration were observed: the reviewer reached Patients with only the fictional review ward and opened its seeded admission. The optional-display-field decoder mismatch was fixed; 50 core tests pass, including required-field rejection. An iPad patient paired to the fictional admission using a clinician-issued game code, received the four-medicine practice challenge and opened it. Attempt saving, final evidence, clinician result retrieval and upload validation are still being verified. The Mac locked during the test; no completion or upload is claimed. A permanent patient code is not implemented and will not be introduced by weakening pairing expiry.

## Current release findings

- First Native Release archive attempt failed at CodeSign with `errSecInternalComponent`. A later Xcode retry succeeded: Organizer shows an arm64 iOS App Archive, version 0.2.0 (2), identifier com.edmundliew.samification, team Yong Hock Liew. App Store validation is in progress; archive creation alone does not prove upload readiness.
- App Store Connect app record is Samification, Apple ID 6832386816, bundle com.edmundliew.samification. The exact bundle ID is already registered under team 3T3328WVBE. Searching the Apps list by name located the record. Private reviewer sign-in fields and instructions were saved in App Review Information; no password is stored in this repository.
- Archive 0.2.0 (2) failed Apple validation for missing iPhone/iPad app icons and CFBundleIconName. Added an original opaque 1024px tray icon and AppIcon asset-catalog build setting. Archive (3) exists but predates the latest wording/decoder fix. Current source is 0.2.0 build 4 and needs a fresh archive/validation. Added UserDefaults reason CA92.1 privacy manifest and ITSAppUsesNonExemptEncryption=false: app uses Apple URLSession HTTPS/Keychain only, no custom crypto dependencies. Public listing privacy/support URLs, disclosures, screenshots, review contact details, age rating and account-deletion support remain incomplete. TestFlight upload and internal testing take priority before public submission.
- Owner's earlier email link returned otp_expired. The separate review account must prove valid password login and secure session restoration independently.

## Current checkpoint and next action

App Review Information was saved in App Store Connect under Apple app ID 6832386816. Reload shows nonempty protected reviewer credential fields and version 0.2.0. The username and password are intentionally excluded from this repository's notes beyond the non-secret reviewer email. Use Apple’s private sign-in fields, never public metadata, to supply the password.

Current source build: **0.2.0 (4)**. Xcode successfully ran the corrected decoder on iPhone and built/installed on iPad. Native iPhone restored the signed-in clinician session, loaded its one review admission and current regimen, and issued a patient pairing code. Native iPad joined that admission, received its practice assignment and opened the medication game. Debugger startup stalled during installation; direct app launch after installation worked. Build 4 Archive was started and reached 65/71 steps before the Mac locked; its final archive/validation status must be checked after unlock.

All **50 Swift core tests passed**. New tests verify backend snapshots can omit display/provenance fields without weakening mandatory answer-key fields. Dose, strength, periods, identity, inclusion and confirmation remain mandatory; malformed supplied display fields still fail decoding. The 1024px original icon was visually inspected and verified opaque. Both plist files and the generated Xcode project passed plist validation. No distribution upload, TestFlight release or public review submission has been verified.

Next: unlock Mac; finish native patient submission/share and clinician evidence check; archive/validate current build 4; upload to App Store Connect; wait for processing; enable internal TestFlight for the account owner. Complete public listing/privacy/review requirements before any public App Store submission. Keep App Store review credentials private and keep reviewer access confined to fictional records.
