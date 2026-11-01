# Samification

Medication tray assessment prototype for iPhone and iPad. Bundle identifier: `com.edmundliew.samification`.

## v0.1.0 — offline SwiftUI foundation

Includes clinician medication review/CSV import, versioned assignments, patient tap/drag tray game, package photos, red/green feedback, hints, immutable submissions, clinician results, review records, audit events, Help, and a simulated administrator approval preview. Four fictional medications are preconfirmed on launch.

This is a source preview, not a clinically validated or signed distribution. Authentication, Supabase access policies, cross-device delivery, notifications and durable audit storage are planned in v0.2–v0.5. Role switching is explicitly a local demo control. No Supabase network requests or credentials are used in v0.1. Closing the app clears session data.

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

## Staff access development checkpoint

The Account tab and Supabase staff-access migration are in development for v0.2. The stable v0.1.0 tag remains the offline preview. This checkpoint has 12 passing Swift tests and 26 isolated PostgreSQL checks; remote migration, Auth configuration and updated native UI verification remain pending. See [staff access setup and validation](docs/STAFF_ACCESS.md).
