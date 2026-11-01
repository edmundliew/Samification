# Xcode validation — 1 November 2026

Source: v0.1.0, commit `016bf0e41863b9b1450dceea6a4598a0c83dbf6e`.

## Installed and verified

- Installed Apple Xcode 27.2 (27B52) through the Mac App Store.
- Completed first-run system component setup and installed iOS 27.2 platform support and simulator runtime.
- Opened `Samification.xcodeproj` in Xcode.
- Native Xcode iOS build succeeded. Device-SDK compile verification temporarily disabled code signing in Debug; the temporary setting was removed afterward. No distribution signing configuration was changed.
- Built and launched the app on the iPhone 17e / iOS 27.2 simulator.
- Swift Package XCTest suite ran with the full Xcode toolchain: **8 tests, 0 failures**.
- Observed clinician assignment, patient inbox navigation, medication game launch and all four supplied package images.
- Exercised pill addition, incorrect submission feedback, hint count increment, and Clear all. After clearing, the original submission and hint count remained recorded, and sharing was disabled until the updated tray was checked again.

## Pending

- Complete corrected-tray-to-results UI walkthrough: simulator automation timed out before completion.
- Visual and touch testing on an iPad simulator, drag/drop gestures, accessibility and larger text sizes.
- Real-device signing, Apple Developer team selection, provisioning, TestFlight and App Store submission.
- Connected Supabase authentication, patient pairing, server scoring and production access control.

The iPhone launch is a smoke check, not complete clinical or UI validation. Earlier limitations in `docs/RELEASES.md` describe the state at initial publication; this dated record supersedes the missing-Xcode and unexecuted-XCTest limitations only.

## Toolchain selection

The system developer directory may still point to Command Line Tools. Commands can use full Xcode without changing that global setting:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun swift test
```

Command-line iOS compilation in the agent execution sandbox could not launch nested compiler macro helpers (`sandbox_apply: Operation not permitted`). Building in the Xcode application succeeded. Simulator control from that sandbox also could not connect reliably to the simulator service; native Device Hub was used for the recorded smoke check.
