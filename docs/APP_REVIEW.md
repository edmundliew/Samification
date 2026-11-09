# App Review preparation — 9 November 2026

Status: NOT uploaded or submitted. Reviewer Auth account creation is awaiting the owner's private password entry in the prepared Supabase form. App Store Connect browser sign-in is also awaiting the owner.

## Dedicated review identity

Prepared login: `app-review@samification.example` (a reserved, non-deliverable dummy identifier, not a mailbox). Password must be unique, entered privately by the owner and provided to Apple only in App Store Connect’s review credentials. Never put passwords or Auth tokens in Git, logs or public metadata. The review account must remain active through review. It has no administrator access.

Prepared, not executed: `supabase/admin/provision-app-review.sql`. Creates an isolated fictional review ward and grants only that ward's clinician role, with an owner-approved audit reason. It seeds one fictional admission, a four-medication confirmed regimen and a practice assignment using existing controlled RPCs. No synthetic completed assessment or clinical eligibility decision is seeded. Running it requires action-time approval and an already-created Auth identity. It must never use a ward containing real patient records.

## Draft reviewer instructions (verify before submission)

1. Open Staff sign-in and use the dedicated review credentials in App Review Information.
2. Open Patients → APPLE-REVIEW-001 · Fictional patient.
3. Inspect the confirmed regimen, assign a challenge, and generate a fresh pairing code.
4. On a second device open Join my care and enter the code. Codes expire after 15 minutes; generate at review time, never provide an old code in notes.
5. Open the assigned challenge, use the medication reference, tap or drag medication images into time compartments, check the tray, try hints after an error, then share results.
6. Return to the clinician admission to inspect evidence and record a review. The app does not automatically qualify patients for self-administration.
7. For a single-device walkthrough, return to the welcome page and select Try demo. This is explicitly fictional local data and includes clinician/patient previews; it is not an authentication bypass into connected records.

The connected two-device flow and valid native login must pass before these instructions are submitted as verified. A permanent patient code is not implemented and will not be introduced by weakening pairing expiry.

## Current release findings

- Native Release archive reached CodeSign, then failed with `errSecInternalComponent` after a long signing delay. It did not produce a verified uploadable archive. Investigate Keychain authorization; do not change certificate trust or disable signing to bypass it.
- App Store Connect opened at Apple sign-in; no app record inspected or created yet.
- App icon and privacy manifest are not present yet. Distribution validation, privacy/support URLs, privacy disclosures, screenshots, review contact details, age rating, account-deletion support and export-compliance answers still need completion and verification.
- Owner's earlier email link returned otp_expired. The separate review account must prove valid password login and secure session restoration independently.
