# Samification administrator portal

Separate from the iPhone/iPad clinician/patient app. Prepared locally; **not deployed**. Uses the existing Supabase project and public publishable key. No backend secrets or role grants are bundled.

Sign in using an already verified staff email/password. Only active administrators can load the portal; database RLS and RPCs remain authoritative. Session stays in memory and is lost on reload. Initial verification/password setup still uses the app and requires working email delivery. No staff domain is auto-approved.

Features: pending requests, scoped approve/reject with reasons, clinician ward suspend/resume with reasons, ward list, latest 100 audit events. Ward creation/editing and administrator provisioning remain controlled backend operations. No patient clinical records are loaded.

## Local verification

```sh
node --test web/admin/test.mjs
python3 -m http.server 8767 --bind 127.0.0.1 --directory web/admin
```

Open http://127.0.0.1:8767. Tests use fictional mocked responses, not live authentication or memberships.

## Cloudflare Pages

Create a separate Pages project for administration rather than replacing the medication prototype. Deploy only `index.html`, `app.js`, `style.css` and `_headers` from this directory as a static site (no framework or build). Do not upload the repository or local configuration files. `_headers` supplies CSP, frame blocking, no-store and referrer protection. Verify response headers, live administrator sign-in, non-admin denial and a fictional audited approval before using it for a pilot. Hosting alone grants no backend permissions.
