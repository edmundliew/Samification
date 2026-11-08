# Separate workspaces — 8 November 2026

## Mobile entry

- **Join my care**: patient pairing, then that admission’s assigned challenges. No staff account tab, clinician tabs, or role selector.
- **Staff sign-in**: email/password and existing account setup. An authenticated user without active clinician membership stays at access/request status. Active clinicians open Patients, Account and Help. Admissions contain medication review, assignments, patient pairing, results and clinical reviews.
- **Try demo**: explicitly fictional, local-only clinician/patient previews. No connected account, pairing or administrator tabs. Exit demo returns to the entry screen. The medication game remains unchanged.

The entry preference persists locally and grants no permission. Staff sessions restore through Keychain and server refresh. Patient connection is retained in memory during this process only; persistent patient restoration across app termination is not implemented. During an active paired session there is no workspace-switch button; End patient session must complete before Back becomes available. Separate approval is still required for every clinician ward grant. Dual-role staff see only clinician tools on mobile; no administrator role is displayed there.

The shared staff store now lives at the root, so navigation does not create duplicate account sessions. Access refresh commits a complete snapshot; a failed refresh clears cached grants. Clinical APIs continue enforcing server RLS independently of navigation. Credentials are cleared on backgrounding. Connected patient APIs and evidence rules were not changed.

## Administrator web portal

`web/admin` is an independent static portal for email/password sign-in, active-administrator verification, pending clinician approvals/rejections, scoped suspension/resumption, ward configuration display and latest 100 access audit events. A reason and an explicit decision submission are required. It calls the existing controlled RPCs; there are no direct table writes, administrator-grant controls, patient records or clinical review screens. Ward creation/editing remains owner-controlled backend work, not yet a portal feature.

Only the public publishable key is included. Session tokens are in memory, never browser storage or URLs. Reload requires sign-in. Non-administrators are denied and their session is logged out. All user text uses textContent. CSP and Cloudflare response headers restrict scripts, frames and connections. No schema, permissions or staff memberships were changed by this UI checkpoint.

## Validation

- Xcode built and launched the updated app on iPhone 17e successfully. The shell xcodebuild attempt encountered the known host macro/CoreSimulator restriction; native Xcode succeeded.
- Inspected welcome, patient pairing-only view, clinician email/password-only view, fictional demo, patient demo inbox, medication challenge, Back and Exit demo.
- 48 Swift core tests pass. Five mocked portal tests pass: invalid password; ordinary-clinician rejection without admin data fetch; admin read-only loading and untrusted-name rendering; required reason/scoped approval RPC; sign-out clearing rendered records.
- Portal localhost returned HTTP 200. Browser sign-in form rendered with no JS console errors. No live portal approval or valid authenticated portal/native login was performed.
- New native approved-clinician automatic routing is source/build verified only; it awaits a valid native staff session. Current owner email link returned otp_expired. No fresh real credentials were entered or sent by these tests.
- Latest iPad/large-text navigation, patient session restoration, live portal auth, Cloudflare portal deployment and App Store readiness remain pending.
