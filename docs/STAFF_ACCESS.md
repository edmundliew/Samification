# v0.2 staff access — development checkpoint

This is preparatory work, not a completed v0.2 release. Medication review, assignments, patient gameplay and results remain the offline demo. Patient pairing, persistent clinical records and backend scoring are still pending.

## Added

The Account tab supports email-code sign-in, requesting clinician access to an active care scope, and administrator approval/rejection/suspension/resumption with a reason. Requests and memberships come from Supabase; the demo role selector does not grant connected permissions. Session tokens are held in memory, never logged or stored in UserDefaults. Sessions require another sign-in after app termination or expiry. Keychain persistence, refresh and lifecycle handling remain future work.

`supabase/migrations/202611010001_staff_access.sql` creates staff-only tables, RLS policies and narrow RPCs. Clients have no direct write privileges on membership, request status or audit tables. Anonymous patient sessions cannot request staff access. An administrator membership alone does not pass the clinician scope check. Future clinical policies must explicitly use the scoped clinician check and the separate patient admission check.

## Project setup (not yet performed remotely)

1. Sign in to the existing Supabase dashboard as project owner. Review the migration and apply it once through the project's SQL editor or an authenticated Supabase migration workflow. No service-role key belongs in the iOS app.
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
- Updated native UI build and end-to-end sign-in remain unverified. Command-line iOS compilation was blocked by nested compiler macro sandbox restrictions. Xcode UI automation timed out while opening the project. The earlier v0.1 simulator build does not validate the new Account screen.
- The iPhone simulator reconnected and the earlier demo launched. Full corrected-tray-to-results walkthrough, iPad layout, and drag/drop gesture QA remain incomplete.
- The remote Supabase project has **not** been migrated or bootstrapped. Dashboard sign-in is pending.

Run the database checks in an isolated environment with a trusted installation of `@electric-sql/pglite`:

```sh
node supabase/tests/staff-access.mjs /absolute/path/to/pglite/dist/index.js
```

The script creates a disposable in-memory PostgreSQL database; it does not connect to Supabase. It uses only fictional users and wards. Run the Swift tests with the full Xcode toolchain as described in README.
