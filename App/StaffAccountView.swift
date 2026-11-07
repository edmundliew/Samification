import SwiftUI
import Observation

@MainActor @Observable final class StaffAccountStore {
    var email = ""
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
    var emailValid: Bool { email.contains("@") && email.count <= 254 && !email.contains(where: \.isWhitespace) }
    func perform(_ action: @escaping (StaffAccessClient) async throws -> Void) async {
        guard !busy else { return }
        guard let client else { notice = StaffAPIError.configuration.localizedDescription; failed = true; return }
        busy = true; notice = nil; failed = false
        defer { busy = false }
        do { try await action(client) }
        catch {
            if case StaffAPIError.authentication = error { clearSession() }
            notice = (error as? StaffAPIError)?.localizedDescription ?? "Unable to read the service response. Please try again."
            failed = true
        }
    }
    func sendCode() async {
        guard emailValid else { return }
        await perform { client in
            try await client.sendCode(email: self.email)
            self.codeSent = true
            self.notice = "Check your email. Copy the sign-in link without opening it, then paste it below. If your email contains a code, you can use that instead."
        }
    }
    func signIn() async {
        guard StaffAccessClient.validEmailCode(code) else { notice = "Enter the numeric code from your email, not the words on its button."; failed = true; return }
        await perform { client in
            self.session = try await client.verifyCode(email: self.email, code: self.code.trimmingCharacters(in: .whitespacesAndNewlines))
            self.code = ""
            try await self.load(client)
        }
    }
    func signInWithLink() async {
        guard StaffAccessClient.validEmailLink(emailLink) else { notice = "Copy the actual link address from the email button, not its words. Use the original, unopened Supabase sign-in link."; failed = true; return }
        let link = emailLink; emailLink = ""
        await perform { client in
            self.session = try await client.verifyEmailLink(link, expectedEmail: self.email)
            self.code = ""
            try await self.load(client)
            self.notice = "Signed in successfully. Your approved access is shown below."
        }
    }
    func refresh() async { await perform { try await self.load($0) } }
    private func load(_ client: StaffAccessClient) async throws {
        guard let token = session?.access_token else { return }
        // Clear cached grants before checking current server permissions; failures keep no stale access list.
        scopes = []; memberships = []; requests = []
        let newMemberships = try await client.memberships(token: token)
        let newScopes = try await client.scopes(token: token)
        let newRequests = try await client.requests(token: token)
        memberships = newMemberships; scopes = newScopes; requests = newRequests
        if !scopes.contains(where: { $0.id == selectedScope && $0.active }) { selectedScope = scopes.first(where: \.active)?.id }
    }
    func requestAccess() async {
        guard let token = session?.access_token, let scope = selectedScope else { return }
        await perform { client in
            try await client.requestAccess(scope: scope, name: self.name.trimmingCharacters(in: .whitespacesAndNewlines), token: token)
            try await self.load(client); self.notice = "Access request submitted for administrator review."
        }
    }
    func decide(_ id: UUID, approve: Bool) async {
        guard let token = session?.access_token else { return }
        await perform { client in
            try await client.decide(requestID: id, approve: approve, reason: self.reason, token: token)
            try await self.load(client); self.reason = ""; self.notice = "Decision recorded."
        }
    }
    func setAccess(_ membership: StaffMembership) async {
        guard let token = session?.access_token else { return }
        await perform { client in
            try await client.setAccess(membershipID: membership.id, enabled: !membership.active, reason: self.reason, token: token)
            try await self.load(client); self.reason = ""; self.notice = "Access change recorded."
        }
    }
    func signOut() async {
        guard let token = session?.access_token else { return }
        await perform { client in
            defer { self.clearSession() }
            try await client.signOut(token: token)
        }
    }
    private func clearSession() { session = nil; memberships = []; scopes = []; requests = []; code = ""; emailLink = ""; codeSent = false; reason = ""; name = "" }
    func scopeName(_ id: UUID?) -> String { scopes.first { $0.id == id }?.name ?? "Unknown scope" }
}

struct StaffAccountView: View {
    @State private var account = StaffAccountStore()
    var body: some View {
        @Bindable var account = account
        Form {
            Section {
                Text("Connected staff access").font(.headline)
                Text("Sign in first. Administrator or clinician access requires separate approval.").font(.caption)
            }
            if !account.configured {
                Section { Notice(text: "Connected access is not configured in this build. Add the project URL and publishable key using Config/Local.xcconfig.", color: .orange) }
            } else if let session = account.session {
                Section("Signed in") {
                    Text(session.user.email ?? "Staff account")
                    Button("Refresh access") { Task { await account.refresh() } }
                    Button("Sign out", role: .destructive) { Task { await account.signOut() } }
                    Text("This development build keeps your session in memory. Reopening the app requires sign-in.").font(.caption)
                }
                Section("Your access") {
                    let own = account.memberships.filter { $0.user_id == session.user.id }
                    if own.isEmpty { Text("No approved staff role. You can request clinician access below.") }
                    ForEach(own) { m in
                        VStack(alignment: .leading) {
                            Text(m.role.capitalized).font(.headline)
                            Text(m.role == "administrator" ? "User administration" : account.scopeName(m.scope_id))
                            Text(m.active ? "Active" : "Suspended").foregroundStyle(m.active ? .green : .red)
                        }
                    }
                }
                if account.memberships.contains(where: { $0.user_id == session.user.id && $0.role == "clinician" && $0.active }) {
                    Section("Clinician workspace") {
                        NavigationLink("Open connected admissions") { ConnectedClinicalView(account: account) }
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
                if account.administrator {
                    Section("Administrator decision reason") {
                        TextField("Reason for approval or access change", text: $account.reason, axis: .vertical)
                        Text("A reason is required and retained in the server audit log. Approvals grant clinician access to the requested scope only.").font(.caption)
                    }
                    Section("Pending requests") {
                        let pending = account.requests.filter { $0.status == "pending" }
                        if pending.isEmpty { Text("No pending requests") }
                        ForEach(pending) { r in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(r.display_name).font(.headline); Text(account.scopeName(r.scope_id))
                                Button("Approve clinician") { Task { await account.decide(r.id, approve: true) } }
                                Button("Reject request", role: .destructive) { Task { await account.decide(r.id, approve: false) } }
                            }.disabled(!reasonValid)
                        }
                    }
                    Section("Clinician memberships") {
                        ForEach(account.memberships.filter { $0.role == "clinician" }) { m in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(account.requests.first { $0.user_id == m.user_id && $0.scope_id == m.scope_id }?.display_name ?? "Staff member")
                                Text(account.scopeName(m.scope_id))
                                Button(m.active ? "Suspend access" : "Resume access", role: m.active ? .destructive : nil) { Task { await account.setAccess(m) } }.disabled(!reasonValid)
                            }
                        }
                    }
                } else {
                    Section("Your requests") {
                        ForEach(account.requests) { r in Text("\(account.scopeName(r.scope_id)) · \(r.status.capitalized)") }
                    }
                }
            } else {
                Section("Staff sign-in") {
                    TextField("Email address", text: $account.email).textContentType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().disabled(account.codeSent)
                    if account.emailValid {
                        SecureField("Paste original sign-in link", text: $account.emailLink).textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive()
                        Button("Verify link & sign in") { Task { await account.signInWithLink() } }.disabled(!StaffAccessClient.validEmailLink(account.emailLink))
                        if !account.emailLink.isEmpty && !StaffAccessClient.validEmailLink(account.emailLink) {
                            Text("This is not a complete sign-in link. In your email, right-click the button and choose Copy Link Address; paste that address here.").font(.caption).foregroundStyle(.red)
                        }
                        Text("Right-click the email button → Copy Link Address. Paste the address here without opening it in a browser.").font(.caption)
                        DisclosureGroup("Have a numeric email code instead?") {
                            TextField("Numeric email code", text: $account.code).textContentType(.oneTimeCode).keyboardType(.numberPad).autocorrectionDisabled()
                            Button("Verify numeric code") { Task { await account.signIn() } }.disabled(!StaffAccessClient.validEmailCode(account.code))
                        }
                        if let notice = account.notice { Notice(text: notice, color: account.failed ? .red : .teal) }
                        if account.busy { ProgressView("Verifying with Supabase…") }
                        Button("Use another email") { account.codeSent = false; account.code = ""; account.emailLink = "" }
                    }
                    Button(account.codeSent ? "Send another sign-in email" : "Send sign-in email") { Task { await account.sendCode() } }.disabled(!account.emailValid)
                    Text("Signing in creates an authentication account if needed. It does not grant a staff role.").font(.caption)
                }
            }
            if let notice = account.notice, account.session != nil || !account.emailValid { Section { Notice(text: notice, color: account.failed ? .red : .teal) } }
            if account.busy { ProgressView("Contacting Supabase…") }
        }.disabled(account.busy).navigationTitle("Staff account")
    }
    private var reasonValid: Bool { let value = account.reason.trimmingCharacters(in: .whitespacesAndNewlines); return !value.isEmpty && value.count <= 500 }
}
