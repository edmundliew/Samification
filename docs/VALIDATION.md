# Uploaded beta checkpoint — 9 November 2026

**56 core tests passed. Build 0.2.0 (6) passed Apple validation and uploaded successfully.** The connected native patient/clinician evidence test passed with the isolated fictional ward: wrong attempt → hint → correct retry → finish, followed by matching clinician counts and audit history. App Store Connect confirms build 0.2.0 (6) is **Testing** in **Samification Internal**, with one tester and one build. See [APP_REVIEW.md](APP_REVIEW.md) for exact build/test scope and remaining limits. Earlier checkpoints below are historical.

# Release preparation — 9 November 2026

**50 core tests pass.** Fixed native decoding of backend-confirmed medication snapshots that omit optional display/provenance fields; answer-key fields remain required and malformed fields are rejected. Native clinician sign-in/session restoration, admission/regimen loading, patient-code issuance, iPad pairing and challenge delivery were observed with the isolated fictional reviewer ward. Full patient submission/clinician results and final archive validation remain pending. See [APP_REVIEW.md](APP_REVIEW.md) for the release checkpoint. Mac lock interrupted UI checks; no upload or TestFlight release is claimed.

# Separate workspace checkpoint — 8 November 2026

The current entry/navigation validation is recorded in [WORKSPACES.md](WORKSPACES.md). Native Xcode build/launch and welcome → patient/staff/demo paths passed on iPhone 17e. All 48 core tests and five mocked admin portal tests pass. The portal is local-only; valid native/portal sign-in, automatic approved-clinician routing and Cloudflare deployment remain unverified. No role grants or production clinical changes were made.

The records below describe earlier checkpoints; the former initial Account tab and mobile administrator controls have been replaced.

# Simplified staff authentication — 8 November 2026

Implemented standard email/password sign-in as the primary Account screen and initial app tab. First-time account/password setup and recovery are in a collapsed secondary flow. Added authenticated password updates, device-only Keychain session persistence, refresh-token renewal, user-ID matching on restore, foreground/periodic refresh and local credential clearing on sign-out or invalid session. Roles remain server-authorized.

**48 core tests passed**, including five new checks for password grants without email/role fields, refresh grants and rotated-token decoding, authenticated password updates with minimum length, safe Auth error classification and local rejection of empty credentials. Native Xcode build/launch succeeded on iPhone 17e. Observed the simple email/password form with disabled empty submission. Submitted deliberately fictional credentials to the live Auth endpoint; the app cleared the password field and displayed the expected incorrect-credentials message. No real password or session credential was read, logged or committed. A fresh one-time verification email request for the owner was accepted by Supabase; its delivery and the credential step remain pending. No security settings, roles or production email configuration were changed.

Successful live sign-in, Keychain save/rotation/restoration, sign-out and the complete connected clinician/patient UI journey remain unverified until the owner completes password setup. SMTP and direct email-to-app redirects remain unresolved for onboarding/recovery. The final keyboard-submit/help-copy adjustments were source-checked after the running native build.

---

# Two-column tablets within each compartment — 8 November 2026

Kept the four time compartments across one row. Within each compartment, both games now use exactly two flexible tablet columns, so four tablets form a 2×2 group and additional tablets continue into further two-column rows. Compact lettered pill badges fit the narrow iPhone compartments. Their removal buttons retain a 44-point minimum height and full cell hit area. Medication names remain in accessibility labels; incorrect badges retain red styling. No tablet count is hidden or capped by this layout.

Xcode built and launched the changed views on iPhone 17e / iOS 27.2. Verified an existing five-tablet tray flowed into two columns, tapped one tablet to remove it and visually confirmed the remaining four formed a 2×2 group. Source parsing and whitespace checks passed. The connected view shares this grid configuration but was not tested with live authentication. Larger accessibility fonts, iPad and smaller iPhones still need visual checks. Scoring and transport are unchanged.

---

# Shared tray action row — 8 November 2026

Both local and connected games use the same action row: a smaller Clear all button on the left and Check my daily tray centred on the page. Equal side widths preserve the primary action’s centre alignment. Existing disabled states and clear/submit handlers are retained; clearing does not reset assessment history. Only layout and shared UI composition changed. Source parsing and whitespace checks passed. Xcode built and launched the changed views on iPhone 17e; the final portrait preview confirmed a one-line Clear all label on the left and a centred Check button on the same row. Tapping Clear all emptied the working tray, left submissions/hints at zero and disabled Clear all while empty. Larger text and smaller screen widths still need visual checks.

---

# Medication image interaction and focused challenge — 8 November 2026

Removed the separate lettered pill button from medication bags. The package image now belongs to the accessible add button and is the drag provider’s starting surface; the name, strength and medication code remain separate above it. Medicines without a matching image use a generic medication symbol inside the same button. Both games share this component. The in-app help now describes image taps and drags.

While a local or connected challenge is presented, the demo role header and bottom tab bar are hidden. The Back button remains available; returning to the inbox restores the normal app header and tabs. This display state is transient and does not change roles, permissions, scoring or saved records. Reduced reference padding, a shorter instruction and a compact prior-exposure note preserve the relevant information while freeing vertical space. The page still scrolls when content needs it, including larger fonts, expanded references, many tablets or feedback.

Built and launched through Xcode on iPhone 17e / iOS 27.2. At default text size, the medication row, all four tray periods and Check button were visible together without vertical scrolling. Verified Bedtime selection, adding A through the medication image button, removing the tray tablet, returning to the inbox with header and tabs restored, and reopening the focused game. Source parsing and whitespace checks passed. A simulator drag attempt did not produce a confirmed drop; physical drag/drop validation remains pending. The fallback, larger accessibility sizes, iPad layout and authenticated connected game also need further visual/gesture checks. The help copy update was source-checked after the running build; no scoring or transport changes were made.

---

# Compact single-row daily tray — 8 November 2026

Both games now use four equal flexible columns for Morning, Afternoon, Evening and Bedtime, rather than an adaptive grid that wraps on iPhone. Pictograms sit above the labels in a shared accessible header. Reduced tray padding, compartment minimum height, card padding, package-photo height and vertical spacing keep more of the shelf and tray visible together. Names remain multiline, and text follows system font scaling; there is no fixed maximum tray height, so additional tablets remain visible as compartments grow.

Built and launched through Xcode on iPhone 17e / iOS 27.2. Portrait inspection confirmed all four compartments across the screen with pill controls visible above. Verified selecting Bedtime, tapping A to add to Bedtime and tapping that tray tablet to remove it. Source parsing and diff checks passed. Scoring and transport logic are unchanged. The drag/drop handlers remain intact; a drag gesture was interrupted during this check, so successful drag/drop is not claimed. Larger text, smaller iPhones, landscape and the connected authenticated UI still require device checks.

---

# Horizontal medication shelf and signing — 8 November 2026

The account owner approved configuring the Yong Hock Liew Apple Developer team for this app. Xcode displayed a managed provisioning profile and an Apple Development signing certificate. Debug and Release now specify team `3T3328WVBE`; the bundle identifier remains `com.edmundliew.samification`. No signing secrets or profiles are committed. Archive creation, distribution validation and TestFlight upload remain pending; the Product menu exposed Archive as disabled during this session.

Both the local and connected games now share a horizontal medication shelf. Ziplocs use fixed-width cards in one HStack inside a horizontal ScrollView, with native scroll indicators and a swipe instruction. The collection never wraps into additional rows as medicines are added. Pill tap handlers and drag providers remain on the existing buttons. The tray layout and scoring are unchanged.

The change compiled and launched on iPhone 17e / iOS 27.2. Portrait visual inspection confirmed a single row with the next card partially visible. Source parsing and diff checks passed. The final build retained individually accessible medication buttons. Verified an actual sideways swipe from the C/D end back to A/B, and tapping D added Allopurinol to Morning. Native scroll indicators use system visibility behavior and may fade between gestures. Larger medication collections, larger text, landscape and connected authenticated game gestures still need device validation. The prior 43 core tests passed before these UI-only changes; they were not rerun because no scoring or transport code changed.

---

# iPad simulator validation — 8 November 2026

- Reran the core XCTest suite: **43 tests, zero failures**.
- Built and launched the development app on iPad (A16), iPadOS 27.2, through Xcode. A stalled simulator boot required a restart; no content reset was performed.
- Observed all four package photos and all four pictogram tray compartments in portrait layout.
- Assigned a fictional local challenge and submitted an incorrect tray. The misplaced tablet displayed red, error feedback appeared and the hint became available. Hint count reached one.
- Clear all retained the existing submission and hint history.
- Found duplicate child identities in the tablet LazyVGrid: different medicines reused the same integer tablet indices. Xcode reported undefined layout results, and visible tray updates were unreliable. Both local and connected games now flatten tablet cells and identify each by medication UUID plus tablet index.
- Rebuilt and relaunched the corrected app successfully. The saved fictional challenge restored. Added B, C and D to Morning and A to Bedtime, observing each distinct tablet appear. The corrected tray passed on submission 2 with one hint retained. Sharing locked the challenge read-only.
- Swift source parsing and diff whitespace checks passed after the UI fix. The 43 core tests ran before the UI-only change; no core scoring or transport code changed.

Connected native sign-in and the clinician results UI walkthrough remain pending. The last simulator email request was rejected with `over_email_send_rate_limit`, and no email was sent. The separate live database walkthrough passed nine checks; it does not replace actual Auth/session or cross-device UI validation. Xcode Apple Accounts showed no signed-in account; account sign-in is being handed to the owner for password/verification entry. Distribution team selection, provisioning and TestFlight upload remain pending. Drag/drop, landscape, larger text and VoiceOver require further device checks.

---

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
