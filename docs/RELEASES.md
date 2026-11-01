# Releases

## v0.1.0 — SwiftUI source preview

- Universal iPhone/iPad SwiftUI target, iOS 17 minimum.
- Three explicitly simulated role previews.
- Four preconfirmed fictional medications with supplied package images.
- CSV review preserves source name and instructions; edits require reconfirmation.
- Tap/drag into four pictogram compartments; tap removal and Clear all preserve assessment history.
- Three evidence categories, full submission history and separate clinical review.
- Help walkthrough and audit inspector.

Validation on the authoring Mac: core compiles and standalone behavioural verification passes; SwiftUI source syntax parsed and project structure checked. Full Xcode is absent, so iOS type checking, simulator build, UI layout/touch checks, XCTest execution, device signing and TestFlight upload remain pending. Do not describe this as a tested iOS binary.

Additional check: the SwiftUI sources typechecked against the macOS 14+ SDK after omitting only the iOS-specific keyboard-type and navigation-title-display modifiers in a disposable copy. This does not verify those modifiers or the iOS target. The XCTest test target could not run because the command-line tools do not provide XCTest. Local verification covers the same key assessment lifecycle with a standalone Swift executable.

GitHub write access was restored by adding this repository to the connector installation. Source publication is supported; iOS simulator/device validation remains pending.

Known limits: session-only demo; no connected Supabase, secure administrator bootstrap, patient pairing, central results collection or production audit. Clinical scoring rules are proposed. The reference card is available during assessment; this is an open-reference task. Food instructions and exact time intervals are not scored.

Every subsequent release must record its changes, validation, limitations and commit/tag. TestFlight and App Store submission are separate from source release.
