# Familiar healthcare sign-in pattern

Samification uses a small, conventional entry flow. Staff open Account, enter email/password and sign in. Approved roles come from server memberships, never email domains. Patient admission pairing remains separate and does not require patient email. A remembered staff session is renewed using its refresh token; no password is saved by Samification. Face ID, passkeys and hospital SSO are future options, not implemented features.

## Research and application

- [Epic MyChart biometric login](https://www.mychart.org/Help/passcode-biometric): MyChart offers biometric return login after initial sign-in. We apply the principle of separating initial identity verification from routine return access.
- [University Hospitals Epic mobile setup](https://www.uhhospitals.org/for-employees/epic-mobile-resources): this hospital deployment uses existing staff credentials and remote two-step verification. Hospital configuration varies; this is not a claim that all Epic deployments work identically. Future hospital SSO depends on a partner’s identity provider.
- [MyChart account activation](https://www.mychart.org/l/en-us/help/sign-up/): activation and identity verification precede ongoing account access. Samification likewise keeps first-time verification separate from staff approval.
- [MyChart Care Companion](https://www.mychart.org/Features): care plans, reminders and tasks suggest a clear patient task list and clinician-assigned challenges. This does not validate Samification’s competency scoring or imply integration with Epic.
- [Supabase password authentication](https://supabase.com/docs/guides/auth/passwords) and [sessions](https://supabase.com/docs/guides/auth/sessions): password and refresh grants support routine access without sending login email. Initial confirmation and recovery still depend on email.

## Current implementation and limits

Password sign-in sends only email/password to the pinned project Auth endpoint. Password setup uses the authenticated user endpoint and a minimum of 12 characters. Passwords are cleared from fields before requests; no privileged project key is used. Tokens are saved in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; refresh replaces rotated credentials and checks the returned user ID matches the saved identity. Invalid sessions clear saved sign-in, while temporary connectivity failure retains credentials for retry. Sign-out attempts server invalidation and clears local credentials. A remembered session is not an administrator approval or a new clinical privilege.

The initial/recovery email verification path remains transitional: users copy the original email verification link into a secondary form, then set their password. Direct email-to-app links and production SMTP configuration remain unresolved. The existing localhost redirect must not be represented as fixed. Built-in sender limits still affect initial setup/recovery, but not routine password sign-in. No email verification was disabled.

The account owner must complete live password entry directly. A successful live password sign-in, Keychain rotation/restoration after relaunch, sign-out and expired-session recovery are still pending; mock transport tests do not prove them. Only a live negative-password flow has been verified so far.
