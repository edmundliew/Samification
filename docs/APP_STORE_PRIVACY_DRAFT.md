# Samification privacy preparation — owner review required

Draft only. This file is an implementation inventory, not a published privacy policy or a statement of legal compliance. Owner-approved contact: edmund_liew@live.com.

## Data handled by the connected app

| Data | Purpose | Storage / access |
| --- | --- | --- |
| Staff email, profile name and Auth user ID | Authentication and staff access approval | Supabase Auth and protected profile/access records |
| Ward membership, requests, approvals and access audit | Authorize and audit clinician access | Supabase; scoped approval controls |
| Admission alias and ID, medication names, strengths, doses, schedules and directions | Deliver the assigned virtual training challenge | Supabase; approved ward clinicians and paired patient identity |
| Tray submissions, hints, references, timestamps and calculated results | Preserve assessment evidence and retries | Supabase; immutable server actions |
| Clinician review outcome and rationale | Document review of the virtual evidence | Supabase; scoped ward access |
| Staff session credentials | Restore authorized staff sign-in | Apple Keychain on the device |
| Temporary patient credentials | Authorize the paired admission session | App memory; lost after termination |
| Fictional demo workspace | Single-device practice | Device-local saved workspace and restart backup |

The source integrates no advertising or cross-app tracking SDK. The app's privacy manifest does not replace App Store data disclosures. Supabase infrastructure/Auth security logs and any Apple-provided diagnostics must be checked separately before making complete declarations. Medication data remains sensitive even where the pilot is instructed to use fictional records.

## Proposed App Privacy mapping to verify in Apple's questionnaire

Contact Info: name and email address (staff authentication/access). Identifiers: user ID, including temporary patient Auth identity. Health & Fitness / Health: medication-related records if used for a real patient. User Content / Other User Content: clinician review text and imported records as appropriate. Usage Data / Product Interaction: recorded challenge actions and assistance requests. Purposes are app functionality and security/access control; these records are linked to account/admission identities. Do not choose Data Not Collected for this connected build. Do not claim tracking or advertising use where none exists. Confirm Apple's precise definitions and the configured backend before publishing.

## Public-release gaps requiring real implementation or owner facts

1. Confirm the operator and applicable retention/deletion rules. No automatic purge period is established in the current migrations; do not promise a made-up deletion time or retention duration.
2. Implement an in-app way to initiate account deletion and an actual backend fulfillment process. Staff approval/suspension, sign-out and End patient session are not account/data deletion. Preserve records only where there is an established lawful requirement, and explain it to the user.
3. Publish a stable privacy policy and support page, and link the privacy policy inside the app. Owner approved the support/privacy email above; no policy is published yet.
4. Verify Supabase deployment region, processor arrangements, operational log retention, backup retention and deletion handling against actual project settings.
5. Complete Apple's age rating, content rights, regulated-device status, privacy declarations and distribution questions using accurate facts. Do not infer medical certification from the Medical category or from a disclaimer.

## Authoritative Apple guidance checked 9 November 2026

- https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/app-store/app-privacy-details/
