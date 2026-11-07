# Same-account pilot testing — 8 November 2026

The account owner chose one verified email identity for both administrator and clinician testing. Administrator access remains separate from ward-specific clinician membership. Email domains grant neither role.

## Activated with explicit approval

`supabase/admin/provision-same-account-test-clinician.sql` provisions clinician membership only in **Samification Test Ward (fictional)**. The owner supplies the verified Auth UUID through the transaction-local `samification.test_staff_id` setting after BEGIN. The script requires a verified, previously signed-in active administrator, uses the ordinary request/approval functions and audit records, rejects suspended memberships and is idempotent for an active membership. This is persistent access until explicitly suspended. No patient records are created by provisioning. The account owner explicitly approved activation on 8 November 2026. The grant was applied in the project SQL Editor. Four live verification checks passed: administrator membership retained; exactly one active clinician membership, limited to the fictional ward; clinician approval audit present; and no clinical admission, challenge run, review or patient-session records remaining after the walkthrough.

## Repeatable workflow checks

`supabase/admin/rollback-workflow-walkthrough.sql` exercises fictional admission creation, confirmed regimen assignment, pairing, incorrect submission, idempotent replay, hint, correct retry, clinician review and patient-session revocation. All nine result rows must pass; the transaction then rolls back the fictional clinical records and an uncommitted anonymous Auth fixture. Sequence gaps may remain. This owner-run script simulates database JWT claims; it does not issue Auth tokens or verify native sign-in, HTTP authorization or the entire native UI workflow.

`supabase/tests/same-account-workflow.mjs` runs the actual four migrations and both scripts in disposable PGlite. **24 checks passed locally**, including guarded provisioning, audited approval, idempotency, the nine workflow results, rollback cleanup and refusal to reactivate a suspended membership. No live roles or data changed during these checks.

Example local command, using an installed PGlite module:

```sh
node supabase/tests/same-account-workflow.mjs /absolute/path/to/pglite/dist/index.js
```

## Remaining validation

All nine rollback-only workflow checks also passed against the live Supabase project on 8 November 2026. The fictional clinical records were rolled back; the approved scoped clinician membership and its approval audit persist. These checks execute database functions with simulated claims in an owner SQL session, not actual patient/staff Auth sessions. Successful native authentication and a complete connected UI walkthrough are still pending. The most recent email request returned `over_email_send_rate_limit`; it did not deliver a new email. Sender configuration remains independent of recipient emails and can be changed later.
