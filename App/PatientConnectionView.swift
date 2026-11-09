import SwiftUI
import Observation

@MainActor @Observable final class PatientConnectionStore {
    var code = ""
    var session: StaffSession?
    @ObservationIgnored private var sessionProvider: PatientSessionProvider?
    var paired = false
    var inbox: [PatientInboxEntry] = []
    var games: [UUID: ConnectedGameStore] = [:]
    func game(for entry: PatientInboxEntry) -> ConnectedGameStore {
        if let game = games[entry.id] { return game }; let game = ConnectedGameStore(entry: entry); games[entry.id] = game; return game
    }
    var expiration: String?
    var busy = false
    var notice: String?
    var configured: Bool { BackendConfiguration.client() != nil }
    var validCode: Bool { UUID(uuidString: code.trimmingCharacters(in: .whitespacesAndNewlines)) != nil }
    private func perform(_ action: (StaffAccessClient) async throws -> Void) async {
        guard !busy, let client = BackendConfiguration.client() else { return }
        busy = true; notice = nil; defer { busy = false }
        do { try await action(client) }
        catch {
            if case StaffAPIError.authentication = error { await clearConnection() }
            notice = (error as? StaffAPIError)?.localizedDescription ?? error.localizedDescription
        }
    }
    func join() async {
        guard validCode else { return }
        await perform { client in
            if self.session == nil {
                let value = try await client.beginPatientSession()
                self.session = value; self.sessionProvider = PatientSessionProvider(session: value, client: client)
            }
            _ = try await self.withSession { client, token in try await client.claimPairing(code: self.code, token: token) }
            self.paired = true; self.code = ""
            try await self.load(client)
        }
    }
    func refresh() async { await perform { try await self.load($0) } }
    // Retry an expired Auth token once using the same operation/request ID.
    // Invalid/expired admission grants still fail at the server after renewal.
    func withSession<T>(_ operation: (StaffAccessClient, String) async throws -> T) async throws -> T {
        guard let provider = sessionProvider, let client = BackendConfiguration.client() else { throw StaffAPIError.authentication }
        do {
            let value = try await provider.current(); session = value
            do { return try await operation(client, value.access_token) }
            catch StaffAPIError.authentication {
                let renewed = try await provider.current(forceRefresh: true); session = renewed
                return try await operation(client, renewed.access_token)
            }
        } catch StaffAuthError.invalidRefresh {
            await clearConnection(); throw StaffAPIError.authentication
        } catch StaffAPIError.authentication {
            await clearConnection(); throw StaffAPIError.authentication
        }
    }
    private func clearConnection() async {
        await sessionProvider?.invalidate(); sessionProvider = nil
        session = nil; paired = false; inbox = []; games.values.forEach { $0.invalidate() }; games = [:]; expiration = nil; code = ""
    }
    private func load(_ client: StaffAccessClient) async throws {
        inbox = []; expiration = nil
        let records = try await withSession { client, token in
            guard let userID = self.session?.user.id else { throw StaffAPIError.authentication }
            return try await client.currentPatientSessions(userID: userID, token: token)
        }
        guard let active = records.first else {
            await clearConnection()
            throw WorkflowError.invalid("This patient session is no longer active. Ask your clinician for a new game code.")
        }
        let entries = try await withSession { client, token in try await client.patientInbox(token: token) }
        expiration = active.expires_at; inbox = entries
    }

    func leave() async {
        await perform { client in
            let token = try await self.withSession { client, token in
                try await client.endPatientSession(token: token); return token
            }
            await self.clearConnection()
            try await client.signOut(token: token)
        }
    }

}

struct PatientConnectionView: View {
    @Bindable var connection: PatientConnectionStore
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        @Bindable var connection = connection
        List {
            Section { Notice(text: "Use the game code provided by your care team. No email or staff sign-in is needed. Development build: fictional admissions only.") }
            if !connection.configured {
                Section { Text("Patient connection is not configured in this build.") }
            } else if connection.paired {
                Section("Patient session") {
                    Button("Refresh assigned challenges") { Task { await connection.refresh() } }
                    if let expiration = connection.expiration { Text("Session expiry: \(expiration)").font(.caption) }
                    Button("End patient session", role: .destructive) { Task { await connection.leave() } }
                }
                Section("Assigned medication references") {
                    if connection.inbox.isEmpty { Text("No current challenges are available. Refresh or check with your clinician.") }
                    ForEach(connection.inbox) { entry in
                        DisclosureGroup("\(entry.patient_alias) · regimen v\(entry.regimen_version)") {
                            Text(entry.practice ? "Practice" : "Assessment").font(.caption)
                            if connection.session != nil {
                                NavigationLink("Open medication challenge") { ConnectedGameView(game: connection.game(for: entry), connection: connection) }
                            }
                            Text("\(entry.medications.count) medicines. Open the challenge to request your medication reference.").font(.caption)
                        }
                    }
                }
            } else {
                Section("Enter your game code") {
                    TextField("Game code", text: $connection.code).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Continue") { Task { await connection.join() } }.disabled(!connection.validCode)
                    Text("Game codes expire after 15 minutes and can be used by one patient identity. Ask your clinician if the code has expired.").font(.caption)
                }
            }
            if let notice = connection.notice { Section { Notice(text: notice, color: .red) } }
            if connection.busy { ProgressView("Connecting…") }
        }.disabled(connection.busy).navigationTitle(connection.paired ? "My challenges" : "Play Samification")
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && connection.paired { Task { await connection.refresh() } }
                else if phase != .active { connection.inbox = []; connection.expiration = nil; connection.games.values.forEach { $0.invalidate() } }
            }
    }
}
