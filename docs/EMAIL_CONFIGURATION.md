# Email configuration boundary

Email setup is deferred and must not block the medication and assessment workflow.

The sending provider, sender display name and sender address belong in Supabase’s backend SMTP/email settings. They are not compiled into the SwiftUI app or used to determine user roles. Changing the sender later should require only backend/provider configuration, without an iOS release. The provider may require proof that the sending address/domain is authorised; that requirement belongs to email delivery, not account approval.

Staff recipient emails can use any domain they control. Verifying an email proves control of that address. Administrator and clinician permissions come only from protected memberships and explicit approval; no allowlist based on sender domain or automatic administrator assignment is implemented. The initial administrator is provisioned separately after identity verification. Patient admission pairing does not require an email address.

SMTP/API credentials stay in the email provider and Supabase settings. No privileged email credential goes into the iOS app, local demo workspace or public GitHub repository. Sender changes must preserve the application’s verification-code template when that flow is enabled. The existing project currently has a link-only default template; no paid upgrade or custom SMTP change has been performed.
