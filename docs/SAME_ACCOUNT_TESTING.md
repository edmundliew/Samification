# Same-account pilot testing — 8 November 2026

The account owner chose one verified email identity for both administrator and clinician testing. Administrator access remains separate from ward-specific clinician membership. Email domains grant neither role.

## Prepared, not activated

`supabase/admin/provision-same-account-test-clinician.sql` provisions clinician membership only in **Samification Test Ward (fictional)**. The owner supplies the verified Auth UUID through the transaction-local `samification.test_staff_id` setting after BEGIN. The script requires a verified, previously signed-in active administrator, uses the ordinary request/approval functions and audit records, rejects suspended memberships and is idempotent for an active membership. This is persistent access until explicitly suspended. No patient records are created by provisioning. Live activation awaits action-time approval for the expanded privilege.

## Repeatable workflow checks

`supabase/admin/rollback-workflow-walkthrough.sql` exercises fictional admission creation, confirmed regimen assignment, pairing, incorrect submission, idempotent replay, hint, correct retry, clinician review and patient-session revocation. All nine result rows must pass; the transaction then rolls back the fictional clinical records and an uncommitted anonymous Auth fixture. Sequence gaps may remain. This owner-run script simulates database JWT claims; it does not issue Auth tokens or verify native sign-in, HTTP authorization or the entire native UI workflow.

`supabase/tests/same-account-workflow.mjs` runs the actual four migrations and both scripts in disposable PGlite. **24 checks passed locally**, including guarded provisioning, audited approval, idempotency, the nine workflow results, rollback cleanup and refusal to reactivate a suspended membership. No live roles or data changed during these checks.

Example local command, using an installed PGlite module:

```sh
node supabase/tests/same-account-workflow.mjs /absolute/path/to/pglite/dist/index.js
```

## Remaining validation

Apply and verify the scoped grant after approval, then execute the rollback-only walkthrough against the project. Successful native authentication and a complete connected UI walkthrough are still pending. The most recent email request returned `over_email_send_rate_limit`; it did not deliver a new email. Sender configuration remains independent of recipient emails and can be changed later.
