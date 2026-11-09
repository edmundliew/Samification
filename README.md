# Samification

SwiftUI iPhone/iPad medication assessment app with Supabase-backed clinician and patient workflows. Development checkpoint, 8 November 2026; use fictional data only.

The app opens with **Play Samification**, **Staff sign-in**, and a separate **Try demo** entry. Patients see pairing and assigned challenges only. Approved clinicians enter the Patients workspace; medication review, assignments, pairing, evidence and reviews are grouped by admission. Mobile administrator controls have been removed. The separate administrator portal is in `web/admin`; it is prepared locally and not yet deployed to Cloudflare.

Staff email/password sign-in and secure session restoration are implemented. First-time email verification/password setup remains unresolved for the owner's test account: the supplied link returned `otp_expired`. The dedicated fictional reviewer login, staff restoration, patient pairing/challenge completion and clinician evidence retrieval have now been verified. Patient/staff token renewal is implemented with same-identity checks; 56 core tests pass. The owner already has administrator and clinician access scoped to the fictional test ward. Backend migrations for staff access, clinical workflow, patient pairing and assessment evidence are deployed.

The isolated demo retains CSV review, four preconfirmed fictional medicines, clinician/patient previews, the visual tray game and results. Role previews never authorize connected access. See [workspace design and validation](docs/WORKSPACES.md), [validation](docs/VALIDATION.md), and [portal setup](web/admin/README.md). Build 0.2.0 (6) passed Apple validation and is **Testing** in the **Samification Internal** TestFlight group. Public App Store submission has not occurred.

The next build, 0.2.0 (8), adds a shared step-by-step tester Help guide before sign-in and in the patient and clinician workspaces. The guide has been verified in the iPad simulator; TestFlight upload remains pending and the live build is still 6.

## Open and run

1. Install full Xcode with an iOS SDK (Xcode 15 or newer; latest compatible stable version preferred).
2. Open `Samification.xcodeproj`. Select the **Samification** scheme.
3. Select an iPhone or iPad simulator and run. No developer team is needed for simulator builds.
4. For a device, set your Apple development team in Signing & Capabilities. Bundle ID availability and App Store registration are not yet verified.

Use Try demo to assign a fictional challenge, preview Patient, play and share, then return to Clinician → Results. Exit demo to use the real pairing or staff entry. Administrator access is managed in the separate web portal.

## Verification

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

The explicit developer directory uses full Xcode even if the system still selects Command Line Tools. See `docs/VALIDATION.md` for the latest verification record. For command-line installations without XCTest:

```sh
swiftc Sources/SamificationCore/*.swift scripts/VerifyCore.swift -o /tmp/samification-check
/tmp/samification-check
```

Unsigned simulator build after installing Xcode:

```sh
xcodebuild -project Samification.xcodeproj -scheme Samification \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Structure

- `App/`: SwiftUI screens and bundled demo photos.
- `Sources/SamificationCore/`: value models, scoring rules, evidence lifecycle and CSV importer (also compiled directly into the app target).
- `Tests/`: XCTest coverage of clinically significant assessment edge cases.
- `docs/`: requirements, release notes, and backend boundaries.
- `Config/`: local configuration example. Real secrets and signing files are ignored.

Package photos were supplied by the project owner for the demo. They are not verified product-identification images or licensed catalogue assets. They only appear with the demo product's original strength. Imported products use labelled pill icons until a verified catalogue is implemented.

## Backend checkpoints

Twenty-eight Swift tests and 112 isolated PostgreSQL checks pass (26 staff access + 53 clinical workflow + 33 patient pairing). The staff migration's five live schema/grant checks also passed. See [staff access](docs/STAFF_ACCESS.md), [deployment record](docs/BACKEND_DEPLOYMENT.md) and [current workflow](docs/CORE_WORKFLOW.md). Email sender configuration is a backend setting, independent of role approval and the recipient’s email domain; see [email configuration boundary](docs/EMAIL_CONFIGURATION.md).

See [connected workflow and pairing validation](docs/CONNECTED_WORKFLOW.md) for the latest development checkpoint.

### Connected assessment development

The development branch now includes server-scored patient challenges, immutable submission history and scoped clinician reviews. See [assessment evidence](docs/ASSESSMENT_EVIDENCE.md). Migration 004 is deployed and its seven live checks passed. Build 0.2.0 (6) is released to internal TestFlight.
