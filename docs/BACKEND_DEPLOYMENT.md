# Staff-access deployment — 1 November 2026

Project: Samification (`vqexfcvzoryocjnzjozv`).

Applied `supabase/migrations/202611010001_staff_access.sql` through the authenticated Supabase dashboard SQL editor, following the owner’s explicit action-time confirmation. The editor content was copied back and compared with the local migration before execution: exact match, 9,539 characters. Execution returned “Success. No rows returned.”

Migration SHA-256: `e93b594a5204910acc241da3d02ba39e86843db5fa9468ef7bac7f2cb3a5f904`. The source is present in development commit `ddfd3c983aae52bbaf29d6d57b827c5b7aa43e2f`.

Read-only live catalog checks all returned true:

- Four staff tables have RLS enabled.
- Authenticated clients cannot directly insert, update or delete staff tables; anonymous clients cannot read or write them.
- Four read policies are installed.
- Three staff RPCs are security-definer functions executable by authenticated callers, not anonymous callers. Their internal authorization guards were exercised by the isolated PostgreSQL suite.
- No administrator membership was granted by this migration.

These live checks inspect schema and grants. They do not replace end-to-end Auth/RLS validation with distinct real test sessions. The isolated suite previously passed 26 permission checks; the Swift suite passed 12 tests.

This was manual SQL-editor execution, not a Supabase CLI migration push. Do not assume the CLI migration-history table records this deployment; reconcile history before adopting CLI migration management, without reapplying existing CREATE statements. No patient records, clinical roles, scopes or staff memberships were seeded.

## Remaining prerequisites

The intended administrator has no application Auth identity yet. Dashboard login is a separate identity system. Complete application sign-in, verify that account’s email, then review and confirm the administrator membership grant separately.

The current default Magic Link/OTP email is link-only. Supabase’s dashboard requires custom SMTP or Pro to edit it. No paid upgrade, email provider connection or template change was performed. Email-code sign-in requires that setup. See `docs/STAFF_ACCESS.md`.
