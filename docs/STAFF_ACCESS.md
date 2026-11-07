# v0.2 staff access — development checkpoint

This is preparatory work, not a completed v0.2 release. Medication review, assignments, patient gameplay and results remain the offline demo. Patient pairing, persistent clinical records and backend scoring are still pending.

## Added

The Account tab supports email-code sign-in, requesting clinician access to an active care scope, and administrator approval/rejection/suspension/resumption with a reason. Requests and memberships come from Supabase; the demo role selector does not grant connected permissions. Session tokens are held in memory, never logged or stored in UserDefaults. Sessions require another sign-in after app termination or expiry. Keychain persistence, refresh and lifecycle handling remain future work.

`supabase/migrations/202611010001_staff_access.sql` creates staff-only tables, RLS policies and narrow RPCs. Clients have no direct write privileges on membership, request status or audit tables. Anonymous patient sessions cannot request staff access. An administrator membership alone does not pass the clinician scope check. Future clinical policies must explicitly use the scoped clinician check and the separate patient admission check.

## Project setup (staff migration applied; remaining steps pending)

1. **Completed on 1 November 2026:** signed in as project owner and applied the exact reviewed migration through the SQL editor after explicit confirmation. Five read-only live checks passed. Do not run the migration again; the tables now exist. No service-role key belongs in the iOS app.
2. Configure the Auth **Magic Link** email template to include `{{ .Token }}` for code entry; verify email provider settings, rate limits and delivery. The app uses `/auth/v1/otp` and `/auth/v1/verify` with verification type `email`. Dashboard sign-in and application Auth users are separate accounts.
3. Sign in through the app to create and verify the intended staff Auth identity. The project owner must verify that user's identity in Authentication → Users.
4. Bootstrap the initial administrator using that verified **Auth user UUID** through the project-owner SQL session. Never select an administrator from untrusted client metadata. Insert a membership with `role = 'administrator'` and `scope_id = null`. This privilege change requires review at the time it is performed. No administrator is seeded by the migration.
5. Insert the pilot's approved fictional care scope(s) through the owner SQL session. Scope administration UI is not implemented yet.
6. Copy `Config/Local.xcconfig.example` to ignored `Config/Local.xcconfig` and enter the public project settings. `Config/Base.xcconfig` includes it optionally. The project generator preserves this configuration reference. Leave secrets and signing material out of GitHub.
7. Validate with two independent staff accounts: request/approve, unauthorised direct writes, wrong-scope access, anonymous denial, suspension and resumption. No patient data is required.

Use the Supabase [passwordless email guide](https://supabase.com/docs/guides/auth/auth-email-passwordless), [RLS guide](https://supabase.com/docs/guides/database/postgres/row-level-security), and [database function guidance](https://supabase.com/docs/guides/database/functions) when configuring the project.

## Validation — 1 November 2026

- Full Xcode Swift Package run: **12 tests, 0 failures** (8 assessment/import tests and 4 API client tests).
- Isolated PostgreSQL runtime: **26 access-control checks passed**, including blocked self-approval, anonymous staff requests, direct status/membership/audit writes, wrong scopes, immediate suspension, and no implicit clinician rights for administrators.
- Tests apply the actual migration in PGlite 0.5.14 with a small mock of Supabase's `auth.uid()` / `auth.jwt()` functions. They do not validate the live project's Auth gateway, email delivery, JWT verification, configuration or existing database state.
- Project generation and `plutil` validation passed.
- Updated native iOS build and launch succeeded through Xcode on iPhone 17e / iOS 27.2. The Account screen was verified both without configuration and with the configured email-code form. A smoke check found that custom generated Info.plist build settings did not embed the backend keys; an explicit Config/Info.plist fixed this. The built app now contains the correct project URL and public client key. End-to-end Auth sign-in remains pending. Command-line macro compilation is still restricted by the execution sandbox.
- The iPhone simulator reconnected and the earlier demo launched. Full corrected-tray-to-results walkthrough, iPad layout, and drag/drop gesture QA remain incomplete.
- Supabase dashboard sign-in is verified. Preflight found no public tables and no application Auth user for the intended administrator. After explicit confirmation, the exact tested migration was applied successfully. Five read-only live checks passed: four tables with RLS, no direct client writes, four read policies, three protected RPCs, and no administrator seeded. Administrator bootstrap is still pending.
- The project currently uses Supabase default email delivery and a link-only template. The dashboard disables template editing without custom SMTP or a Pro upgrade. No plan, SMTP, template, or security setting was changed. Email-code delivery and end-to-end sign-in remain blocked on email service setup.

Run the database checks in an isolated environment with a trusted installation of `@electric-sql/pglite`:

```sh
node supabase/tests/staff-access.mjs /absolute/path/to/pglite/dist/index.js
```

The script creates a disposable in-memory PostgreSQL database; it does not connect to Supabase. It uses only fictional users and wards. Run the Swift tests with the full Xcode toolchain as described in README.

## 7 November — first administrator preflight and email-link support

Migrations 001–004 are deployed; current workflow status is in `ASSESSMENT_EVIDENCE.md`. A fresh owner-session lookup found no application Auth identity for the intended initial administrator. No administrator or clinician membership has been granted. Dashboard owner sign-in remains separate from app sign-in.

The Account screen now accepts the original Supabase email sign-in/confirmation link as an alternative to a numeric email code. This avoids requiring custom SMTP/template editing for the first project-owner test account. Request a sign-in email, copy its original link without opening it, and paste it into the secure field in the native app. Do not paste login links into chat. The client accepts only this project's HTTPS `/auth/v1/verify` link, rejects ambiguous tokens, recovery/invite/email-change flows and fragments, exchanges the token hash via the pinned JSON endpoint and checks the returned email against the requested identity. It never visits the email link's redirect destination. Link/session values remain in memory and are not logged or committed.

Default Supabase email delivery may restrict recipients and rate-limit requests. Supporting the default link format does not establish delivery to arbitrary recipients; custom sender configuration remains necessary before a broad pilot, and can still be configured later without changing role approval logic.

Validation: **35 Swift tests passed**, including pinned verification destination, duplicate/type rejection, ignored redirect destinations and mismatched-user rejection/sign-out. Native build and launch verification are performed separately. Administrator grant still requires verified Auth identity and explicit action-time approval; email verification alone grants no role.

References: [Supabase verification API](https://supabase.com/docs/reference/swift/auth-verifyotp), [default email-link format](https://supabase.com/docs/guides/auth/auth-email-templates).

The first live sign-in email request was accepted from the native app on 7 November. Delivery and user verification are still pending. The app is left on its Account verification form in the Mac iPhone simulator. No login credential was read from email or copied into chat.

A separate owner-only `supabase/admin/bootstrap-first-administrator.sql` is now prepared. It refuses execution without an explicitly supplied verified Auth UUID, rejects anonymous/unconfirmed/never-signed-in identities, refuses a second initial administrator (including when an existing administrator is suspended), grants only the unscoped administrator role and records the bootstrap in the access audit. It is not part of automatic migrations and has **not** been run live. Ten isolated PostgreSQL guard checks passed. The next live step requires successful app sign-in and explicit privilege-grant confirmation for that exact identity.

## 8 November — sign-in form feedback fix

A simulator sign-in attempt submitted the button caption `Sign in` through the numeric-code option. The service rejected it, but the message was below the visible form. The form now defaults to link verification, collapses the alternative code controls, shows errors alongside the controls, and rejects button captions/invalid code formats before sending a request. Link verification is available as soon as an email is entered, including when the sign-in email was requested elsewhere; requesting another email is not required just to reveal the field. The introductory text is shorter so the controls are easier to reach.

The shared link parser validates both the submit button state and the actual network operation. Numeric codes require 6–10 ASCII digits. A plain copied caption in the link field produces an immediate instruction to copy the actual link address. The app keeps original verification tokens in memory only. These input checks do not grant roles or bypass server verification.

Validation: **37 Swift tests passed**. The updated app built and launched on the iPhone simulator. Entering a fictional button caption into the link field showed the inline error and kept verification disabled. The test value was cleared; the app is left on the link form for the user. Successful native authentication remains pending the user's valid one-use email link. No additional live roles or database changes were made.

## 8 November — Outlook copied-link compatibility

Outlook may copy a Safe Links URL, formatted email, or only the selected button caption. The parser now extracts a single unique credential from copied text/Markdown/HTML, locally unwraps up to three Outlook Safe Links envelopes, and still accepts only this project's HTTPS verification endpoint and supported sign-in types. It rejects ambiguous credentials, malformed wrappers and oversized input. It never opens Outlook, a tracking link or the configured redirect destination.

A user-initiated **Paste email link** button tries the clipboard's URL, HTML and text representations. It reads the clipboard only after that button is tapped; no clipboard data is logged or persisted. If every representation contains only `Sign in`, the app explicitly explains that Copy Link Address is required. The actual credential shared in chat was not opened, tested, saved in files or added to fixtures; all new tests use fictional token strings.

Validation: **40 Swift tests passed**, including copied Outlook Markdown/HTML, wrapper bounds, duplicate credentials, foreign origins and the pinned outgoing verification request. End-to-end sign-in still requires a valid, unused user-supplied link. The existing Supabase sending rate limit is a separate delivery constraint; this change does not resend email or alter email settings.

## 8 November — authentication rejection diagnosis and tests

The live Auth log for the reported pre-login permission error showed HTTP 403, machine code `otp_expired`, and `One-time token not found`. The client had classified every HTTP 403 as a staff authorisation failure. Auth errors now use their machine codes to distinguish expired/invalid/used one-time links, email-send quota failures and recipient restrictions. Unknown verification failures have a separate sign-in message. Raw server messages are not reflected into the UI. Clinical permission failures still retain the existing forbidden-access handling.

Validation: **43 Swift tests passed**. After rebuilding and launching the native app, a deliberately fictional token was submitted to the real verification endpoint. The app displayed the correct `otp_expired` explanation and did not sign in. No email was sent, real user token consumed, staff role granted or clinical row created during this negative test. The user's original reported failure was diagnosed from server log error codes, not by reusing their posted login link. Successful live native sign-in remains unverified until a valid unused link is available; the known default-email sending quota remains a separate constraint.
