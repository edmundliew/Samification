# App Review and TestFlight — 9 November 2026

## Current release

**Samification 0.2.0 (6)** passed Apple validation and Xcode confirmed **App upload complete**. App Store Connect confirms **Testing** in **Samification Internal** (1 tester, 1 build). The owner account is the internal tester. Public App Store submission has not occurred.

Apple app ID: `6832386816`. Bundle: `com.edmundliew.samification`. Team: `3T3328WVBE` (Yong Hock Liew). The owner accepted the updated Developer Program License Agreement. The private App Review Information username/password fields and patient/clinician review notes were saved. No passwords or session tokens are stored in this repository.

## Review account and data

Dedicated login: `app-review@samification.example`, an owner-created dummy identity without a mailbox. Its password belongs only in Apple's private review credentials. It has active clinician access only to **App Review Ward (fictional only)** and no administrator access, following explicit owner approval recorded in the access audit.

Fictional admission: **APPLE-REVIEW-001**. Regimen v2 retains the same four fictional medication examples. The earlier v1 pending challenge was superseded through the controlled confirmation API; evidence was preserved. A v2 practice challenge was completed in native testing. Reviewers can assign a fresh challenge from the clinician admission before issuing a new patient game code.

## Verified workflow

- Native clinician login/session restoration, fictional ward/admission/regimen access and game-code issuance.
- Native iPad pairing and four-medication challenge delivery.
- Incorrect first tray saved; one hint requested; correct second tray saved; Finish & share locked the challenge.
- Native clinician evidence matched: first attempt incorrect, submissions 2, retries 1, first correct attempt 2, hints 1. Attempt 2 had dose 4/4 and schedule 4/4, with zero unexpected placements/omissions. Audit showed start → submit → hint → submit → finish.
- **56 core tests pass**, including optional medication display-field compatibility, mandatory answer-key rejection, expiry policy, coalesced renewal, same-identity enforcement, invalid-refresh rejection and invalidation during renewal.
- Original opaque 1024px tray icon, AppIcon build configuration, UserDefaults privacy reason CA92.1, and OS-only encryption declaration were included in the validated build.

Native patient workflow was exercised on build 5; build 6 additionally includes clinician preflight renewal and the shared equivalent expiry policy. Build 6 was archived, Apple-validated and uploaded. Real-device installation through TestFlight is the next verification.

## Session behavior and limits

Patient Auth credentials remain memory-only. Renewal preserves the same anonymous identity; it does not extend or bypass admission pairing expiry/revocation. Each protected request remains server-authorized. Patient requests retry one Auth-expiry response using the same pending action identifier. Staff actions renew ahead of expiry; unexpected Auth expiry renews sign-in and asks the user to retry, rather than replaying an entire clinical workflow automatically.

During a long test a patient session reported expired sign-in, and a server-only submission reproduced successfully inside a rolled-back transaction. The exact cause of the earlier generic rejected action was not captured conclusively. No scoring or authorization checks were relaxed.

Cold restart of the patient app still requires clinician re-pairing; a previously started challenge remains bound to its original temporary identity. Physical-device drag gestures, larger text/VoiceOver and native saving of a separate clinical review remain items for beta testing. Public listing support/privacy URLs, disclosures, screenshots, review contact details, age rating and deletion/retention procedures remain incomplete and must be resolved before public App Store review.
