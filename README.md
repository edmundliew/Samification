# Samification

Medication tray assessment prototype for iPhone and iPad. Bundle identifier: `com.edmundliew.samification`.

## Current development build

The clinician workflow now supports multiple fictional patients with separate CSV drafts, immutable confirmed regimen versions, assignments, tray evidence and reviews. The workspace is saved locally and restored after app restart. The four demo medications are preconfirmed for each new fictional patient. Product references and photos can be browsed separately from patient prescriptions.

The Account screen and staff-access Supabase migration are present. The staff migration is deployed; email setup and initial administrator provisioning are deferred. Connected clinician screens now call the admissions, regimen confirmation and assignment API. Clinician pairing and patient Join screens are implemented, with a temporary patient identity and restricted medication-reference inbox. The clinical and pairing migrations are **deployed**, and temporary patient Auth sign-in is enabled. Six live schema/grant checks and 13 unpaired Auth/API checks pass. Initial staff provisioning, valid paired cross-device validation and server-scored game submissions remain pending. Role switching still controls only fictional local previews.

This is a development source checkpoint, not a clinically validated or signed distribution. Use fictional data only. The stable `v0.1.0` tag retains the original session-only preview. See [current workflow validation](docs/CORE_WORKFLOW.md) and [release history](docs/RELEASES.md).

## Open and run

1. Install full Xcode with an iOS SDK (Xcode 15 or newer; latest compatible stable version preferred).
2. Open `Samification.xcodeproj`. Select the **Samification** scheme.
3. Select an iPhone or iPad simulator and run. No developer team is needed for simulator builds.
4. For a device, set your Apple development team in Signing & Capabilities. Bundle ID availability and App Store registration are not yet verified.

Use the Clinician preview to assign a challenge, switch to Patient, play and share, then switch back to Clinician → Results. Help documents the full workflow. Administrator actions are fictional local changes.

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

The development branch now includes server-scored patient challenges, immutable submission history and scoped clinician reviews. See [assessment evidence](docs/ASSESSMENT_EVIDENCE.md). Migration 004 is deployed and its seven live checks passed; this is not yet a TestFlight release.
