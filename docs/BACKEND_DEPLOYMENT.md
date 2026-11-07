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

## Clinical and patient-pairing activation — 1 November 2026

Following separate explicit approval, deployed migrations 002 and 003 in one atomic transaction using the prepared activation bundle. Source checkpoint: `de4df2ba516d93ba9597376ab640159334fd6639`. Bundle SHA-256: `9bd15fc2eca532eb207b25bdf6f05a05ea2dd62083f620f75579097d864d1e60`. The live SQL editor content was checked against that bundle before Run. No users, scopes, staff memberships or clinical records were seeded.

Enabled **Allow anonymous sign-ins** and saved it in Supabase Auth. Email confirmation remains enabled; manual identity linking remains disabled. No email service, paid plan or administrator grant was changed.

Six live schema/grant checks and 13 real Auth/API checks passed. One temporary unpaired Auth identity was created for verification and signed out; the user record was not permanently deleted. No clinical records were created. See `docs/CONNECTED_WORKFLOW.md` for the verified cases and remaining end-to-end limits. These migrations were executed manually through SQL Editor and still require migration-history reconciliation before future CLI-managed deployment.

## Deployed 7 November 2026: assessment evidence migration 004

`202611070004_assessment_evidence.sql` adds three RLS-protected evidence/review tables and narrow patient action/history and clinician review RPCs. It does not seed identities, memberships or patient records. Application roles have no direct writes. Locally tested against all preceding migrations; **successfully applied to the live project** after the user approved activation. See `ASSESSMENT_EVIDENCE.md` for the test evidence and rollout limits.


Migration SHA-256: `c0a3eaa956ff626a2a2828962812f73bc1f7fe7e21284d306f3c85ac45d826d2`. The SQL editor content was copied back and checked against the exact tested source before execution. Supabase returned “Success. No rows returned.” Seven read-only live checks verified three RLS-protected tables, no direct client writes, no unauthenticated evidence reads, three restricted security-definer RPCs, a private scoring helper, no seeded evidence or staff memberships, and successful exact-match scoring using a fictional in-memory example. No clinical rows or Auth identities were created for these checks. Proof: `outputs/samification-evidence-activation-verified.png` in the parent workspace.

This activation was run manually through SQL Editor, as with 001–003. Reconcile CLI migration history before adopting CLI deployment; do not reapply existing CREATE statements. The valid paired clinician/patient workflow remains unverified live until the intended administrator and approved clinician are provisioned.


## 8 November 2026: first administrator provisioned

The explicitly approved initial administrator bootstrap completed for the verified identity. Five live database checks passed, including the active administrator helper, audit record, absence of clinician membership and blocked direct client membership writes. Transaction-local role/JWT simulation was used for database permission checks; native Auth sign-in remains pending. No clinician grant, clinical patient row or email configuration change was performed. See `STAFF_ACCESS.md` for the verification limits and screenshot artifact.
