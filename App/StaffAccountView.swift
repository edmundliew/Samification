import SwiftUI
import UIKit
import Observation
import Security

private enum StaffSessionVault {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.edmundliew.samification.staff-session.v1",
         kSecAttrAccount as String: "current-staff"]
    }
    static func save(_ session: StaffSession) throws {
        guard session.refresh_token?.isEmpty == false else { throw VaultError.unavailable }
        let values: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(session),
                                    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            guard SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw VaultError.unavailable }
        } else if status != errSecSuccess { throw VaultError.unavailable }
    }
    static func load() throws -> StaffSession? {
        let lookup = query.merging([kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]) { _, new in new }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw VaultError.unavailable }
        return try JSONDecoder().decode(StaffSession.self, from: data)
    }
    static func remove() { SecItemDelete(query as CFDictionary) }
    enum VaultError: Error, LocalizedError {
        case unavailable
        var errorDescription: String? { "Unable to access saved sign-in on this device. Unlock the device and try again." }
    }
}

@MainActor @Observable final class StaffAccountStore {
    var email = ""
    var password = ""
    var newPassword = ""
    var confirmPassword = ""
    var restoreFailed = false
    private var restorationAttempted = false
    var code = ""
    var emailLink = ""
    var name = ""
    var reason = ""
    var selectedScope: UUID?
    var session: StaffSession?
    var scopes: [CareScope] = []
    var memberships: [StaffMembership] = []
    var requests: [StaffAccessRequest] = []
    var busy = false
    var notice: String?
    var failed = false
    var codeSent = false
    private var client: StaffAccessClient? { BackendConfiguration.client() }
    var configured: Bool { client != nil }
    var administrator: Bool { memberships.contains { $0.user_id == session?.user.id && $0.role == "administrator" && $0.active } }
    var clinician: Bool { memberships.contains { $0.user_id == session?.user.id && $0.role == "clinician" && $0.active } }
    var emailValid: Bool { email.contains("@") && email.count <= 254 && !email.contains(where: \.isWhitespace) }
    func perform(refreshAuthentication: Bool = true, _ action: @escaping (StaffAccessClient) async throws -> Void) async {
        guard !busy else { return }
        guard let client else { notice = StaffAPIError.configuration.localizedDescription; failed = true; return }
        busy = true; notice = nil; failed = false
        defer { busy = false }
        do {
            if refreshAuthentication, session?.needsRenewal() == true { try await renewAuthentication(client) }
            try await action(client)
        } catch {
            var failure = error
            if refreshAuthentication, case StaffAPIError.authentication = error, session != nil {
                do {
                    try await renewAuthentication(client)
                    notice = "Sign-in renewed. Please retry your action; check its latest status before saving again."
                    failed = true; return
                } catch { failure = error }
            }
            if case StaffAPIError.authentication = failure { clearSession() }
            if case StaffAuthError.invalidRefresh = failure { clearSession() }
            notice = (failure as? StaffAPIError)?.localizedDescription ?? (failure as? StaffAuthError)?.localizedDescription ?? (failure as? StaffSessionVault.VaultError)?.localizedDescription ?? "Unable to read the service response. Please try again."
            failed = true
        }
    }
    private func renewAuthentication(_ client: StaffAccessClient) async throws {
        guard let saved = session, let refresh = saved.refresh_token else { throw StaffAPIError.authentication }
        let value = try await client.refreshSession(refreshToken: refresh)
        guard value.user.id == saved.user.id else {
            try? await client.signOut(token: value.access_token)
            throw StaffAPIError.authentication
        }
        try StaffSessionVault.save(value); session = value
    }
    private func accept(_ value: StaffSession, client: StaffAccessClient) async throws {
        try StaffSessionVault.save(value)
        session = value; password = ""; code = ""; emailLink = ""
        try await load(client)
    }
    func signInWithPassword() async {
        guard emailValid, !password.isEmpty else { return }
        let enteredPassword = password; password = ""
        await perform { client in
            let value = try await client.signInWithPassword(email: self.email, password: enteredPassword)
            try await self.accept(value, client: client)
        }
    }
    func restore(force: Bool = false) async {
        guard !restorationAttempted || force else { return }
        restorationAttempted = true
        await renew()
    }
    func renew() async {
        guard !busy else { return }
        do {
            guard let saved = try StaffSessionVault.load(), let refresh = saved.refresh_token else { return }
            await perform(refreshAuthentication: false) { client in
                let value = try await client.refreshSession(refreshToken: refresh)
                guard value.user.id == saved.user.id else {
                    try? await client.signOut(token: value.access_token)
                    self.clearSession(); throw StaffAPIError.authentication
                }
                try await self.accept(value, client: client)
                self.restoreFailed = false
            }
            restoreFailed = failed && session == nil
        } catch { restoreFailed = true; failed = true; notice = "Unable to restore saved sign-in. Unlock the device and try again." }
    }
    func savePassword() async {
        guard session != nil, newPassword == confirmPassword, newPassword.count >= 12 else { return }
        let value = newPassword; newPassword = ""; confirmPassword = ""
        await perform { client in
            guard let token = self.session?.access_token else { throw StaffAPIError.authentication }
            try await client.setPassword(value, token: token)
            self.notice = "Password saved. Next time, sign in with your email and password."
        }
    }
    func sendCode() async {
        guard emailValid else { return }
        await perform { client in
            try await client.sendCode(email: self.email)
            self.codeSent = true
            self.notice = "Check your email to verify your account, then set a password. This one-time step still requires email delivery."
        }
    }
    func signIn() async {
        guard StaffAccessClient.validEmailCode(code) else { notice = "Enter the numeric code from your email, not the words on its button."; failed = true; return }
        await perform { client in
            let value = try await client.verifyCode(email: self.email, code: self.code.trimmingCharacters(in: .whitespacesAndNewlines))
            try await self.accept(value, client: client)
            self.notice = "Email verified. Open Password settings below to set your Samification password."
        }
    }
    func pasteEmailLink() {
        // Only read the clipboard after the user explicitly taps Paste email link.
        let pasteboard = UIPasteboard.general
        let html = pasteboard.data(forPasteboardType: "public.html").flatMap { String(data: $0, encoding: .utf8) }
        let options = [pasteboard.url?.absoluteString, html, pasteboard.string].compactMap { $0 }
        if let value = options.first(where: StaffAccessClient.validEmailLink) {
            emailLink = value; notice = nil; failed = false
        } else {
            emailLink = ""; failed = true
            notice = "The clipboard has no sign-in address. Right-click the email's Sign in button and choose Copy Link Address, then tap Paste email link. Copying the words Sign in alone is not enough."
        }
    }
    func signInWithLink() async {
        guard StaffAccessClient.validEmailLink(emailLink) else { notice = "Copy the actual link address from the email button, not its words. Use the original, unopened Supabase sign-in link."; failed = true; return }
        let link = emailLink; emailLink = ""
        await perform { client in
            let value = try await client.verifyEmailLink(link, expectedEmail: self.email)
            try await self.accept(value, client: client)
            self.notice = "Email verified. Open Password settings below to set your Samification password."
        }
    }
    func refresh() async { await perform { try await self.load($0) } }
    private func load(_ client: StaffAccessClient) async throws {
        guard let token = session?.access_token else { return }
        // Commit access as one snapshot to avoid tearing down navigation during renewal.
        // Any failed refresh removes cached access; every clinical RPC also enforces RLS.
        do {
            let newMemberships = try await client.memberships(token: token)
            let newScopes = try await client.scopes(token: token)
            let newRequests = try await client.requests(token: token)
            memberships = newMemberships; scopes = newScopes; requests = newRequests
            if !scopes.contains(where: { $0.id == selectedScope && $0.active }) { selectedScope = scopes.first(where: \.active)?.id }
        } catch {
            scopes = []; memberships = []; requests = []
            throw error
        }
    }

    func requestAccess() async {
        guard let scope = selectedScope else { return }
        await perform { client in
            guard let token = self.session?.access_token else { throw StaffAPIError.authentication }
            try await client.requestAccess(scope: scope, name: self.name.trimmingCharacters(in: .whitespacesAndNewlines), token: token)
            try await self.load(client); self.notice = "Access request submitted for administrator review."
        }
    }
    func decide(_ id: UUID, approve: Bool) async {
        await perform { client in
            guard let token = self.session?.access_token else { throw StaffAPIError.authentication }
            try await client.decide(requestID: id, approve: approve, reason: self.reason, token: token)
            try await self.load(client); self.reason = ""; self.notice = "Decision recorded."
        }
    }
    func setAccess(_ membership: StaffMembership) async {
        await perform { client in
            guard let token = self.session?.access_token else { throw StaffAPIError.authentication }
            try await client.setAccess(membershipID: membership.id, enabled: !membership.active, reason: self.reason, token: token)
            try await self.load(client); self.reason = ""; self.notice = "Access change recorded."
        }
    }
    func signOut() async {
        guard let token = session?.access_token else { return }
        await perform(refreshAuthentication: false) { client in
            defer { self.clearSession() }
            try await client.signOut(token: token)
        }
    }
    private func clearSession() { StaffSessionVault.remove(); password = ""; newPassword = ""; confirmPassword = ""; restoreFailed = false; session = nil; memberships = []; scopes = []; requests = []; code = ""; emailLink = ""; codeSent = false; reason = ""; name = "" }
    func scopeName(_ id: UUID?) -> String { scopes.first { $0.id == id }?.name ?? "Unknown scope" }
}

struct StaffAccountView: View {
    @Bindable var account: StaffAccountStore
    var body: some View {
        @Bindable var account = account
        Form {
            Section {
                Text("Clinician sign-in").font(.headline)
                Text("Sign in to access your approved ward. New clinicians require administrator approval.").font(.caption)
            }
            if !account.configured {
                Section { Notice(text: "Connected access is not configured in this build. Add the project URL and publishable key using Config/Local.xcconfig.", color: .orange) }
            } else if let session = account.session {
                Section("Signed in") {
                    Text(session.user.email ?? "Staff account")
                    Button("Refresh access") { Task { await account.refresh() } }
                    Button("Sign out", role: .destructive) { Task { await account.signOut() } }
                    Text("Sign-in is saved securely on this device. Your password is never saved by the app.").font(.caption)
                }
                Section {
                  DisclosureGroup("Password settings") {
                    SecureField("New password · at least 12 characters", text: $account.newPassword).textContentType(.newPassword)
                    SecureField("Confirm new password", text: $account.confirmPassword).textContentType(.newPassword)
                    Button("Save password") { Task { await account.savePassword() } }
                        .disabled(account.newPassword.count < 12 || account.newPassword != account.confirmPassword)
                  }
                }
                Section("Your clinician access") {
                    let own = account.memberships.filter { $0.user_id == session.user.id && $0.role == "clinician" }
                    if own.isEmpty { Text("Your account has no approved clinician access. Submit a request below; an administrator must approve it.") }
                    ForEach(own) { m in
                        VStack(alignment: .leading) {
                            Text(account.scopeName(m.scope_id)).font(.headline)
                            Text(m.active ? "Active" : "Suspended").foregroundStyle(m.active ? .green : .red)
                        }
                    }
                }
                Section("Request clinician access") {
                    TextField("Your name", text: $account.name)
                    Picker("Ward / care scope", selection: $account.selectedScope) {
                        Text("Select a scope").tag(Optional<UUID>.none)
                        ForEach(account.scopes.filter(\.active)) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Button("Submit access request") { Task { await account.requestAccess() } }
                        .disabled(account.selectedScope == nil || account.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || account.name.count > 100)
                    if account.scopes.isEmpty { Text("An administrator must configure a care scope first.").font(.caption) }
                }
                Section("Your requests") {
                    ForEach(account.requests.filter { $0.user_id == session.user.id }) { r in Text("\(account.scopeName(r.scope_id)) · \(r.status.capitalized)") }
                }

            } else {
                Section("Sign in") {
                    TextField("Email address", text: $account.email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $account.password).textContentType(.password).submitLabel(.go)
                        .onSubmit { Task { await account.signInWithPassword() } }
                    Button("Sign in") { Task { await account.signInWithPassword() } }.buttonStyle(.borderedProminent)
                        .disabled(!account.emailValid || account.password.isEmpty)
                    Text("Staff access still requires administrator approval.").font(.caption).foregroundStyle(.secondary)
                    if account.restoreFailed { Button("Retry saved sign-in") { Task { await account.restore(force: true) } } }
                }
                Section {
                    DisclosureGroup("Set up an account or reset password") {
                        Text("Verify your email once, then set a password. Returning users can use the Sign in button above.").font(.caption)
                        Button(account.codeSent ? "Resend verification email" : "Send verification email") { Task { await account.sendCode() } }.disabled(!account.emailValid)
                        if account.emailValid {
                            Button("Paste verification link", systemImage: "doc.on.clipboard") { account.pasteEmailLink() }
                            SecureField("Verification link", text: $account.emailLink).textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive()
                            Button("Verify email") { Task { await account.signInWithLink() } }.disabled(!StaffAccessClient.validEmailLink(account.emailLink))
                            Text("Copy the link address from your email without opening it. Use this only for first-time setup or password recovery.").font(.caption)
                            DisclosureGroup("Use an email code instead") {
                                TextField("Email code", text: $account.code).textContentType(.oneTimeCode).keyboardType(.numberPad)
                                Button("Verify code") { Task { await account.signIn() } }.disabled(!StaffAccessClient.validEmailCode(account.code))
                            }
                        }
                    }
                }
                if let notice = account.notice { Section { Notice(text: notice, color: account.failed ? .red : .teal) } }

            }
            if let notice = account.notice, account.session != nil { Section { Notice(text: notice, color: account.failed ? .red : .teal) } }
            if account.busy { ProgressView("Contacting Supabase…") }
        }.disabled(account.busy).navigationTitle("Staff account")
    }
}
