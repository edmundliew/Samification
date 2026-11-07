import SwiftUI
import Observation

@MainActor @Observable final class PatientConnectionStore {
    var code = ""
    var session: StaffSession?
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
            if case StaffAPIError.authentication = error { session = nil; paired = false; inbox = []; games = [:]; expiration = nil }
            notice = (error as? StaffAPIError)?.localizedDescription ?? error.localizedDescription
        }
    }
    func join() async {
        guard validCode else { return }
        await perform { client in
            if self.session == nil { self.session = try await client.beginPatientSession() }
            guard let token = self.session?.access_token else { throw StaffAPIError.authentication }
            _ = try await client.claimPairing(code: self.code, token: token)
            self.paired = true; self.code = ""
            try await self.load(client)
        }
    }
    func refresh() async { await perform { try await self.load($0) } }
    private func load(_ client: StaffAccessClient) async throws {
        inbox = []; expiration = nil
        guard let session else { throw StaffAPIError.authentication }
        let active = try await client.currentPatientSessions(userID: session.user.id, token: session.access_token)
        guard let record = active.first else {
            paired = false; self.session = nil
            throw WorkflowError.invalid("This patient session is no longer active. Ask your clinician for a new pairing session.")
        }
        expiration = record.expires_at
        inbox = try await client.patientInbox(token: session.access_token)
    }
    func leave() async {
        await perform { client in
            guard let token = self.session?.access_token else { return }
            try await client.endPatientSession(token: token)
            self.session = nil; self.paired = false; self.inbox = []; self.games = [:]; self.expiration = nil; self.code = ""
            try await client.signOut(token: token)
        }
    }
}

struct PatientConnectionView: View {
    @State private var connection = PatientConnectionStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        @Bindable var connection = connection
        List {
            Section { Notice(text: "Patient connection · Development preview. Use a pairing code issued by your clinician for a fictional admission. This connection does not require email.") }
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
                            if let token = connection.session?.access_token {
                                NavigationLink("Open medication challenge") { ConnectedGameView(game: connection.game(for: entry), token: token) }
                            }
                            Text("\(entry.medications.count) medicines. Open the challenge to request your medication reference.").font(.caption)
                        }
                    }
                }
            } else {
                Section("Join your admission") {
                    TextField("Paste pairing code", text: $connection.code).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Connect to my admission") { Task { await connection.join() } }.disabled(!connection.validCode)
                    Text("Pairing codes expire after 15 minutes and can be used by one patient identity. Ask your clinician if the code has expired.").font(.caption)
                }
            }
            if let notice = connection.notice { Section { Notice(text: notice, color: .red) } }
            if connection.busy { ProgressView("Connecting…") }
        }.disabled(connection.busy).navigationTitle("Patient connection")
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && connection.paired { Task { await connection.refresh() } }
                else if phase != .active { connection.inbox = []; connection.expiration = nil; connection.games.values.forEach { $0.invalidate() } }
            }
    }
}
