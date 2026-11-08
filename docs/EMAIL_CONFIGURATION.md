# Email configuration boundary

Email setup is deferred and must not block the medication and assessment workflow.

The sending provider, sender display name and sender address belong in Supabase’s backend SMTP/email settings. They are not compiled into the SwiftUI app or used to determine user roles. Changing the sender later should require only backend/provider configuration, without an iOS release. The provider may require proof that the sending address/domain is authorised; that requirement belongs to email delivery, not account approval.

Staff recipient emails can use any domain they control. Verifying an email proves control of that address. Administrator and clinician permissions come only from protected memberships and explicit approval; no allowlist based on sender domain or automatic administrator assignment is implemented. The initial administrator is provisioned separately after identity verification. Patient admission pairing does not require an email address.

SMTP/API credentials stay in the email provider and Supabase settings. No privileged email credential goes into the iOS app, local demo workspace or public GitHub repository. Sender changes must preserve the application’s verification-code template when that flow is enabled. The existing project currently has a link-only default template; no paid upgrade or custom SMTP change has been performed.

## 8 November — password sign-in

Routine staff sign-in now uses the Supabase password grant and does not send an email. Session refresh also uses no email. Email verification is still required for initial account/password setup and account recovery; the existing email-link and numeric-code verification paths are secondary. A fresh request for the account owner was accepted by Supabase on 8 November; acceptance does not prove delivery. Production onboarding/recovery still need a configured sender. No SMTP credentials, sender-domain settings, email-confirmation switches or redirect URLs were changed. The localhost redirect problem is not claimed fixed: the interim setup path verifies the original link inside the app, without opening the redirect.
